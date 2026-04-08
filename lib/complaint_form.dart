import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'police_station_service.dart';
import 'package:geolocator/geolocator.dart';

class ComplaintFormScreen extends StatefulWidget {
  @override
  _ComplaintFormScreenState createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  final TextEditingController _detailsController = TextEditingController();

  // ── Voice recording ──────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedPath;

  // ── File upload ──────────────────────────────────────────
  static const int _maxTotalBytes = 250 * 1024 * 1024; // 250 MB
  static const int _maxFileBytes = 25 * 1024 * 1024;   // 25 MB per file
  final List<PlatformFile> _uploadedFiles = [];

  // ── Submission state ─────────────────────────────────────
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // Tracking ID Generator: LC-2026-XXXXXX
  // ─────────────────────────────────────────────────────────

  String _generateTrackingId() {
    final year = DateTime.now().year;
    final rand = Random.secure();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final suffix =
        List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'LC-$year-$suffix';
  }

  // ─────────────────────────────────────────────────────────
  // Voice Recording
  // ─────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showSnack("Microphone permission denied.", isError: true);
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/complaint_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(const RecordConfig(), path: path);
    setState(() {
      _isRecording = true;
      _recordedPath = null;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordedPath = path;
    });
    if (path != null) _showSnack("Recording saved.");
  }

  Future<void> _playRecording() async {
    if (_recordedPath == null) return;
    await _audioPlayer.play(DeviceFileSource(_recordedPath!));
    setState(() => _isPlaying = true);
  }

  Future<void> _stopPlayback() async {
    await _audioPlayer.stop();
    setState(() => _isPlaying = false);
  }

  void _deleteRecording() {
    if (_isPlaying) _audioPlayer.stop();
    setState(() {
      _recordedPath = null;
      _isPlaying = false;
    });
  }

  // ─────────────────────────────────────────────────────────
  // File Upload
  // ─────────────────────────────────────────────────────────

  int get _totalUploadedBytes =>
      _uploadedFiles.fold(0, (sum, f) => sum + (f.size));

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final List<String> errors = [];
    final List<PlatformFile> toAdd = [];

    for (final file in result.files) {
      final alreadyAdded =
          _uploadedFiles.any((f) => f.name == file.name && f.size == file.size);
      if (alreadyAdded) {
        errors.add("'${file.name}' already added.");
        continue;
      }
      if (file.size > _maxFileBytes) {
        errors.add("'${file.name}' exceeds 25 MB (${_formatBytes(file.size)}).");
        continue;
      }
      final projectedTotal =
          _totalUploadedBytes + toAdd.fold(0, (s, f) => s + f.size) + file.size;
      if (projectedTotal > _maxTotalBytes) {
        errors.add("'${file.name}' skipped — would exceed 250 MB total limit.");
        continue;
      }
      toAdd.add(file);
    }

    setState(() => _uploadedFiles.addAll(toAdd));

    if (errors.isNotEmpty) {
      _showSnack(errors.join("\n"), isError: true, duration: 4);
    } else if (toAdd.isNotEmpty) {
      _showSnack("${toAdd.length} file(s) added.");
    }
  }

  void _removeFile(int index) {
    setState(() => _uploadedFiles.removeAt(index));
  }

  // ─────────────────────────────────────────────────────────
  // Firebase Storage Upload Helpers
  // ─────────────────────────────────────────────────────────

  /// Uploads a local file to Firebase Storage under complaints/<complaintId>/
  /// Returns the public download URL.
  Future<String> _uploadFileToStorage({
    required String complaintId,
    required String localPath,
    required String fileName,
  }) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('complaints/$complaintId/$fileName');
    final uploadTask = await storageRef.putFile(File(localPath));
    return await uploadTask.ref.getDownloadURL();
  }

  // ─────────────────────────────────────────────────────────
  // Submit
  // ─────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final details = _detailsController.text.trim();
    if (details.isEmpty && _recordedPath == null && _uploadedFiles.isEmpty) {
      _showSnack(
          "Please add complaint details, a voice recording, or a file.",
          isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // ── 1. Generate IDs ────────────────────────────────
      final complaintId =
          FirebaseFirestore.instance.collection('ComplaintDetail').doc().id;
      final trackingId = _generateTrackingId();
      final now = Timestamp.now();

      // ── 2. Find nearest police station ─────────────────
      int? stationId;
      try {
        final station =
            await PoliceStationService.findNearestPoliceStation();
        if (station != null) {
          final raw = station['StationID'];
          stationId = raw is int ? raw : int.tryParse(raw.toString());
        }
      } catch (e) {
        // Location unavailable — station_id left null; can be filled later
        debugPrint("Station lookup failed: $e");
      }

      // ── 3. Upload audio recording ──────────────────────
      String? audioUrl;
      if (_recordedPath != null) {
        final audioFileName =
            'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        audioUrl = await _uploadFileToStorage(
          complaintId: complaintId,
          localPath: _recordedPath!,
          fileName: audioFileName,
        );
      }

      // ── 4. Upload proof files ──────────────────────────
      final List<String> proofUrls = [];
      for (final file in _uploadedFiles) {
        if (file.path == null) continue;
        final url = await _uploadFileToStorage(
          complaintId: complaintId,
          localPath: file.path!,
          fileName: file.name,
        );
        proofUrls.add(url);
      }

      // ── 5. Save to Firestore ComplaintDetail ──────────
      //Position position = await PoliceStationService._getCurrentPosition();
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
      } catch (e) {
        position = null;
      }

      await FirebaseFirestore.instance
          .collection('ComplaintDetail')
          .doc(complaintId)
          .set({
        'complaint_id': complaintId,
        'tracking_id': trackingId,
        'complaint_text': details,
        'audio_url': audioUrl,
        'proof_files': proofUrls,
        'location_coordinates': position != null
          ? {'lat': position.latitude, 'lon': position.longitude}
          : null,
        //'location_coordinates': null, 
        'station_id': stationId,
        'timestamp': now,
        'last_updated': now,
        'status': 'pending',
        'resolution_notes': null,
        'assigned_officer': null,
        'category_id': null,    // AI categorisation — set later by backend
        'subtype_id': null,
        'emergency_flag': false,
        'citizen_id': null,     // anonymous submission
      });

      // ── 6. Show success dialog with tracking ID ────────
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text("Complaint Submitted"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  "Your complaint has been submitted anonymously."),
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Your Tracking ID",
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                    SizedBox(height: 4),
                    SelectableText(
                      trackingId,
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                          letterSpacing: 1.2),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Text(
                  "Save this ID to track your complaint status in the Citizen Dashboard.",
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resetForm();
              },
              child: Text("OK"),
            ),
          ],
        ),
      );
    } catch (e, stack) {
      debugPrint("Submission error: $e\n$stack");
      _showSnack("Submission failed: ${e.toString()}", isError: true, duration: 4);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─────────────────────────────────────────────────────────
  // Cancel / Reset
  // ─────────────────────────────────────────────────────────

  void _cancel() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Discard Complaint?"),
        content: Text(
            "Are you sure you want to cancel? All entered data will be lost."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("No, keep editing"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text("Yes, discard"),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    _detailsController.clear();
    if (_isPlaying) _audioPlayer.stop();
    setState(() {
      _recordedPath = null;
      _isRecording = false;
      _isPlaying = false;
      _uploadedFiles.clear();
    });
  }

  // ─────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────

  void _showSnack(String msg,
      {bool isError = false, int duration = 2}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? Colors.red.shade700 : Colors.green.shade700,
      duration: Duration(seconds: duration),
    ));
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get _totalSizeLabel =>
      '${_formatBytes(_totalUploadedBytes)} / ${_formatBytes(_maxTotalBytes)}';

  // ─────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("File a Complaint"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _isSubmitting
          ? _buildSubmittingOverlay()
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Complaint Details ─────────────────
                  _sectionCard(
                    icon: Icons.description_outlined,
                    title: "Complaint Details",
                    child: TextField(
                      controller: _detailsController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            "Describe your complaint in detail…",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // ── Voice Recording ───────────────────
                  _sectionCard(
                    icon: Icons.mic_outlined,
                    title: "Voice Recording",
                    subtitle: "Optional",
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Record / Stop
                            ElevatedButton.icon(
                              onPressed: _isRecording
                                  ? _stopRecording
                                  : _startRecording,
                              icon: Icon(_isRecording
                                  ? Icons.stop
                                  : Icons.mic),
                              label: Text(
                                  _isRecording ? "Stop" : "Record"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isRecording
                                    ? Colors.red
                                    : Colors.blueAccent,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (_recordedPath != null) ...[
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                tooltip: _isPlaying ? "Stop" : "Play",
                                icon: Icon(
                                    _isPlaying
                                        ? Icons.stop_circle_outlined
                                        : Icons.play_circle_outline,
                                    color: Colors.blueAccent,
                                    size: 26),
                                onPressed: _isPlaying
                                    ? _stopPlayback
                                    : _playRecording,
                              ),
                              SizedBox(width: 8),
                              Text("Recording ready",
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.green.shade700)),
                              SizedBox(width: 8),
                              IconButton(
                                tooltip: "Delete recording",
                                icon: Icon(Icons.delete_outline,
                                    color: Colors.red.shade400,
                                    size: 26),
                                onPressed: _deleteRecording,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // ── File Upload ───────────────────────
                  _sectionCard(
                    icon: Icons.attach_file,
                    title: "Attach Files",
                    subtitle: "Max 25 MB per file · 250 MB total",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickFiles,
                          icon: Icon(Icons.upload_file),
                          label: Text("Upload Files"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        if (_uploadedFiles.isNotEmpty) ...[
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Total size:",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                              Text(_totalSizeLabel,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _totalUploadedBytes >
                                              _maxTotalBytes * 0.9
                                          ? Colors.orange.shade700
                                          : Colors.grey.shade700)),
                            ],
                          ),
                          SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _totalUploadedBytes / _maxTotalBytes,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(
                                _totalUploadedBytes > _maxTotalBytes * 0.9
                                    ? Colors.orange
                                    : Colors.blueAccent,
                              ),
                            ),
                          ),
                          SizedBox(height: 10),
                          ...List.generate(_uploadedFiles.length, (i) {
                            final f = _uploadedFiles[i];
                            return Container(
                              margin: EdgeInsets.only(bottom: 6),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(_fileIcon(f.extension),
                                      size: 20, color: Colors.blueGrey),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(f.name,
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis),
                                        Text(_formatBytes(f.size),
                                            style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    Colors.grey.shade500)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close,
                                        size: 18,
                                        color: Colors.red.shade400),
                                    onPressed: () => _removeFile(i),
                                    tooltip: "Remove",
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 28),

                  // ── Submit / Cancel ───────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _cancel,
                          icon: Icon(Icons.cancel_outlined),
                          label: Text("Cancel"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submit,
                          icon: Icon(Icons.send),
                          label: Text("Submit Complaint"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            textStyle: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ── Submitting overlay ────────────────────────────────────
  Widget _buildSubmittingOverlay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blueAccent),
          SizedBox(height: 20),
          Text(
            "Submitting your complaint…",
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
          ),
          SizedBox(height: 6),
          Text(
            "Uploading files and securing your identity.",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ── Section card wrapper ──────────────────────────────────
  Widget _sectionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blueAccent, size: 20),
                SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                if (subtitle != null) ...[
                  SizedBox(width: 8),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
              ],
            ),
            Divider(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  // ── File type icon ────────────────────────────────────────
  IconData _fileIcon(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.videocam;
      case 'mp3':
      case 'wav':
      case 'm4a':
        return Icons.audio_file;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }
}
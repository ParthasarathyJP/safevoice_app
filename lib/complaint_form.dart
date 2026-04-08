import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

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
      _recordedPath = null; // clear previous recording
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordedPath = path;
    });
    if (path != null) {
      _showSnack("Recording saved.");
    }
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
      // Duplicate check
      final alreadyAdded =
          _uploadedFiles.any((f) => f.name == file.name && f.size == file.size);
      if (alreadyAdded) {
        errors.add("'${file.name}' already added.");
        continue;
      }
      // Per-file size check
      if (file.size > _maxFileBytes) {
        errors.add(
            "'${file.name}' exceeds 25 MB (${_formatBytes(file.size)}).");
        continue;
      }
      // Total size check
      final projectedTotal =
          _totalUploadedBytes + toAdd.fold(0, (s, f) => s + f.size) + file.size;
      if (projectedTotal > _maxTotalBytes) {
        errors.add(
            "'${file.name}' skipped — would exceed 250 MB total limit.");
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
  // Submit / Cancel
  // ─────────────────────────────────────────────────────────

  void _submit() {
    final details = _detailsController.text.trim();
    if (details.isEmpty && _recordedPath == null && _uploadedFiles.isEmpty) {
      _showSnack(
          "Please add complaint details, a voice recording, or a file.",
          isError: true);
      return;
    }

    // TODO: wire up to Firestore / backend
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text("Complaint Submitted"),
          ],
        ),
        content: Text(
            "Your complaint has been submitted anonymously.\n\nA Tracking ID will be generated shortly. You can check the status in the Citizen Dashboard."),
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
  }

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
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      duration: Duration(seconds: duration),
    ));
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  String get _totalSizeLabel {
    final used = _totalUploadedBytes;
    return "${_formatBytes(used)} / 250 MB";
  }

  // ─────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ───────────────────────────────────────
          Row(
            children: [
              Icon(Icons.report_problem_outlined,
                  color: Colors.redAccent, size: 28),
              SizedBox(width: 10),
              Text(
                "Submit a Complaint",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            "Your identity remains 100% anonymous.",
            style: TextStyle(color: Colors.green.shade700, fontSize: 13),
          ),
          SizedBox(height: 20),

          // ── Complaint Details ─────────────────────────────
          _sectionCard(
            icon: Icons.edit_note,
            title: "Complaint Details",
            child: TextField(
              controller: _detailsController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText:
                    "Describe the incident clearly — location, time, what happened...",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          SizedBox(height: 16),

          // ── Voice Recording ───────────────────────────────
          _sectionCard(
            icon: Icons.mic,
            title: "Voice Recording",
            child: Column(
              children: [
                // Record / Stop Record buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isRecording ? null : _startRecording,
                        icon: Icon(Icons.fiber_manual_record),
                        label: Text("Record Voice"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecording
                              ? Colors.grey
                              : Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isRecording ? _stopRecording : null,
                        icon: Icon(Icons.stop),
                        label: Text("Stop Record"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecording
                              ? Colors.orange.shade700
                              : Colors.grey.shade300,
                          foregroundColor:
                              _isRecording ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),

                // Recording indicator
                if (_isRecording) ...[
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, color: Colors.red, size: 12),
                      SizedBox(width: 6),
                      Text("Recording in progress...",
                          style: TextStyle(
                              color: Colors.red,
                              fontStyle: FontStyle.italic,
                              fontSize: 13)),
                    ],
                  ),
                ],

                // Playback controls (shown only when a recording exists)
                if (_recordedPath != null && !_isRecording) ...[
                  SizedBox(height: 12),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.audio_file,
                            color: Colors.blueAccent, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Recording saved",
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade800),
                          ),
                        ),
                        // Play / Stop Replay
                        IconButton(
                          tooltip: _isPlaying ? "Stop Replay" : "Replay",
                          icon: Icon(
                            _isPlaying
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline,
                            color: Colors.blueAccent,
                            size: 28,
                          ),
                          onPressed:
                              _isPlaying ? _stopPlayback : _playRecording,
                        ),
                        // Delete recording
                        IconButton(
                          tooltip: "Delete Recording",
                          icon: Icon(Icons.delete_outline,
                              color: Colors.red.shade400, size: 26),
                          onPressed: _deleteRecording,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),

          // ── File Upload ───────────────────────────────────
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

                // Total usage bar
                if (_uploadedFiles.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Total size:",
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
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
                  ClipRoundedRect(
                    radius: 4,
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

                  // File list
                  ...List.generate(_uploadedFiles.length, (i) {
                    final f = _uploadedFiles[i];
                    return Container(
                      margin: EdgeInsets.only(bottom: 6),
                      padding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(_fileIcon(f.extension),
                              size: 20, color: Colors.blueGrey),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.name,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _formatBytes(f.size),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close,
                                size: 18, color: Colors.red.shade400),
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

          // ── Submit / Cancel ───────────────────────────────
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
                  onPressed: _submit,
                  icon: Icon(Icons.send),
                  label: Text("Submit Complaint"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Section card wrapper ────────────────────────────────
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

  // ── File type icon ──────────────────────────────────────
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

// ── Helper widget: ClipRRect with radius shorthand ────────
class ClipRoundedRect extends StatelessWidget {
  final double radius;
  final Widget child;
  const ClipRoundedRect({required this.radius, required this.child});

  @override
  Widget build(BuildContext context) =>
      ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
}
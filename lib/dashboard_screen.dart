import 'package:flutter/material.dart';
import 'police_station_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with RouteAware {
  final TextEditingController _trackingController = TextEditingController();
  Map<String, String>? _complaintData;

  String _selectedFilter = 'Monthly';
  final List<String> _filters = ['Yearly', 'Monthly', 'Weekly'];

  String _stationMode = 'gps';
  String? _selectedStation;
  String? _selectedState;
  bool _loadingStation = true;
  Map<String, dynamic>? _nearestStation;

  // Stats state
  int _complaintsFiled = 0;
  int _resolvedCases = 0;
  int _pendingCases = 0;
  bool _loadingStats = false;
  String _lastUpdated = 'No updates';
  bool _loadingComplaint = false;

  // ✅ Unified initializing flag — gates the whole screen
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  /// ✅ Chains all startup calls in order
  Future<void> _initialize() async {
    await _loadPreferences();
    if (_stationMode == 'gps') {
      await _loadNearestStation(); // sets _loadingStation = false internally
    } else {
      // ✅ Custom mode: station is already known from prefs, no GPS fetch needed
      if (mounted) setState(() => _loadingStation = false);
      await _loadComplaintStats();
    }
    if (mounted) {
      setState(() => _initializing = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _trackingController.dispose();
    super.dispose();
  }

  /// ✅ Re-run full initialization when returning from Settings
  @override
  void didPopNext() {
    setState(() {
      _initializing = true;
      _loadingStation = true;
    });
    _initialize();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _stationMode = prefs.getString('stationMode') ?? 'gps';
        _selectedStation = prefs.getString('selectedStation');
        _selectedState = prefs.getString('selectedState');
        // ✅ Do NOT set _loadingStation = false here
        // _loadNearestStation() manages it for GPS mode
        // _initialize() manages it for custom mode
      });
    }
  }

  Future<Map<String, String>?> _fetchComplaintByTrackingId(
      String trackingId) async {
    final firestore = FirebaseFirestore.instance;

    final snapshot = await firestore
        .collection('ComplaintDetail')
        .where('tracking_id', isEqualTo: trackingId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();

    String stationName = 'Unknown';
    if (data['station_id'] != null) {
      final stationSnapshot = await firestore
          .collection('PoliceStations')
          .where('StationID', isEqualTo: data['station_id'])
          .limit(1)
          .get();

      if (stationSnapshot.docs.isNotEmpty) {
        final stationData = stationSnapshot.docs.first.data();
        stationName = stationData['StationName'] ?? 'Unknown';
      }
    }

    String formatTimestamp(Timestamp? ts) {
      if (ts == null) return '';
      return DateFormat('dd-MMM-yyyy, hh:mm a').format(ts.toDate());
    }

    return {
      'Police Station': stationName,
      'Complaint Status': data['status'] ?? 'Unknown',
      'Complaint Date': formatTimestamp(data['timestamp'] as Timestamp?),
      'Updated Date': formatTimestamp(data['last_updated'] as Timestamp?),
      'Notes': data['resolution_notes'] ?? '',
    };
  }

  Future<void> _loadNearestStation() async {
    if (mounted) setState(() => _loadingStation = true);
    try {
      final station = await PoliceStationService.findNearestPoliceStation();

      if (mounted) {
        setState(() {
          _nearestStation =
              station ?? {"StationName": "No station found", "State": ""};
          _loadingStation = false; // ✅ GPS fetch done
        });
      }

      if (station != null) {
        await _loadComplaintStats();
      }
    } catch (e) {
      debugPrint('Station load error: $e');
      if (mounted) {
        setState(() {
          _nearestStation = {"StationName": "Unknown", "State": "Unavailable"};
          _loadingStation = false; // ✅ Even on error, stop showing loading text
        });
      }
    }
  }

  String formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _loadComplaintStats() async {
    String? stationName;

    if (_stationMode == 'gps') {
      if (_nearestStation == null) return;
      stationName = _nearestStation!['StationName'];
    } else {
      stationName = _selectedStation;
    }

    if (stationName == null ||
        stationName == 'Unknown' ||
        stationName == 'No station found') return;

    if (mounted) setState(() => _loadingStats = true);

    try {
      final stats = await PoliceStationService.getComplaintStatsRolling(
        stationName,
        _selectedFilter,
      );

      if (mounted) {
        setState(() {
          _complaintsFiled = stats['Filed'] ?? 0;
          _resolvedCases = stats['Resolved'] ?? 0;
          _pendingCases = stats['Pending'] ?? 0;

          final rawUpdate = stats['LastUpdate'];
          _lastUpdated =
              rawUpdate != null ? formatDate(rawUpdate) : 'No updates';
          _loadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Stats load error: $e');
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  void _trackComplaint() async {
    final trackingId = _trackingController.text.trim();
    if (trackingId.isEmpty) return;

    setState(() => _loadingComplaint = true);

    final result = await _fetchComplaintByTrackingId(trackingId);

    if (mounted) {
      setState(() {
        _complaintData = result ??
            {
              'Police Station': 'Not found',
              'Complaint Status': 'N/A',
              'Complaint Date': '',
              'Updated Date': '',
              'Notes': 'No complaint found for this ID.'
            };
        _loadingComplaint = false;
      });
    }
  }

  Widget _statCard({
    required IconData icon,
    required Color color,
    required String title,
    required int value,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: _loadingStats
            ? Text(
                'Loading...',
                style:
                    TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              )
            : Text(
                '$value',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Show full-screen loader during initialization
    if (_initializing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading dashboard...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // ✅ Normal content once initialized
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title + Filter row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Citizen Dashboard',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              DropdownButton<String>(
                value: _selectedFilter,
                items: _filters.map((filter) {
                  return DropdownMenuItem<String>(
                    value: filter,
                    child: Text(filter),
                  );
                }).toList(),
                onChanged: _loadingStats
                    ? null
                    : (newValue) async {
                        setState(() => _selectedFilter = newValue!);
                        await _loadComplaintStats();
                      },
              ),
            ],
          ),
          SizedBox(height: 12),

          // Location Card
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: ListTile(
              leading: Icon(Icons.location_on, color: Colors.blueAccent),
              title: Text('Location'),
              subtitle: _loadingStation
                  ? Text('Fetching preferred police station...')
                  : (_stationMode != 'gps'
                      ? Text(
                          '${_selectedStation ?? "Unknown"}, ${_selectedState ?? ""}',
                        )
                      : Text(
                          '${_nearestStation?['StationName'] ?? "Unknown"}, '
                          '${_nearestStation?['State'] ?? ""}',
                        )),
            ),
          ),
          SizedBox(height: 12),

          // Complaints Filed
          _statCard(
            icon: Icons.report,
            color: Colors.orangeAccent,
            title: 'Complaints Filed',
            value: _complaintsFiled,
          ),
          SizedBox(height: 12),

          // Resolved Cases
          _statCard(
            icon: Icons.check_circle,
            color: Colors.green,
            title: 'Resolved Cases',
            value: _resolvedCases,
          ),
          SizedBox(height: 12),

          // Pending Cases
          _statCard(
            icon: Icons.pending_actions,
            color: Colors.redAccent,
            title: 'Pending Cases',
            value: _pendingCases,
          ),
          SizedBox(height: 20),

          // Latest Update
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: ListTile(
              leading: Icon(Icons.notifications, color: Colors.blueGrey),
              title: Text('Latest Update'),
              subtitle: _loadingStats
                  ? Text(
                      'Loading...',
                      style: TextStyle(
                          fontStyle: FontStyle.italic, color: Colors.grey),
                    )
                  : Text(_lastUpdated),
            ),
          ),
          SizedBox(height: 20),

          // Track Complaint Section
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track Your Complaint',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _trackingController,
                          decoration: InputDecoration(
                            labelText: 'Enter Tracking ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _loadingComplaint ? null : _trackComplaint,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                        ),
                        child: _loadingComplaint
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text('Go'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          // Complaint Details (if available)
          if (_complaintData != null)
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _complaintData!.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Expanded(flex: 3, child: Text(entry.value)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedJurisdiction;
  String? _selectedStation;

  List<String> _states = [];
  List<String> _districts = [];
  List<String> _jurisdictions = [];
  List<String> _stations = [];

  String _stationMode = 'gps'; // default mode
  String _rolloverMode = 'fixed'; // default

  @override
  void initState() {
    super.initState();
    _loadStates();
    _loadSettings(); // restore saved mode + selections
    _loadRolloverMode();
  }

  void _restoreDefault() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _stationMode = 'gps';
      _selectedState = null;
      _selectedDistrict = null;
      _selectedJurisdiction = null;
      _selectedStation = null;
    });
    await prefs.setString('stationMode', 'gps');
    await prefs.setString('selectedState', '');
    await prefs.setString('selectedDistrict', '');
    await prefs.setString('selectedJurisdiction', '');
    await prefs.setString('selectedStation', '');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restored to default (GPS)'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _loadRolloverMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rolloverMode = prefs.getString('rolloverMode') ?? 'fixed';
    });
  }

  Future<void> _saveRolloverMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rolloverMode', mode);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rollover mode saved'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _stationMode = prefs.getString('stationMode') ?? 'gps';
      _selectedState = prefs.getString('selectedState');
      _selectedDistrict = prefs.getString('selectedDistrict');
      _selectedJurisdiction = prefs.getString('selectedJurisdiction');
      _selectedStation = prefs.getString('selectedStation');
    });

    // If a state was saved, reload dependent dropdowns
    if (_selectedState != null && _selectedState!.isNotEmpty) {
      await _loadDistricts(_selectedState!);
    }
    if (_selectedDistrict != null && _selectedDistrict!.isNotEmpty) {
      await _loadJurisdictions(_selectedDistrict!);
    }
    if (_selectedJurisdiction != null && _selectedJurisdiction!.isNotEmpty) {
      await _loadStations(_selectedJurisdiction!);
    }
  }

  Future<void> _saveSettings() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('stationMode', _stationMode);
      await prefs.setString('selectedState', _selectedState ?? '');
      await prefs.setString('selectedDistrict', _selectedDistrict ?? '');
      await prefs.setString('selectedJurisdiction', _selectedJurisdiction ?? '');
      await prefs.setString('selectedStation', _selectedStation ?? '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settings saved successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    }

  Future<void> _cancelChanges() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _stationMode = prefs.getString('stationMode') ?? 'gps';
      _selectedState = prefs.getString('selectedState');
      _selectedDistrict = prefs.getString('selectedDistrict');
      _selectedJurisdiction = prefs.getString('selectedJurisdiction');
      _selectedStation = prefs.getString('selectedStation');
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Changes discarded'), duration: Duration(seconds: 2)),
    );

    Navigator.pop(context); // ✅ Just pop — returns to the main shell + dashboard tab
  }

  Future<void> _loadStates() async {
    final snapshot = await FirebaseFirestore.instance.collection('PoliceStations').get();
    setState(() {
      _states = snapshot.docs.map((doc) => doc['State'] as String).toSet().toList();
    });
  }

  Future<void> _loadDistricts(String state) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('PoliceStations')
        .where('State', isEqualTo: state)
        .get();
    setState(() {
      _districts = snapshot.docs.map((doc) => doc['District'] as String).toSet().toList();
    });
  }

  Future<void> _loadJurisdictions(String district) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('PoliceStations')
        .where('District', isEqualTo: district)
        .get();
    setState(() {
      _jurisdictions = snapshot.docs.map((doc) => doc['JurisdictionArea'] as String).toSet().toList();
    });
  }

  Future<void> _loadStations(String jurisdiction) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('PoliceStations')
        .where('JurisdictionArea', isEqualTo: jurisdiction)
        .get();
    setState(() {
      _stations = snapshot.docs.map((doc) => doc['StationName'] as String).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Police Station',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),

                // Option buttons
                RadioListTile(
                  title: Text('Use GPS Location'),
                  value: 'gps',
                  groupValue: _stationMode,
                  onChanged: (val) => setState(() => _stationMode = val!),
                ),
                RadioListTile(
                  title: Text('Custom Selection'),
                  value: 'custom',
                  groupValue: _stationMode,
                  onChanged: (val) => setState(() => _stationMode = val!),
                ),

                // Dropdowns only if Custom is selected
                if (_stationMode == 'custom') ...[
                  DropdownButton<String>(
                    hint: Text('Select State'),
                    value: _states.contains(_selectedState) ? _selectedState : null,
                    items: _states.map((s) =>
                        DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedState = val;
                        _selectedDistrict = null;
                        _selectedJurisdiction = null;
                        _selectedStation = null;
                      });
                      _loadDistricts(val!);
                    },
                  ),
                  DropdownButton<String>(
                    hint: Text('Select District'),
                    value: _selectedDistrict,
                    items: _districts.map((d) =>
                        DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedDistrict = val;
                        _selectedJurisdiction = null;
                        _selectedStation = null;
                      });
                      _loadJurisdictions(val!);
                    },
                  ),
                  DropdownButton<String>(
                    hint: Text('Select Jurisdiction'),
                    value: _selectedJurisdiction,
                    items: _jurisdictions.map((j) =>
                        DropdownMenuItem(value: j, child: Text(j))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedJurisdiction = val;
                        _selectedStation = null;
                      });
                      _loadStations(val!);
                    },
                  ),
                  DropdownButton<String>(
                    hint: Text('Select Police Station'),
                    value: _selectedStation,
                    items: _stations.map((ps) =>
                        DropdownMenuItem(value: ps, child: Text(ps))).toList(),
                    onChanged: (val) => setState(() => _selectedStation = val),
                  ),
                ],

                Divider(),

                // Action buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(onPressed: _restoreDefault, child: Text('Restore Default')),
                    ElevatedButton(onPressed: _saveSettings, child: Text('Save')),
                    //ElevatedButton(onPressed: _cancelChanges, child: Text('Cancel')),
                  ],
                ),
              ],
            ),
          ),

          Card(
            margin: EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard Rollover',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _rolloverMode == 'fixed'
                              ? Colors.blue
                              : Colors.grey,
                        ),
                        onPressed: () {
                          setState(() => _rolloverMode = 'fixed');
                          _saveRolloverMode('fixed');
                        },
                        child: Text('Fixed Ranges'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _rolloverMode == 'calendar'
                              ? Colors.blue
                              : Colors.grey,
                        ),
                        onPressed: () {
                          setState(() => _rolloverMode = 'calendar');
                          _saveRolloverMode('calendar');
                        },
                        child: Text('Calendar-based'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
 
}
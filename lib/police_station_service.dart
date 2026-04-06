import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class PoliceStationService {
  static Future<Position> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permissions are denied.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions are permanently denied.");
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  static double _calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth radius in km
    var dLat = (lat2 - lat1) * pi / 180;
    var dLon = (lon2 - lon1) * pi / 180;
    var a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  /// Returns nearest police station document
  static Future<Map<String, dynamic>?> findNearestPoliceStationTest() async {
    final pos = await _getCurrentPosition();

    final snapshot =
        await FirebaseFirestore.instance.collection('PoliceStations').get();

    double minDistance = double.infinity;
    Map<String, dynamic>? nearestStation;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final lat = data['Latitude'];
      final lon = data['Longitude'];
      if (lat != null && lon != null) {
        final dist = _calculateDistance(pos.latitude, pos.longitude, lat, lon);
        if (dist < minDistance) {
          minDistance = dist;
          nearestStation = data;
        }
      }
    }

    return nearestStation;
  }

  static Future<Map<String, dynamic>?> findNearestPoliceStation() async {
    final pos = await _getCurrentPosition();
    final double testLat = pos.latitude;
    final double testLon = pos.longitude;

    final snapshot =
        await FirebaseFirestore.instance.collection('PoliceStations').get();

    double minDistance = double.infinity;
    Map<String, dynamic>? nearestStation;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final lat = data['Latitude'];
      final lon = data['Longitude'];
      if (lat != null && lon != null) {
        final dist = _calculateDistance(testLat, testLon, lat, lon);
        if (dist < minDistance) {
          minDistance = dist;
          nearestStation = data;
        }
      }
    }

    return nearestStation;
  }

  Future<void> checkTimestampTypes() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('ComplaintDetail').get();

    for (var doc in snapshot.docs) {
      final ts = doc['timestamp'];
      print("Doc=${doc.id}, type=${ts.runtimeType}, value=$ts");
    }
  }

  /// Complaint statistics for a station within rolling window (7/30/365 days)
  static Future<Map<String, dynamic>> getComplaintStatsRolling(
      String stationName, String period) async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Step 1: Find StationId from PoliceStations using StationName
      final cleanName = stationName.split(',').first.trim();
      final stationSnapshot = await firestore
          .collection('PoliceStations')
          .where('StationName', isEqualTo: cleanName)
          .limit(1)
          .get();

      if (stationSnapshot.docs.isEmpty) {
        return {
          'Filed': -100,
          'Resolved': -100,
          'Pending': -100,
          'LastUpdate': null
        };
      }

      final stationData = stationSnapshot.docs.first.data();
      final int stationId = stationData['StationID'] is int
          ? stationData['StationID']
          : int.parse(stationData['StationID'].toString());

      // Step 2: Calculate rolling window start date
      DateTime now = DateTime.now();
      DateTime start;
      if (period == 'Yearly') {
        start = now.subtract(Duration(days: 365));
      } else if (period == 'Monthly') {
        start = now.subtract(Duration(days: 30));
      } else if (period == 'Weekly') {
        start = now.subtract(Duration(days: 7));
      } else {
        start = DateTime(100); // fallback: all time
      }

      // Step 3: Queries with nested try/catch
      try {
        final totalSnapshot = await firestore
            .collection('ComplaintDetail')
            .where('station_id', isEqualTo: stationId)
            .where('timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .get();

        int totalFiled = totalSnapshot.size;
        int resolvedCount = totalSnapshot.docs
            .where((doc) => doc.data()['status'] == 'resolved')
            .length;
        int pendingCount = totalFiled - resolvedCount;

        Timestamp? latestTs;
        if (totalSnapshot.docs.isNotEmpty) {
          latestTs = totalSnapshot.docs
              .map((doc) => doc.data()['timestamp'] as Timestamp?)
              .where((ts) => ts != null)
              .reduce((a, b) => a!.compareTo(b!) > 0 ? a : b);
        }

        return <String, dynamic>{
          'Filed': totalFiled,
          'Resolved': resolvedCount,
          'Pending': pendingCount,
          'LastUpdate': latestTs?.toDate().toIso8601String() ?? "No updates",
        };
      } catch (complaintError, stack) {
        print(
            "ComplaintDetail query error for StationId=$stationId: $complaintError\n$stack");
        return {
          'Filed': -200,
          'Resolved': -200,
          'Pending': -200,
          'LastUpdate': null
        };
      }
    } catch (stationError, stack) {
      print("Station lookup error: $stationError\n$stack");
      return {
        'Filed': -300,
        'Resolved': -300,
        'Pending': -300,
        'LastUpdate': null
      };
    }
  }
}
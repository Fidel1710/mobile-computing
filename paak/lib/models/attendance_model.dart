import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String sessionId;
  final String nim;
  final String name;
  final DateTime timestamp;
  final int rssi;

  AttendanceModel({
    required this.sessionId,
    required this.nim,
    required this.name,
    required this.timestamp,
    required this.rssi,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else {
        return DateTime.now();
      }
    }

    return AttendanceModel(
      sessionId: map['sessionId'] ?? '',
      nim: map['nim'] ?? '',
      name: map['name'] ?? '',
      timestamp: parseDateTime(map['timestamp']),
      rssi: map['rssi'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'nim': nim,
      'name': name,
      'timestamp': Timestamp.fromDate(timestamp),
      'rssi': rssi,
    };
  }
}

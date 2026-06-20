import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String sessionId;
  final String courseName;
  final String className;
  final String lecturerName;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;

  SessionModel({
    required this.sessionId,
    required this.courseName,
    required this.className,
    required this.lecturerName,
    required this.startTime,
    this.endTime,
    required this.isActive,
  });

  factory SessionModel.fromMap(Map<String, dynamic> map) {
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

    return SessionModel(
      sessionId: map['sessionId'] ?? '',
      courseName: map['courseName'] ?? '',
      className: map['className'] ?? '',
      lecturerName: map['lecturerName'] ?? '',
      startTime: parseDateTime(map['startTime']),
      endTime: map['endTime'] != null ? parseDateTime(map['endTime']) : null,
      isActive: map['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'courseName': courseName,
      'className': className,
      'lecturerName': lecturerName,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'isActive': isActive,
    };
  }
}

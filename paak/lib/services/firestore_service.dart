import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';
import '../models/attendance_model.dart';

class FirestoreService {
  // Lazy-load Firestore instance to prevent crash if Firebase is not initialized
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // In-memory simulation fallback database, persisted to SharedPreferences.
  static const String _localSessionsKey = 'demo_local_sessions_v1';
  static const String _localAttendancesKey = 'demo_local_attendances_v1';
  static final List<SessionModel> _mockSessions = [];
  static final List<AttendanceModel> _mockAttendances = [];
  static final StreamController<List<AttendanceModel>> _attendanceStreamController =
      StreamController<List<AttendanceModel>>.broadcast();
  static bool _localStoreLoaded = false;
  static Future<void>? _localStoreLoadFuture;

  /// Helper to check if Firebase is initialized.
  bool get isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool get isDemoMode => !isFirebaseReady;

  Future<void> _ensureLocalStoreLoaded() async {
    if (_localStoreLoaded) {
      return;
    }

    _localStoreLoadFuture ??= _loadLocalStore();
    await _localStoreLoadFuture;
  }

  Future<void> _loadLocalStore() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _mockSessions
        ..clear();
      _mockAttendances
        ..clear();

      final sessionsJson = prefs.getString(_localSessionsKey);
      if (sessionsJson != null && sessionsJson.isNotEmpty) {
        final decodedSessions = jsonDecode(sessionsJson);
        if (decodedSessions is List) {
          _mockSessions.addAll(
            decodedSessions
                .whereType<Map>()
                .map((entry) => SessionModel.fromMap(Map<String, dynamic>.from(entry))),
          );
        }
      }

      final attendancesJson = prefs.getString(_localAttendancesKey);
      if (attendancesJson != null && attendancesJson.isNotEmpty) {
        final decodedAttendances = jsonDecode(attendancesJson);
        if (decodedAttendances is List) {
          _mockAttendances.addAll(
            decodedAttendances
                .whereType<Map>()
                .map((entry) => AttendanceModel.fromMap(Map<String, dynamic>.from(entry))),
          );
        }
      }
    } catch (_) {
      // Keep empty local lists if persisted demo data cannot be read.
    } finally {
      _localStoreLoaded = true;
      _localStoreLoadFuture = null;
    }
  }

  Map<String, dynamic> _sessionToLocalMap(SessionModel session) {
    return {
      'sessionId': session.sessionId,
      'courseName': session.courseName,
      'className': session.className,
      'lecturerName': session.lecturerName,
      'startTime': session.startTime.millisecondsSinceEpoch,
      'endTime': session.endTime?.millisecondsSinceEpoch,
      'isActive': session.isActive,
    };
  }

  Map<String, dynamic> _attendanceToLocalMap(AttendanceModel attendance) {
    return {
      'sessionId': attendance.sessionId,
      'nim': attendance.nim,
      'name': attendance.name,
      'timestamp': attendance.timestamp.millisecondsSinceEpoch,
      'rssi': attendance.rssi,
    };
  }

  Future<void> _persistLocalStore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localSessionsKey,
        jsonEncode(_mockSessions.map(_sessionToLocalMap).toList()),
      );
      await prefs.setString(
        _localAttendancesKey,
        jsonEncode(_mockAttendances.map(_attendanceToLocalMap).toList()),
      );
    } catch (_) {
      // Ignore persistence errors; in-memory demo mode still works for this run.
    }
  }

  /// Create a new class session (Dosen).
  Future<void> createSession(SessionModel session) async {
    await _ensureLocalStoreLoaded();

    if (isFirebaseReady) {
      try {
        await _db.collection('sessions').doc(session.sessionId).set(session.toMap());
        return;
      } catch (e) {
        // Fallback to mock on error
      }
    }
    // Simulation fallback
    _mockSessions.removeWhere((s) => s.sessionId == session.sessionId);
    _mockSessions.add(session);
    await _persistLocalStore();
  }

  /// End an active session (Dosen).
  Future<void> endSession(String sessionId) async {
    await _ensureLocalStoreLoaded();

    if (isFirebaseReady) {
      try {
        await _db.collection('sessions').doc(sessionId).update({
          'isActive': false,
          'endTime': Timestamp.fromDate(DateTime.now()),
        });
        return;
      } catch (_) {}
    }
    // Simulation fallback
    final index = _mockSessions.indexWhere((s) => s.sessionId == sessionId);
    if (index != -1) {
      final old = _mockSessions[index];
      _mockSessions[index] = SessionModel(
        sessionId: old.sessionId,
        courseName: old.courseName,
        className: old.className,
        lecturerName: old.lecturerName,
        startTime: old.startTime,
        endTime: DateTime.now(),
        isActive: false,
      );
      await _persistLocalStore();
    }
  }

  /// Fetch session details by session ID.
  Future<SessionModel?> getSession(String sessionId) async {
    await _ensureLocalStoreLoaded();

    if (isFirebaseReady) {
      try {
        final doc = await _db.collection('sessions').doc(sessionId).get();
        if (doc.exists && doc.data() != null) {
          return SessionModel.fromMap(doc.data()!);
        }
        return null;
      } catch (_) {}
    }
    // Simulation fallback
    final index = _mockSessions.indexWhere((s) => s.sessionId == sessionId);
    return index != -1 ? _mockSessions[index] : null;
  }

  /// Check if a session exists and is currently active.
  Future<bool> isSessionActive(String sessionId) async {
    final session = await getSession(sessionId);
    return session?.isActive ?? false;
  }

  /// Submit student attendance (Mahasiswa).
  Future<void> submitAttendance(AttendanceModel attendance) async {
    await _ensureLocalStoreLoaded();

    // Check duplicate NIM first in either database
    final alreadyAttended = await hasStudentAttended(attendance.sessionId, attendance.nim);
    if (alreadyAttended) {
      throw Exception("NIM Anda sudah terdaftar hadir di sesi ini!");
    }

    if (isFirebaseReady) {
      try {
        await _db.collection('attendances').add(attendance.toMap());
        return;
      } catch (e) {
        // Fallback to mock on database write error
      }
    }

    // Simulation fallback
    _mockAttendances.add(attendance);
    _attendanceStreamController.add(List.from(_mockAttendances));
    await _persistLocalStore();
  }

  /// Check if a specific NIM has already attended a session.
  Future<bool> hasStudentAttended(String sessionId, String nim) async {
    await _ensureLocalStoreLoaded();

    if (isFirebaseReady) {
      try {
        final query = await _db
            .collection('attendances')
            .where('sessionId', isEqualTo: sessionId)
            .where('nim', isEqualTo: nim)
            .get();
        return query.docs.isNotEmpty;
      } catch (_) {}
    }
    // Simulation fallback
    return _mockAttendances.any((a) => a.sessionId == sessionId && a.nim == nim);
  }

  /// Listen to real-time attendance logs for a specific session (Dosen).
  Stream<List<AttendanceModel>> streamAttendances(String sessionId) {
    if (isFirebaseReady) {
      try {
        return _db
            .collection('attendances')
            .where('sessionId', isEqualTo: sessionId)
            .snapshots()
            .map((snapshot) {
              final list = snapshot.docs
                  .map((doc) => AttendanceModel.fromMap(doc.data()))
                  .toList();
              list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              return list;
            });
      } catch (_) {
        // Fallback on stream listener error
      }
    }

    // Simulation fallback stream
    final controller = StreamController<List<AttendanceModel>>();

    _ensureLocalStoreLoaded().then((_) {
      if (controller.isClosed) {
        return;
      }

      final initialList = _mockAttendances.where((a) => a.sessionId == sessionId).toList();
      initialList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      controller.add(initialList);

      final subscription = _attendanceStreamController.stream.listen((allAttendances) {
        if (!controller.isClosed) {
          final filtered = allAttendances.where((a) => a.sessionId == sessionId).toList();
          filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          controller.add(filtered);
        }
      });

      controller.onCancel = () {
        subscription.cancel();
        controller.close();
      };
    });

    return controller.stream;
  }
}

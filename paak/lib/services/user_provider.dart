import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider with ChangeNotifier {
  String _role = ''; // 'dosen', 'mahasiswa', or ''
  String _lecturerName = '';
  String _studentName = '';
  String _studentNim = '';
  bool _isInitialized = false;

  String get role => _role;
  String get lecturerName => _lecturerName;
  String get studentName => _studentName;
  String get studentNim => _studentNim;
  bool get isInitialized => _isInitialized;

  UserProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _role = prefs.getString('role') ?? '';
      _lecturerName = prefs.getString('lecturerName') ?? '';
      _studentName = prefs.getString('studentName') ?? '';
      _studentNim = prefs.getString('studentNim') ?? '';
    } catch (_) {
      // Fallback if preferences fail
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setRole(String role) async {
    _role = role;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', role);
    } catch (_) {}
  }

  Future<void> setLecturerName(String name) async {
    _lecturerName = name;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lecturerName', name);
    } catch (_) {}
  }

  Future<void> setStudentProfile(String name, String nim) async {
    _studentName = name;
    _studentNim = nim;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('studentName', name);
      await prefs.setString('studentNim', nim);
    } catch (_) {}
  }

  Future<void> logout() async {
    _role = '';
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('role', '');
    } catch (_) {}
  }
}

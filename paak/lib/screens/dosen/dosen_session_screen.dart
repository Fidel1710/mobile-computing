import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/session_model.dart';
import '../../services/ble_advertiser_service.dart';
import '../../services/firestore_service.dart';
import '../../services/permission_service.dart';
import 'dosen_live_attendance_screen.dart';
import 'dosen_home_screen.dart';

class DosenSessionScreen extends StatefulWidget {
  final SessionModel session;

  const DosenSessionScreen({
    super.key,
    required this.session,
  });

  @override
  State<DosenSessionScreen> createState() => _DosenSessionScreenState();
}

class _DosenSessionScreenState extends State<DosenSessionScreen>
    with SingleTickerProviderStateMixin {
  final BleAdvertiserService _advertiserService = BleAdvertiserService();
  final FirestoreService _firestoreService = FirestoreService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isAdvertising = false;
  String _statusMessage = "Menginisialisasi Bluetooth...";
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    // Pulse animation for beacon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initAdvertising();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _advertiserService.stopAdvertising();
    super.dispose();
  }

  Future<void> _initAdvertising() async {
    try {
      final permissionsGranted = await PermissionService.requestBlePermissions();
      if (!permissionsGranted) {
        setState(() {
          _hasError = true;
          _statusMessage = "Izin lokasi & Bluetooth ditolak dosen.";
        });
        _showPermissionDialog();
        return;
      }

      final isSupported = await _advertiserService.isAdvertisingSupported();
      if (!isSupported) {
        setState(() {
          _hasError = true;
          _statusMessage = "HP Anda tidak mendukung BLE Advertising.";
        });
        return;
      }

      await _advertiserService.startAdvertising(
        widget.session.sessionId,
        widget.session.courseName,
      );

      setState(() {
        _isAdvertising = true;
        _statusMessage = "Sinyal BLE Sesi Berhasil Disiarkan!";
        _hasError = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _statusMessage = e.toString().replaceAll("Exception: ", "");
      });
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.amber),
            SizedBox(width: 8),
            Text("Izin Diperlukan"),
          ],
        ),
        content: const Text(
          "Aplikasi ini membutuhkan izin Bluetooth dan Lokasi agar Dosen dapat memancarkan sinyal absensi.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DosenHomeScreen()),
              );
            },
            child: const Text("Kembali"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await PermissionService.openSystemSettings();
              _initAdvertising();
            },
            child: const Text("Buka Pengaturan"),
          ),
        ],
      ),
    );
  }

  void _endSession() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.indigoAccent),
      ),
    );

    // Stop advertiser
    await _advertiserService.stopAdvertising();
    // Update firestore status
    await _firestoreService.endSession(widget.session.sessionId);

    if (mounted) {
      Navigator.of(context).pop(); // Dismiss loader
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DosenHomeScreen()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sesi kelas telah diakhiri dan ditutup."),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final startTimeStr = DateFormat('HH:mm').format(widget.session.startTime);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          "Sesi Kelas Aktif",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.indigo.shade900,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Session Information Card
              Card(
                color: Colors.white.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.white10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.session.courseName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade800,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.session.className,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Dosen: ${widget.session.lecturerName}",
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.access_time, color: Colors.cyanAccent, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                "Mulai: $startTimeStr WIB",
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                          SelectableText(
                            "ID: ${widget.session.sessionId.substring(0, 8)}...",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. BLE Advertising Status Indicator
              Card(
                color: _hasError ? Colors.red.shade900.withValues(alpha: 0.2) : Colors.cyan.shade900.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _hasError ? Colors.redAccent.withValues(alpha: 0.4) : Colors.cyanAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      // Pulsing beacon dot
                      FadeTransition(
                        opacity: _pulseAnimation,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _hasError
                                ? Colors.redAccent
                                : (_isAdvertising ? Colors.cyanAccent : Colors.amberAccent),
                            boxShadow: [
                              BoxShadow(
                                color: _hasError
                                    ? Colors.redAccent
                                    : (_isAdvertising ? Colors.cyanAccent : Colors.amberAccent),
                                blurRadius: 6,
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _hasError
                                ? Colors.redAccent
                                : (_isAdvertising ? Colors.cyanAccent : Colors.amberAccent),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (_hasError)
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.redAccent),
                          onPressed: _initAdvertising,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. Realtime Student List
              const Text(
                "Kehadiran Mahasiswa (Realtime)",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: DosenLiveAttendanceScreen(
                  sessionId: widget.session.sessionId,
                ),
              ),

              // 4. End Session Button
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _endSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                icon: const Icon(Icons.stop),
                label: const Text(
                  "Akhiri Sesi Kelas",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

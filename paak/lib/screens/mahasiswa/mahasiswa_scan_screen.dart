import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../models/attendance_model.dart';
import '../../models/session_model.dart';
import '../../services/ble_scanner_service.dart';
import '../../services/firestore_service.dart';
import '../../services/permission_service.dart';
import '../../services/user_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/rssi_strength_indicator.dart';

class MahasiswaScanScreen extends StatefulWidget {
  const MahasiswaScanScreen({super.key});

  @override
  State<MahasiswaScanScreen> createState() => _MahasiswaScanScreenState();
}

class _MahasiswaScanScreenState extends State<MahasiswaScanScreen> {
  final BleScannerService _scannerService = BleScannerService();
  final FirestoreService _firestoreService = FirestoreService();

  // Cache to prevent repetitive Firestore queries
  final Map<String, SessionModel?> _sessionCache = {};
  final Set<String> _pendingSessionQueries = {};
  final Set<String> _processedAttendance = {};

  bool _isScanning = false;
  String _scanStatusMessage = "Siap untuk memindai...";
  bool _isSuccess = false;
  final TextEditingController _manualCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startScanFlow();
  }

  @override
  void dispose() {
    _manualCodeController.dispose();
    _scannerService.dispose();
    super.dispose();
  }

  void _submitManualCode() async {
    final code = _manualCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ID Sesi tidak boleh kosong")),
      );
      return;
    }

    _scannerService.addLog("Manual Input", code, 0, "Memverifikasi sesi manual...");
    setState(() {
      _scanStatusMessage = "Memverifikasi sesi manual...";
    });

    try {
      final session = await _firestoreService.getSession(code);
      if (session != null) {
        _processSessionScan(session, -50, "Manual Input");
      } else {
        _scannerService.addLog("Manual Input", code, 0, "ID Sesi tidak ditemukan");
        setState(() {
          _scanStatusMessage = "Sesi tidak ditemukan. Pastikan ID Sesi benar.";
        });
      }
    } catch (e) {
      _scannerService.addLog("Manual Input", code, 0, "Gagal: ${e.toString()}");
      setState(() {
        _scanStatusMessage = "Gagal memverifikasi sesi: ${e.toString()}";
      });
    }
  }

  Future<void> _startScanFlow() async {
    setState(() {
      _scanStatusMessage = "Meminta izin Bluetooth & Lokasi...";
    });

    final hasPermissions = await PermissionService.requestBlePermissions();
    if (!hasPermissions) {
      setState(() {
        _scanStatusMessage = "Izin ditolak. Presensi tidak dapat dilanjutkan.";
      });
      _showPermissionDialog();
      return;
    }

    final isBluetoothOn = await _scannerService.isBluetoothOn();
    if (!isBluetoothOn) {
      setState(() {
        _scanStatusMessage = "Bluetooth tidak aktif. Aktifkan Bluetooth Anda.";
      });
      _showBluetoothOffDialog();
      return;
    }

    _startScanning();
  }

  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
      _isSuccess = false;
      _scanStatusMessage = "Mencari sinyal kelas aktif...";
    });

    try {
      await _scannerService.startScanning(
        onDeviceFound: _handleDeviceFound,
        timeout: const Duration(seconds: 45),
      );

      // Stop scanning indicator after timeout
      Future.delayed(const Duration(seconds: 45), () {
        if (mounted && _isScanning && !_isSuccess) {
          setState(() {
            _isScanning = false;
            _scanStatusMessage = "Pencarian selesai. Sesi kelas tidak ditemukan.";
          });
        }
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _scanStatusMessage = e.toString().replaceAll("Exception: ", "");
      });
    }
  }

  void _handleDeviceFound(ScanResult result) async {
    final name = result.device.advName.isNotEmpty
        ? result.device.advName
        : "Device";
    final rssi = result.rssi;
    final uuids = result.advertisementData.serviceUuids;

    if (uuids.isEmpty) return;

    for (final uuid in uuids) {
      final sessionUuid = uuid.toString().toLowerCase();

      // Skip if we already successfully registered attendance for this session
      if (_processedAttendance.contains(sessionUuid)) {
        continue;
      }

      // Check cache first
      if (_sessionCache.containsKey(sessionUuid)) {
        final session = _sessionCache[sessionUuid];
        if (session != null) {
          _processSessionScan(session, rssi, name);
        }
      } else {
        // Query Firestore if not already querying
        if (!_pendingSessionQueries.contains(sessionUuid)) {
          _pendingSessionQueries.add(sessionUuid);
          _scannerService.addLog(name, sessionUuid, rssi, "Memverifikasi sesi di cloud...");

          try {
            final session = await _firestoreService.getSession(sessionUuid);
            _sessionCache[sessionUuid] = session;
            _pendingSessionQueries.remove(sessionUuid);

            if (session != null) {
              _processSessionScan(session, rssi, name);
            } else {
              _scannerService.addLog(name, sessionUuid, rssi, "Bukan UUID sesi absensi valid.");
            }
          } catch (e) {
            _pendingSessionQueries.remove(sessionUuid);
            _scannerService.addLog(name, sessionUuid, rssi, "Gagal validasi cloud: ${e.toString()}");
          }
        }
      }
    }
  }

  void _processSessionScan(SessionModel session, int rssi, String deviceName) async {
    final sessionId = session.sessionId;

    // 1. Check if session is active
    if (!session.isActive) {
      _scannerService.addLog(deviceName, sessionId, rssi, "Sesi '${session.courseName}' tidak aktif");
      return;
    }

    // 2. Fetch Student Info
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final nim = userProvider.studentNim;
    final name = userProvider.studentName;

    // Double check attendance status
    bool alreadyAttended = false;
    try {
      alreadyAttended = await _firestoreService.hasStudentAttended(sessionId, nim);
    } catch (_) {}

    if (alreadyAttended) {
      _processedAttendance.add(sessionId);
      _scannerService.addLog(deviceName, sessionId, rssi, "Sudah absen di '${session.courseName}'");
      setState(() {
        _scanStatusMessage = "Anda sudah tercatat hadir di kelas ${session.courseName}.";
        _isScanning = false;
      });
      _scannerService.stopScanning();
      _showSuccessDialog(session, isAlreadyRegistered: true);
      return;
    }

    // 3. Proximity Validation (RSSI Strength check)
    if (!AppConstants.isWithinRange(rssi)) {
      _scannerService.addLog(
        deviceName,
        sessionId,
        rssi,
        "Sinyal lemah ($rssi dBm). Silakan dekati dosen!",
      );
      setState(() {
        _scanStatusMessage = "Sinyal kelas '${session.courseName}' terlalu lemah ($rssi dBm). Mendekatlah ke dosen.";
      });
      return;
    }

    // 4. Submit Attendance
    _scannerService.addLog(deviceName, sessionId, rssi, "Mencatat presensi...");
    setState(() {
      _scanStatusMessage = "Mencatat presensi untuk '${session.courseName}'...";
    });

    final attendance = AttendanceModel(
      sessionId: sessionId,
      nim: nim,
      name: name,
      timestamp: DateTime.now(),
      rssi: rssi,
    );

    try {
      await _firestoreService.submitAttendance(attendance);
      _processedAttendance.add(sessionId);
      _scannerService.addLog(deviceName, sessionId, rssi, "Presensi Berhasil!");

      setState(() {
        _isScanning = false;
        _isSuccess = true;
        _scanStatusMessage = "Presensi sukses dicatat di '${session.courseName}'!";
      });

      _scannerService.stopScanning();
      _showSuccessDialog(session);
    } catch (e) {
      final cleanMsg = e.toString().replaceAll("Exception: ", "");
      _scannerService.addLog(deviceName, sessionId, rssi, "Gagal submit: $cleanMsg");
      setState(() {
        _scanStatusMessage = "Gagal mencatat presensi: $cleanMsg";
      });
    }
  }

  void _showSuccessDialog(SessionModel session, {bool isAlreadyRegistered = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isAlreadyRegistered ? Icons.info : Icons.check_circle,
              color: isAlreadyRegistered ? Colors.amber : Colors.tealAccent.shade400,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(isAlreadyRegistered ? "Sudah Hadir" : "Presensi Sukses"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAlreadyRegistered
                  ? "Anda sudah tercatat hadir untuk sesi kelas ini sebelumnya."
                  : "Presensi Anda berhasil dicatat secara otomatis via BLE!",
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            const Text("Detail Sesi:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("Mata Kuliah: ${session.courseName}"),
            Text("Kelas: ${session.className}"),
            Text("Dosen: ${session.lecturerName}"),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // pop dialog
              Navigator.of(context).pop(); // pop back to home
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Selesai"),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Izin Diperlukan"),
        content: const Text(
          "Izin Bluetooth dan Lokasi diperlukan agar aplikasi dapat memindai sinyal presensi BLE dari dosen.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await PermissionService.openSystemSettings();
              _startScanFlow();
            },
            child: const Text("Buka Pengaturan"),
          ),
        ],
      ),
    );
  }

  void _showBluetoothOffDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Bluetooth Mati"),
        content: const Text("Silakan aktifkan Bluetooth Anda terlebih dahulu untuk memulai presensi."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startScanFlow();
            },
            child: const Text("Coba Lagi"),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLogsToCsv() async {
    final logs = _scannerService.currentLogs;
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Belum ada riwayat pemindaian untuk diekspor."),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final StringBuffer buffer = StringBuffer();
    // CSV headers
    buffer.writeln("Waktu,Nama Perangkat,Service UUID,RSSI (dBm),Status");

    for (final entry in logs) {
      final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.timestamp);
      buffer.writeln(
        '"$timeStr","${entry.deviceName}","${entry.uuid}",${entry.rssi},"${entry.status}"',
      );
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/log_presensi_ble_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Data Log Pengujian RSSI Presensi BLE',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal mengekspor berkas: ${e.toString()}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          "Pindai Presensi",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: "Ekspor Log CSV",
            onPressed: _exportLogsToCsv,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Radar Scanning UI / Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    if (_isScanning)
                      const Center(
                        child: SizedBox(
                          height: 48,
                          width: 48,
                          child: CircularProgressIndicator(
                            color: Colors.tealAccent,
                            strokeWidth: 3.5,
                          ),
                        ),
                      )
                    else
                      Icon(
                        _isSuccess ? Icons.check_circle_outline : Icons.bluetooth_disabled,
                        color: _isSuccess ? Colors.tealAccent : Colors.grey.shade600,
                        size: 48,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _scanStatusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isSuccess ? Colors.tealAccent : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isScanning)
                      const Text(
                        "Tetap dekat dengan handphone dosen...",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. Logs header
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Log Pemindaian BLE (Live RSSI)",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _scannerService.clearLogs()),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.clear_all, size: 16, color: Colors.tealAccent),
                    label: const Text(
                      "Bersihkan",
                      style: TextStyle(color: Colors.tealAccent, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 3. Realtime scanning list representation
              StreamBuilder<List<ScanLogEntry>>(
                stream: _scannerService.logsStream,
                initialData: _scannerService.currentLogs,
                builder: (context, snapshot) {
                  final logs = snapshot.data ?? [];

                  if (logs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: Text(
                          "Belum ada data pemindaian...",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: logs.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final entry = logs[index];
                      final timeStr = DateFormat('HH:mm:ss').format(entry.timestamp);

                      // Signal status color
                      final bool isStrong = entry.rssi >= AppConstants.defaultRssiThreshold;
                      final bool isSessionCheck = entry.status.contains("Berhasil") || entry.status.contains("Mencatat");

                      return Card(
                        color: isSessionCheck
                            ? Colors.teal.shade900.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.03),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSessionCheck
                                ? Colors.tealAccent.withValues(alpha: 0.2)
                                : Colors.white10,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              entry.status.contains("Berhasil")
                                  ? Icons.check
                                  : (isStrong ? Icons.bluetooth : Icons.bluetooth_searching),
                              color: entry.status.contains("Berhasil")
                                  ? Colors.tealAccent
                                  : (isStrong ? Colors.cyanAccent : Colors.grey),
                              size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.deviceName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (entry.rssi != 0)
                                RssiStrengthIndicator(
                                  rssi: entry.rssi,
                                  iconSize: 18,
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              if (entry.uuid.isNotEmpty)
                                Text(
                                  "UUID: ${entry.uuid.substring(0, 8)}...",
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.status,
                                      style: TextStyle(
                                        color: entry.status.contains("Berhasil")
                                            ? Colors.tealAccent
                                            : (entry.status.contains("lemah")
                                                ? Colors.amberAccent
                                                : Colors.white70),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    timeStr,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // 4. Retry / scanning control button
              const SizedBox(height: 16),
              if (!_isScanning && !_isSuccess)
                ElevatedButton.icon(
                  onPressed: _startScanning,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade800,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    "Pindai Ulang",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                )
              else if (_isScanning)
                ElevatedButton.icon(
                  onPressed: () {
                    _scannerService.stopScanning();
                    setState(() {
                      _isScanning = false;
                      _scanStatusMessage = "Pemindaian dihentikan.";
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade700,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.cancel),
                  label: const Text(
                    "Hentikan Pemindaian",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 16),
              Card(
                color: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Demo / Fallback Mode (Input Manual)",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.tealAccent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualCodeController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: "Masukkan ID Sesi Kelas",
                                hintStyle: const TextStyle(color: Colors.white30),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _submitManualCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("Absen", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
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

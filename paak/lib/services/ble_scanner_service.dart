import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ScanLogEntry {
  final DateTime timestamp;
  final String deviceName;
  final String uuid;
  final int rssi;
  final String status;

  ScanLogEntry({
    required this.timestamp,
    required this.deviceName,
    required this.uuid,
    required this.rssi,
    required this.status,
  });

  Map<String, String> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'deviceName': deviceName,
      'uuid': uuid,
      'rssi': rssi.toString(),
      'status': status,
    };
  }
}

class BleScannerService {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  final List<ScanLogEntry> _scanLogs = [];
  final StreamController<List<ScanLogEntry>> _logsController = StreamController<List<ScanLogEntry>>.broadcast();

  Stream<List<ScanLogEntry>> get logsStream => _logsController.stream;
  List<ScanLogEntry> get currentLogs => List.unmodifiable(_scanLogs);

  /// Check if Bluetooth is supported on this device.
  Future<bool> isBluetoothSupported() async {
    try {
      return await FlutterBluePlus.isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Check if Bluetooth adapter is ON.
  Future<bool> isBluetoothOn() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  /// Stream of bluetooth adapter states.
  Stream<BluetoothAdapterState> get adapterStateStream => FlutterBluePlus.adapterState;

  /// Start scanning for BLE devices.
  /// When a device is found, it will execute [onDeviceFound].
  Future<void> startScanning({
    required Function(ScanResult result) onDeviceFound,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final supported = await isBluetoothSupported();
    if (!supported) {
      throw Exception("Bluetooth tidak didukung di perangkat ini.");
    }

    final on = await isBluetoothOn();
    if (!on) {
      throw Exception("Bluetooth tidak aktif. Nyalakan Bluetooth Anda.");
    }

    // Clear previous logs for a new scanning session
    _scanLogs.clear();
    _logsController.add(_scanLogs);

    await stopScanning();

    // Start scanning
    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        continuousUpdates: true,
      );
    } catch (e) {
      throw Exception("Gagal memulai pemindaian BLE: ${e.toString()}");
    }

    // Listen for scan results
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        onDeviceFound(result);
      }
    }, onError: (error) {
      addLog("System", "", 0, "Error saat scan: $error");
    });
  }

  /// Stop scanning.
  Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  /// Add a log entry for the user to see raw RSSI details.
  void addLog(String deviceName, String uuid, int rssi, String status) {
    final entry = ScanLogEntry(
      timestamp: DateTime.now(),
      deviceName: deviceName.isEmpty ? "Unknown Device" : deviceName,
      uuid: uuid,
      rssi: rssi,
      status: status,
    );
    _scanLogs.insert(0, entry); // Newest first
    _logsController.add(_scanLogs);
  }

  /// Clear the log history.
  void clearLogs() {
    _scanLogs.clear();
    _logsController.add(_scanLogs);
  }

  /// Close controller.
  void dispose() {
    stopScanning();
    _logsController.close();
  }
}

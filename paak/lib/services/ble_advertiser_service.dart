import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class BleAdvertiserService {
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();

  /// Check if BLE peripheral mode (advertising) is supported by this device's hardware.
  Future<bool> isAdvertisingSupported() async {
    try {
      return await _peripheral.isSupported;
    } catch (e) {
      return false;
    }
  }

  /// Start BLE advertising with the sessionId as the Service UUID.
  /// We also set a local name so the advertising packet has a readable identifier.
  Future<void> startAdvertising(String sessionId, String courseName) async {
    final bool supported = await isAdvertisingSupported();
    if (!supported) {
      throw Exception("Perangkat Anda tidak mendukung mode BLE Peripheral / Bluetooth Advertising.");
    }

    // Limit course name length in BLE advertising name (local name has limits in BLE packet size)
    final cleanCourseName = courseName.length > 10 ? courseName.substring(0, 10) : courseName;

    final AdvertiseData advertiseData = AdvertiseData(
      serviceUuid: sessionId,
      localName: "P-$cleanCourseName",
    );

    try {
      await _peripheral.start(advertiseData: advertiseData);
    } catch (e) {
      throw Exception("Gagal memulai Bluetooth Advertising: ${e.toString()}");
    }
  }

  /// Stop BLE advertising.
  Future<void> stopAdvertising() async {
    try {
      await _peripheral.stop();
    } catch (_) {
      // Ignore errors when trying to stop
    }
  }

  /// Check if the device is currently advertising.
  Future<bool> isCurrentlyAdvertising() async {
    try {
      return await _peripheral.isAdvertising;
    } catch (_) {
      return false;
    }
  }
}

class AppConstants {
  /// Default RSSI threshold in dBm. Sinyal yang lebih kuat dari ini (misal -65) dianggap valid.
  /// Sinyal yang lebih lemah (misal -85) dianggap tidak valid.
  static const int defaultRssiThreshold = -70;

  /// Cek apakah RSSI berada dalam jangkauan yang diperbolehkan.
  static bool isWithinRange(int rssi, {int threshold = defaultRssiThreshold}) {
    return rssi >= threshold;
  }

  /// Label deskripsi berdasarkan kekuatan sinyal RSSI
  static String getSignalStrengthLabel(int rssi) {
    if (rssi >= -60) {
      return "Sangat Kuat (Dekat)";
    } else if (rssi >= -70) {
      return "Kuat (Cukup Dekat)";
    } else if (rssi >= -85) {
      return "Lemah (Jauh)";
    } else {
      return "Sangat Lemah (Terlalu Jauh)";
    }
  }
}

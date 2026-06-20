import 'package:flutter/material.dart';

class RssiStrengthIndicator extends StatelessWidget {
  final int rssi;
  final double iconSize;

  const RssiStrengthIndicator({
    super.key,
    required this.rssi,
    this.iconSize = 24.0,
  });

  Color _getStrengthColor(int rssi) {
    if (rssi >= -60) {
      return const Color(0xFF10B981); // Emerald / Very strong
    } else if (rssi >= -70) {
      return Colors.teal; // Strong / OK
    } else if (rssi >= -85) {
      return Colors.amber; // Weak
    } else {
      return const Color(0xFFF43F5E); // Rose / Very weak
    }
  }

  IconData _getStrengthIcon(int rssi) {
    if (rssi >= -60) {
      return Icons.bluetooth;
    } else if (rssi >= -70) {
      return Icons.bluetooth_connected;
    } else if (rssi >= -85) {
      return Icons.bluetooth_searching;
    } else {
      return Icons.bluetooth_disabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStrengthColor(rssi);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getStrengthIcon(rssi),
          color: color,
          size: iconSize,
        ),
        const SizedBox(width: 4),
        Text(
          "$rssi dBm",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: iconSize * 0.55,
          ),
        ),
      ],
    );
  }
}

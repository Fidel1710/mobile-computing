import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';
import 'rssi_strength_indicator.dart';

class AttendanceListItem extends StatelessWidget {
  final AttendanceModel attendance;

  const AttendanceListItem({
    super.key,
    required this.attendance,
  });

  @override
  Widget build(BuildContext context) {
    final formattedTime = DateFormat('HH:mm:ss').format(attendance.timestamp);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Student avatar with initials
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.indigo.shade50,
              child: Text(
                attendance.name.isNotEmpty
                    ? attendance.name.substring(0, 1).toUpperCase()
                    : "?",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Student info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attendance.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "NIM: ${attendance.nim}",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Hadir pada: $formattedTime WIB",
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Proximity indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "Sinyal Scan",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                RssiStrengthIndicator(
                  rssi: attendance.rssi,
                  iconSize: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

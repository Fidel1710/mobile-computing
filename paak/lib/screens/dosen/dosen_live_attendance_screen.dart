import 'package:flutter/material.dart';
import '../../models/attendance_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/attendance_list_item.dart';

class DosenLiveAttendanceScreen extends StatelessWidget {
  final String sessionId;
  final FirestoreService _firestoreService = FirestoreService();

  DosenLiveAttendanceScreen({
    super.key,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AttendanceModel>>(
      stream: _firestoreService.streamAttendances(sessionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.indigoAccent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error memuat data: ${snapshot.error}",
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final attendances = snapshot.data ?? [];

        if (attendances.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    color: Colors.indigo.shade300.withValues(alpha: 0.3),
                    size: 72,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Belum ada mahasiswa absen",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Sinyal Bluetooth sedang memancar...",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
              child: Text(
                "${attendances.length} Mahasiswa Terdaftar",
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: attendances.length,
                itemBuilder: (context, index) {
                  return AttendanceListItem(
                    attendance: attendances[index],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

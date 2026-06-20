# Prompt untuk Gemini CLI — Aplikasi Presensi Otomatis Berbasis Bluetooth (BLE)

Kamu adalah AI engineer yang membantu membangun aplikasi Flutter untuk tugas mata kuliah Mobile Computing. Bangun project ini dari nol sampai siap di-demo, mengikuti spesifikasi di bawah secara lengkap. Tulis kode yang rapi, ada komentar singkat di bagian penting, dan buat README yang menjelaskan cara setup & menjalankan.

## 1. Konteks & Studi Kasus

Aplikasi presensi kelas otomatis menggunakan Bluetooth Low Energy (BLE) sebagai pengganti presensi manual/QR code. Dosen membuka sesi kelas di HP-nya, app dosen broadcast sinyal BLE berisi ID sesi unik. Mahasiswa yang berada dalam jangkauan ruangan otomatis terdeteksi oleh app-nya dan tercatat hadir, tanpa perlu input manual. Validasi jarak (proximity) dilakukan lewat kekuatan sinyal (RSSI) supaya mahasiswa di luar ruangan tidak bisa ikut absen.

Target platform: **Android saja** (BLE advertising di iOS lebih rumit dan tidak perlu untuk demo tugas kuliah).

## 2. Tech Stack

- Flutter (versi stable terbaru), state management: `provider`
- `flutter_blue_plus` — untuk scanning BLE (sisi mahasiswa)
- `flutter_ble_peripheral` — untuk advertising BLE (sisi dosen)
- `firebase_core` + `cloud_firestore` — backend & realtime data
- `permission_handler` — request runtime permission Android 12+
- `uuid` — generate session ID unik
- `intl` — format tanggal/waktu

## 3. Struktur Project

Buat **satu aplikasi Flutter** (bukan dua app terpisah) dengan pemilihan role di awal (Dosen / Mahasiswa), supaya gampang di-build dan di-demo dari satu APK.

```
lib/
  main.dart
  models/
    session_model.dart
    attendance_model.dart
  services/
    ble_advertiser_service.dart   // sisi dosen
    ble_scanner_service.dart      // sisi mahasiswa
    firestore_service.dart
    permission_service.dart
  screens/
    role_selector_screen.dart
    dosen/
      dosen_home_screen.dart
      dosen_session_screen.dart      // mulai sesi + broadcast
      dosen_live_attendance_screen.dart  // list realtime
    mahasiswa/
      mahasiswa_home_screen.dart
      mahasiswa_scan_screen.dart     // scan & submit presensi
  widgets/
    attendance_list_item.dart
    rssi_strength_indicator.dart
  utils/
    constants.dart   // RSSI threshold, UUID service prefix, dll
README.md
```

## 4. Functional Requirements

### 4.1 Role Selector (layar awal)
- Dua tombol besar: "Masuk sebagai Dosen" dan "Masuk sebagai Mahasiswa"
- Tidak perlu sistem login/auth yang kompleks — cukup input nama dosen/mata kuliah, atau NIM+nama mahasiswa, disimpan di local state

### 4.2 Modul Dosen
- Form: nama mata kuliah, kelas (contoh: TI 4C)
- Tombol "Mulai Sesi" → generate `sessionId` (uuid v4) → simpan dokumen baru di Firestore collection `sessions` → mulai BLE advertising dengan payload berisi `sessionId`
- Setelah sesi mulai, tampilkan layar "Sesi Aktif" dengan:
  - Info sesi (mata kuliah, waktu mulai, sessionId)
  - List mahasiswa yang sudah absen, update realtime (`StreamBuilder` dari Firestore)
  - Tombol "Akhiri Sesi" → stop BLE advertising, update field `endTime` & `isActive: false` di Firestore

### 4.3 Modul Mahasiswa
- Form: NIM, nama
- Tombol "Scan & Absen" → request permission BLE & lokasi (jika belum) → mulai scan BLE
- Saat menemukan device dengan payload `sessionId` yang valid:
  - Cek apakah sesi tersebut `isActive: true` di Firestore
  - Cek RSSI terhadap threshold (default **-70 dBm**, taruh di `constants.dart` supaya gampang diubah saat testing)
  - Jika valid, submit dokumen baru ke collection `attendances` (lihat skema di bawah), tampilkan status sukses
  - Jika RSSI terlalu lemah, tampilkan pesan "Sinyal terlalu lemah, dekati ruangan kelas" — **jangan langsung ditolak permanen**, biarkan retry otomatis selama scanning berjalan
- Cegah duplikat: 1 NIM hanya bisa absen 1x per sessionId (cek dulu sebelum submit)

### 4.4 Validasi Proximity
Buat fungsi terpisah `isWithinRange(int rssi)` di `utils/constants.dart` atau helper khusus, supaya threshold-nya gampang diubah dan ditest dengan beberapa nilai berbeda (untuk kebutuhan bab Pengujian di laporan).

## 5. Skema Data Firestore

**Collection `sessions`**
```
{
  sessionId: string (uuid),
  courseName: string,
  className: string,
  lecturerName: string,
  startTime: timestamp,
  endTime: timestamp | null,
  isActive: boolean
}
```

**Collection `attendances`**
```
{
  sessionId: string,
  nim: string,
  name: string,
  timestamp: timestamp,
  rssi: number
}
```

## 6. Permission & AndroidManifest

Tambahkan di `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```
Buat `permission_service.dart` yang request semua izin ini sekaligus saat pertama kali masuk ke layar Dosen atau Mahasiswa, dengan UI fallback yang jelas kalau user menolak izin (jangan crash, tampilkan pesan + tombol buka Settings).

## 7. Penanganan Error / Edge Case yang Wajib Ditangani

- BLE tidak aktif di device → tampilkan dialog minta user nyalakan Bluetooth
- Device tidak mendukung BLE advertising (beberapa HP tidak support peripheral mode) → tangkap exception, tampilkan pesan jelas ke dosen bahwa device tidak kompatibel
- Tidak ada koneksi internet saat submit ke Firestore → simpan ke local queue sederhana, retry saat online (boleh pakai `connectivity_plus` kalau perlu, atau cukup tampilkan pesan error dan tombol retry manual)
- Sesi sudah berakhir tapi mahasiswa masih scan → tolak dengan pesan "Sesi sudah ditutup"

## 8. Utilitas untuk Kebutuhan Pengujian (penting!)

Karena hasil pengujian (jarak deteksi, RSSI, response time) akan dilaporkan di bab Pengujian, buatkan:
- Logging sederhana di layar Mahasiswa yang menampilkan RSSI mentah secara live saat scanning (bukan cuma hasil akhir), supaya saya bisa mencatat angka asli saat testing manual di lapangan
- Opsional: tombol "Export log" yang men-generate file `.csv` berisi riwayat scan (timestamp, rssi, hasil valid/tidak) selama sesi testing berjalan, disimpan ke local storage device

**Catatan penting: jangan generate data uji palsu/dummy di laporan. Aplikasi cukup sediakan mekanisme logging — pengujian jarak, response time, dan akurasi akan saya lakukan manual dengan device asli.**

## 9. Tahapan Pengerjaan (kerjakan berurutan)

1. Setup project Flutter baru + Firebase (firebase_core, cloud_firestore) + tambahkan semua dependency di `pubspec.yaml`
2. Buat models (`SessionModel`, `AttendanceModel`) dengan `fromMap`/`toMap`
3. Buat `permission_service.dart` dan `firestore_service.dart`
4. Buat `ble_advertiser_service.dart` (sisi dosen) — termasuk start/stop advertising
5. Buat `ble_scanner_service.dart` (sisi mahasiswa) — scan, filter device, baca RSSI
6. Bangun UI Role Selector
7. Bangun seluruh alur Dosen (form sesi → broadcast → live attendance list realtime)
8. Bangun seluruh alur Mahasiswa (form → scan → validasi → submit → status)
9. Tambahkan utilitas logging RSSI & export CSV
10. Tambahkan penanganan semua error/edge case di bagian 7
11. Tulis `README.md`: cara install dependency, setup Firebase project, cara build & run, daftar permission yang dibutuhkan, dan catatan device yang sudah pernah ditest

## 10. Deliverable Akhir

- Source code Flutter lengkap dan bisa langsung di-run (`flutter pub get && flutter run`)
- README jelas
- Tidak ada TODO/placeholder yang dibiarkan kosong — semua flow dari buka app sampai presensi tercatat harus berfungsi end-to-end

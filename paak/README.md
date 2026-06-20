# Aplikasi Presensi Otomatis Berbasis Bluetooth Low Energy (BLE)

Projek ini adalah aplikasi presensi kelas otomatis berbasis jarak (proximity) menggunakan teknologi Bluetooth Low Energy (BLE). Aplikasi ini dirancang menggunakan Flutter dan terintegrasi dengan Firebase Cloud Firestore untuk sinkronisasi data presensi secara realtime.

Dosen membuka sesi kelas pada aplikasinya, yang kemudian memicu *BLE peripheral mode advertising* (memancarkan sinyal UUID sesi). Mahasiswa yang berada di dalam ruangan kelas dengan aplikasi aktif akan secara otomatis mendeteksi sinyal tersebut melalui *BLE scanning mode*, mengukur kekuatan sinyal (RSSI) untuk verifikasi jarak, dan mencatat kehadiran ke Firebase.

## Fitur Utama

- **Role Selector Terintegrasi:** Memungkinkan dosen dan mahasiswa memilih peran mereka langsung di dalam satu aplikasi.
- **Realtime Live Attendance:** Dosen dapat melihat daftar kehadiran mahasiswa secara langsung yang terus diperbarui secara realtime dari Firestore.
- **Auto-proximity Validation:** Sistem secara otomatis menyaring mahasiswa berdasarkan threshold RSSI (default: `-70 dBm`) untuk mencegah presensi "titip absen" dari luar kelas.
- **Live Scanning RSSI Logging:** Mahasiswa dapat melihat log deteksi Bluetooth mentah yang menampilkan RSSI secara *live* selama pemindaian.
- **Ekspor CSV:** Fitur ekspor log pemindaian mentah ke file `.csv` yang dapat dibagikan untuk kepentingan analisis data pengujian laporan kuliah.
- **Robust Exception/Fallback Handlers:** Menangani device yang tidak mendukung BLE advertising, Bluetooth tidak aktif, izin ditolak, dan database luring.

---

## 1. Persyaratan Sistem & Hardware

- **Sistem Operasi:** Android SDK 21 (Lollipop) ke atas. Android 12+ (SDK 31+) membutuhkan izin runtime tambahan.
- **Sisi Dosen (Advertising):** Membutuhkan perangkat fisik Android yang mendukung **BLE Peripheral Mode** (Bluetooth advertising). *Catatan: Android emulator tidak mendukung BLE advertising.*
- **Sisi Mahasiswa (Scanning):** Membutuhkan perangkat fisik Android yang memiliki hardware Bluetooth LE.

---

## 2. Dependensi Utama (`pubspec.yaml`)

- `provider`: Manajemen state lokal.
- `flutter_blue_plus`: Layanan pemindaian (scanning) Bluetooth LE untuk Mahasiswa.
- `flutter_ble_peripheral`: Layanan pemancaran (advertising) Bluetooth LE untuk Dosen.
- `firebase_core` & `cloud_firestore`: Database awan realtime untuk menyimpan sesi dan log presensi.
- `permission_handler`: Mengelola izin runtime Android (Bluetooth & Lokasi).
- `uuid`: Membuat ID sesi yang unik (v4 UUID).
- `intl`: Memformat tampilan tanggal dan waktu.
- `path_provider` & `share_plus`: Menyimpan log sementara dan membagikan berkas CSV hasil ekspor.
- `shared_preferences`: Menyimpan profil pengguna lokal (Nama, NIM) agar tidak perlu diisi ulang setiap membuka aplikasi.

---

## 3. Langkah-langkah Setup Firebase (Wajib untuk Realtime Sync)

1. Buka [Firebase Console](https://console.firebase.google.com/) dan buat proyek baru.
2. Tambahkan aplikasi **Android** ke dalam proyek Firebase Anda.
   - Gunakan nama paket (Package Name) yang terdaftar di Gradle: `com.example.presensible`
3. Unduh berkas **`google-services.json`** yang disediakan oleh Firebase.
4. Letakkan berkas `google-services.json` tersebut ke dalam direktori projek Anda di:
   ```
   [root-project]/android/app/google-services.json
   ```
5. Di Firebase Console, masuk ke bagian **Firestore Database** dan klik **Create Database**.
   - Mulai dalam **Test Mode** (agar aplikasi dapat menulis dan membaca data tanpa konfigurasi aturan keamanan yang ketat di awal).
   - Buat dua *collection* kosong:
     - `sessions`: Untuk menyimpan sesi kelas dosen.
     - `attendances`: Untuk menyimpan catatan presensi mahasiswa.

---

## 4. Konfigurasi Izin Android (`AndroidManifest.xml`)

Aplikasi telah dikonfigurasi untuk meminta izin berikut di `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- BLE Permissions -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>
```

---

## 5. Menjalankan Aplikasi

1. Sambungkan perangkat fisik Android Anda menggunakan kabel data dan aktifkan fitur USB Debugging.
2. Jalankan perintah berikut untuk mengunduh semua library dependensi:
   ```bash
   flutter pub get
   ```
3. Lakukan kompilasi dan jalankan aplikasi pada perangkat Anda:
   ```bash
   flutter run
   ```

*Tips:* Untuk membuat berkas installer APK demi keperluan demo presentasi, jalankan perintah:
```bash
flutter build apk --debug
```
Berkas APK akan berada di `build/app/outputs/flutter-apk/app-debug.apk`.

---

## 6. Prosedur Pengujian Jarak & RSSI

Aplikasi ini dilengkapi dengan menu logging khusus di layar Mahasiswa untuk membantu pengambilan data laporan (Bab Pengujian):

1. **Atur Threshold Kedekatan:** Threshold RSSI default diatur sebesar `-70 dBm` di berkas `lib/utils/constants.dart`. Anda dapat mengubah nilai konstanta `defaultRssiThreshold` di file tersebut untuk disesuaikan dengan kondisi ruangan uji coba.
2. **Lihat Log Live:** Saat mahasiswa melakukan pemindaian, layar akan menampilkan tabel status sinyal:
   - Nama Bluetooth Dosen (Format: `P-[NamaMataKuliah]`)
   - Nilai RSSI realtime (misal: `-58 dBm` untuk sinyal kuat, `-82 dBm` untuk sinyal lemah).
   - Indikator Status (contoh: "Memverifikasi sesi...", "Sinyal lemah. Dekati dosen!", atau "Presensi Berhasil!").
3. **Ekspor Data Uji:** Klik ikon **Share / Ekspor** di sudut kanan atas layar Mahasiswa. Berkas CSV akan digenerate berisi rekam jejak scan (Waktu, Nama Perangkat, UUID Sesi, RSSI, dan Status Akhir) yang bisa langsung Anda bagikan via email, WhatsApp, atau media sosial lainnya ke PC Anda untuk diolah di Excel.

# PianoKustik

Aplikasi Visualizer Piano & MIDI interaktif profesional dengan efek visual Synthesia spark bloom, deteksi chord otomatis real-time, dukungan Not Angka / Not Balok, dan koneksi kabel MIDI USB/Bluetooth.

---

## 🎹 Fitur Utama
- **Waterfall Visualizer 60 FPS**: Tampilan stick meluncur halus dengan efek Synthesia Strike Glow & Spark Burst saat tuts ditekan.
- **Deteksi Chord Real-time**: Menampilkan nama chord (misal: *A major*, *C major*, *G minor*) di pojok kiri bawah tuts secara elegan dan semi-transparan.
- **Tampilan Realistis**: Garis merah felt piano akustik, shadow tuts 3D, dan lighting dinamis.
- **Konfigurasi Fleksibel**:
  - Ganti warna waterfall (Gold, Emerald, Neon Cyan, Ruby, Electric Violet, dsb).
  - Tampilkan/sembunyikan not angka atau huruf not pada tuts dan stick meluncur.
- **Konektivitas MIDI**: Mendukung MIDI Keyboard melalui USB-OTG/USB-B atau Bluetooth MIDI.

---

## 🚀 Cara Export & Menjalankan di Windows (.EXE)

> 📘 **Untuk Panduan Lengkap Pemula / Non-IT:**  
> Silakan buka panduan langkah-demi-langkah lengkap di **[PANDUAN_PEMULA_WINDOWS.md](file:///home/okkata/develop/app/midi/PANDUAN_PEMULA_WINDOWS.md)**. Panduan tersebut memuat link download resmi, cara centang Visual Studio C++, ekstrak Flutter, dan setting Path.

### Opsi 1: Build Otomatis di Windows (Paling Mudah)
Jika Anda membuka folder proyek ini di komputer / laptop Windows:
1. Pastikan **Flutter SDK** dan **Visual Studio** (dengan komponen *"Desktop development with C++"*) sudah terpasang.
2. Klik ganda (double-click) file **`build_windows.bat`**.
3. File `.exe` beserta semua file dependensinya akan otomatis di-compile dan folder hasil build akan langsung terbuka di:
   ```
   build\windows\x64\runner\Release\PianoKustik.exe
   ```

### Opsi 2: Menggunakan Command Prompt / PowerShell di Windows
Buka terminal di folder proyek dan jalankan:
```bash
flutter pub get
flutter build windows --release
```
Hasil file executable:
`build\windows\x64\runner\Release\PianoKustik.exe` (sertakan seluruh isi folder `Release` saat memindahkan ke komputer lain).

### Opsi 3: Build Otomatis via GitHub Actions (Cloud CI/CD)
Tanpa perlu install Flutter atau Visual Studio di laptop Windows:
1. Push project ini ke repository GitHub Anda.
2. Buka tab **Actions** di GitHub, pilih workflow **Build PianoKustik Windows EXE**, lalu klik **Run workflow**.
3. Unduh file artifact **`PianoKustik-Windows-x64.zip`** yang sudah siap diekstrak dan langsung dijalankan di Windows!

---

## 🐧 Menjalankan di Linux
```bash
flutter pub get
flutter run -d linux
```

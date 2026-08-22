# pos_mobile_dev — proyek DEV

Salinan `pos_mobile` yang menembak **API dev**. Dibuat 22 Agustus 2026 dengan
`git clone` dari repo produksi lokal, jadi **seluruh riwayat git ikut terbawa**.

| | Produksi | Dev (proyek ini) |
|---|---|---|
| Folder | `../pos_mobile` | `pos_mobile_dev` |
| API | `https://api.estehcandi.com` | `https://api-dev.estehcandi.com` |
| `applicationId` | `com.example.pos_mobile` | `com.example.pos_mobile.dev` |
| Nama aplikasi | Esteh Candi App | **Esteh Candi DEV** |
| Remote git | `origin` → `shahbae/mobile-pos` | `prod` → `shahbae/mobile-pos` (baca saja) |

`applicationId` sengaja dibedakan supaya **kedua APK bisa terpasang berdampingan
di HP yang sama**. Tanpa itu, memasang APK dev akan menimpa aplikasi kasir yang
sedang dipakai dan menghapus sesi loginnya.

## Empat berkas yang membedakan proyek ini

Kalau menarik perubahan dari produksi, **keempat berkas ini jangan ikut ditimpa**:

```
.env                                    API_BASE_URL
android/app/build.gradle.kts            applicationId
android/app/src/main/AndroidManifest.xml  android:label
ios/Runner/Info.plist                   CFBundleDisplayName
```

## Menarik perbaikan dari produksi

Ini bagian yang paling gampang terlupakan. Karena kode dipisah jadi dua proyek,
setiap perbaikan bug di fondasi (printer, absensi, promo, sinkronisasi) **harus
dibawa ke sini secara sadar** — tidak ada yang mengingatkan.

```bash
git fetch prod

# lihat apa yang belum ada di sini
git log --oneline HEAD..prod/main

# ambil satu commit tertentu
git cherry-pick <sha>

# atau tarik semuanya
git merge prod/main
```

Karena riwayatnya sama, `cherry-pick` dan `merge` bekerja normal — inilah alasan
proyek ini di-clone lewat git, bukan disalin dengan `cp -r`.

> Setelah `merge prod/main`, **periksa keempat berkas di atas**. Merge bisa
> mengembalikan `API_BASE_URL` ke `api.estehcandi.com` tanpa konflik apa pun
> kalau baris itu ikut berubah di sisi produksi. Aplikasi tetap jalan normal —
> hanya saja datanya masuk ke database produksi. Kegagalan paling senyap di
> susunan ini.

Cek cepat sebelum build:

```bash
grep API_BASE_URL .env
grep applicationId android/app/build.gradle.kts
```

## Yang belum di-commit saat clone

Enam berkas pekerjaan pemotong kertas printer (18 Agustus) disalin manual karena
`git clone` tidak membawa working tree:

```
lib/data/models/receipt_model.dart
lib/data/services/printer_prefs.dart
lib/data/services/thermal_printer_service.dart
lib/presentation/pages/settings/printer_settings_page.dart
lib/presentation/providers/printer_provider.dart
pubspec.yaml
```

Sama persis dengan yang ada di `../pos_mobile`, dan **masih belum diuji ke
printer fisik** di kedua proyek.

## Remote GitHub

Belum ada. Kalau nanti dibuat repo sendiri:

```bash
git remote add origin git@github-shahbae:shahbae/<nama-repo-dev>.git
git push -u origin feat/revisi-2026-08-03
```

Remote `prod` biarkan tetap ada — itu jalur satu-satunya untuk menarik perbaikan.

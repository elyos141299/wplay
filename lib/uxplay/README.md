# lib/uxplay — submodule UxPlay (belum diunduh di salinan ini)

Folder ini tempatnya **UxPlay**: receiver AirPlay C/C++ yang sebenarnya,
dipakai iDescriptor v0.6.1 sebagai submodule `lib/uxplay`.

- Repo: https://github.com/iDescriptor/uxplay.git
- Commit terkunci di iDescriptor v0.6.1: `eaca2458946d8a283df3b872f25c6b7cc98be411`
- Lisensi: GPL-3.0 (teksnya ada di `../../licenses/GPL-3.0.txt`)
- Salinan yang sudah terunduh untuk dibedah ada di clone Phase 1:
  `~/workspace/wplay/upstream-idescriptor-v0.6.1/lib/uxplay/`

Kode UxPlay **tidak disalin utuh** ke folder app ini — cukup dirujuk
sebagai submodule supaya kredit, lisensi, dan riwayatnya tetap jelas.

Cara mengisi folder ini (pilih satu):

1. Kalau folder `app/` sudah jadi repo git:
   `git submodule update --init lib/uxplay`
2. Cara manual (Windows MSYS2 / Linux, dari folder `app/`):
   `bash scripts/fetch-uxplay.sh`

# Donway — Full System Rebuild

Repositori ini mempertahankan halaman utama dan aset branding Donway dari source asli. Backend dan skema Supabase mulai dari database bisnis kosong; tidak ada produk, saldo, akun demo, voucher, atau transaksi seed.

> **Status jujur:** ini adalah fondasi migrasi yang dapat dikonfigurasi, bukan klaim bahwa seluruh alur toko sudah production-ready. Login Supabase dan dashboard admin awal disediakan. Alur checkout/top up lengkap, edit/arsip produk, upload gambar dari dashboard, manajemen pengguna/pesanan, refund, voucher atomik, serta worker outbox Telegram masih perlu integrasi dan tes end-to-end sebelum menerima transaksi nyata. Fitur uang di UI lama sengaja dinonaktifkan bila belum punya backend tepercaya.

## Persyaratan
- Node.js 20+ dan npm
- Project Supabase
- Akun Vercel untuk deployment
- Git (opsional, untuk GitHub)

## Struktur
- `index.html`, aset PNG: UI dan branding asli
- `admin.html`: dashboard di `/admin`
- `api/_lib/supabase.js`: autentikasi token dan otorisasi admin
- `api/admin/summary.js`: ringkasan dashboard dari database
- `api/admin/products.js`: daftar dan pembuatan produk nonaktif
- `api/send-telegram.js`: endpoint lama sengaja dinonaktifkan karena menerima data sensitif
- `supabase/migrations/`: schema, RLS, RPC checkout/top up approval dan top up request
- `docs/`: audit, tes, deployment, keamanan

## Setup Supabase
1. Buat project baru di Supabase. Simpan URL project dan publishable/anon key untuk konfigurasi publik.
2. Jalankan seluruh isi `supabase/migrations/202610140001_initial_schema.sql` melalui SQL Editor atau gunakan Supabase CLI pada project yang sudah di-link.
3. Database sengaja kosong. Tidak ada produk aktif sampai admin membuat dan mengaktifkannya setelah implementasi manajemen produk lengkap.
4. Di Authentication → URL Configuration, atur Site URL ke domain Vercel dan Redirect URLs untuk domain lokal/preview/production yang benar.
5. Aktifkan email verification sesuai kebijakan toko dan sesuaikan template email. Uji alur konfirmasi dan reset password.
6. Untuk gambar, migration membuat bucket `donway-product-images` dengan batas 5 MB dan MIME JPEG/PNG/WebP. Uji kebijakan storage pada project staging.

### Membuat admin pertama secara aman
1. Daftarkan akun melalui Supabase Auth menggunakan email yang Anda kendalikan. Verifikasi email sesuai pengaturan.
2. Buka Authentication → Users dan salin UUID akun tersebut.
3. Jalankan SQL manual hanya sebagai project owner/DB operator, ganti UUID dengan UUID akun Anda:

```sql
update public.profiles
set role = 'admin', updated_at = now()
where id = 'GANTI_DENGAN_UUID_AUTH_USERS'
  and status = 'active';
```

4. Pastikan tepat satu baris berubah. Login di `https://domain-anda/admin` menggunakan email/password Supabase Auth yang dibuat sendiri.
5. Jangan membuat endpoint publik untuk mengangkat role admin. Jangan kirim password, token, service-role key, atau kredensial asli kepada pihak lain.

## Konfigurasi lokal
1. Salin `.env.example` menjadi `.env` untuk backend lokal saja. Jangan commit `.env`.
2. Isi variabel server pada environment lokal/Vercel. `SUPABASE_SERVICE_ROLE_KEY` hanya untuk server, jangan pernah dimasukkan ke `supabase-config.js` atau bundle browser.
3. Isi `supabase-config.js` dengan `SUPABASE_URL` dan `SUPABASE_ANON_KEY`/publishable key publik. Nilai ini memang dapat dilihat browser; RLS tetap wajib.
4. Jalankan `npm install` lalu `npm run check` dan `npm test`.
5. Jalankan `npx vercel dev` untuk mencoba routing Functions. Tes dengan project Supabase staging terlebih dahulu.

## Variabel environment
- `SUPABASE_URL`: server URL project.
- `SUPABASE_ANON_KEY` atau `SUPABASE_PUBLISHABLE_KEY`: key publik untuk memverifikasi token; juga dapat dipakai di browser sebagai publishable key.
- `SUPABASE_SERVICE_ROLE_KEY`: server-only, bypass RLS; simpan sebagai Secret di Vercel.
- `APP_BASE_URL`: URL situs.
- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`: opsional, hanya untuk worker notifikasi backend yang belum diaktifkan.
- `ADMIN_BOOTSTRAP_SECRET`: belum digunakan pada desain saat ini; admin pertama ditetapkan secara manual melalui SQL oleh operator tepercaya. Jangan set variabel yang tidak digunakan.

Di Vercel, isi Environment Variables secara terpisah untuk Development, Preview, dan Production. Setelah mengganti secret, rotasi juga secret lama di penyedia terkait lalu redeploy. Periksa hasil build agar key service-role tidak ada pada asset publik.

## Deploy Vercel
1. Push source ke repository GitHub pribadi.
2. Import repository ke Vercel dan pastikan Root Directory adalah root proyek.
3. Tambahkan server environment variables pada Vercel. Jangan upload file `.env`.
4. Pastikan `supabase-config.js` memuat URL dan key publik yang benar.
5. Deploy ke Preview dahulu. Tes `/`, `/admin`, login user, penolakan akses admin, dan API.
6. Konfigurasikan Site URL/Redirect URLs Supabase untuk domain final, lalu deploy Production.
7. Setelah perubahan konfigurasi atau kode, lakukan redeploy dan uji ulang.

## Produk dan foto
Endpoint saat ini mendukung daftar produk dan pembuatan produk nonaktif. Dashboard belum menyelesaikan edit/arsip/aktivasi maupun alur upload Storage, jadi jangan mengaktifkan transaksi production berdasarkan versi ini. Produk baru harus tetap nonaktif hingga kategori, foto, stok, harga, dan proses pemenuhan tervalidasi.

## Durasi top up
RPC `create_topup_request` membaca `store_settings.topup_default_duration_minutes` (default 30 menit bila belum diisi), kemudian override aktif dari `user_topup_settings`, lalu menyimpan snapshot `duration_minutes` dan `expires_at` memakai waktu database. Pengelolaan UI admin untuk konfigurasi dan override belum tersedia. Approval memeriksa status pending dan expiry dalam transaksi database.

## Telegram
Endpoint Telegram lama dinonaktifkan karena dapat mengirim password/PIN. Telegram belum aktif dalam alur baru; token bot hanya boleh dipakai di backend dan notifikasi harus dikirim dari outbox setelah transaksi berhasil. Aplikasi tetap berfungsi tanpa Telegram.

## Pengujian dan keterbatasan
Lihat `docs/TEST-REPORT.md`. Tanpa kredensial project Supabase/Vercel, integrasi eksternal tidak dapat diverifikasi dari lingkungan ini. Jangan menerima uang sungguhan sampai checklist integrasi dan fitur yang belum selesai dinyatakan lulus.

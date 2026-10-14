# Panduan Deployment Vercel + Supabase

1. Buat project Supabase baru dan catat URL serta publishable/anon key.
2. Jalankan `supabase/migrations/202610140001_initial_schema.sql` di SQL Editor pada project staging terlebih dahulu. Pastikan seluruh statement berhasil.
3. Isi `supabase-config.js` dengan URL dan key publik. Jangan isi service-role key di sana.
4. Buat akun admin melalui Supabase Auth, verifikasi email, lalu jalankan SQL role assignment di README menggunakan UUID yang benar.
5. Push source ke GitHub, import ke Vercel, tambahkan `SUPABASE_URL`, `SUPABASE_ANON_KEY`/`SUPABASE_PUBLISHABLE_KEY`, dan `SUPABASE_SERVICE_ROLE_KEY` di Environment Variables server.
6. Tambahkan `APP_BASE_URL`. Telegram variables tidak diperlukan sampai worker Telegram diimplementasikan.
7. Deploy Preview. Uji `/`, `/admin`, login valid, login invalid, pengguna biasa ditolak API admin, dan API summary.
8. Atur Site URL dan Redirect URLs Supabase sesuai URL final. Uji email verification/reset password.
9. Setelah checklist tes lulus, deploy Production dan uji ulang. Jangan menyimpan `.env` ke Git.

## Secret rotation
Jika service-role key pernah terpublikasi, rotate key dari Supabase, update environment Vercel, redeploy semua environment terkait, lalu periksa riwayat Git dan build output.

# Catatan Keamanan

- Supabase publishable/anon key boleh berada di browser hanya dengan RLS yang benar. `SUPABASE_SERVICE_ROLE_KEY` hanya boleh berada di backend.
- Admin API memverifikasi Bearer token melalui Supabase Auth dan memeriksa `profiles.role='admin'` serta `status='active'` menggunakan server key.
- Jangan mengangkat role berdasarkan email yang dikirim browser. Tetapkan UUID admin melalui SQL sebagai operator project tepercaya.
- Jangan mengirim password, PIN, access token, cookie, atau service key melalui Telegram/log.
- Endpoint Telegram lama dikembalikan sebagai 410. Notifikasi baru belum diaktifkan; nantinya harus diproses melalui outbox dari backend.
- RLS diaktifkan pada tabel privat/finansial. Tidak ada policy akses universal untuk tabel sensitif. Stok digital rahasia tidak memiliki policy baca client.
- Checkout menggunakan RPC dengan penguncian produk dan wallet, harga dibaca dari DB, idempotency key unik, serta ledger dalam satu transaksi database.
- Approval top up mengunci request, memeriksa pending dan expiry, menambah saldo serta ledger dalam satu transaksi.
- API admin produk saat ini hanya membuat produk nonaktif dan membaca daftar. Implementasi ini belum cukup untuk operasional toko.
- Sebelum production: tambah rate limiting (misalnya middleware/provider), validasi payload maksimum di semua API, CSP yang diuji, upload content sniffing, worker outbox, observability, backup/PITR, audit alert, serta tes concurrency dan pen-test.
- Lakukan rotasi kredensial lama yang pernah dipakai pada source, terutama password hardcoded dan token bot bila pernah ada di riwayat repository.

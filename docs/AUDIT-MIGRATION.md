# Audit dan Migrasi Donway

Audit berdasarkan file yang benar-benar terdapat pada `AkhirDonway-main.zip`.

| Komponen | Implementasi Lama | Implementasi Baru | Status | Bukti/Referensi File |
|---|---|---|---|---|
| UI toko | Satu halaman HTML dengan CSS/JS inline dan aset PNG | UI lama dipertahankan, katalog production kosong | Sebagian | `index.html`, aset root |
| Framework | HTML statis; tidak ada package manager | Tetap HTML statis + Vercel Functions ESM | Selesai untuk fondasi | `package.json`, `vercel.json` |
| Autentikasi | Akun/password disimpan di localStorage; hardcoded admin | Supabase Auth; login UI baru mengonsumsi sesi Supabase | Sebagian; perlu tes project | `index.html`, `admin.html`, `supabase-config.js` |
| Otorisasi admin | Email khusus dan password hardcoded di browser | UUID role di `profiles`, API memverifikasi token, role dan status | Fondasi tersedia | `api/_lib/supabase.js`, `api/admin/*.js`, migration |
| Profil | Profil/PIN disimpan lokal | `profiles` dan RLS; form profil lama belum seluruhnya dimigrasikan | Belum selesai | `index.html`, migration |
| Katalog | Array `PRODUCTS` statis dengan harga dan stok | Array produk aktif dihapus; tabel `products` kosong dan API daftar/create | Sebagian | `index.html`, `api/admin/products.js`, migration |
| Kategori | Array `CATEGORIES` statis | `product_categories` dan policy katalog publik | Schema tersedia; CRUD admin belum tersedia | migration |
| Stok/inventori digital | Stok angka statis di browser | Kolom stok terkunci DB + tabel stock rahasia dengan RLS aktif | Sebagian; reservasi stok digital belum selesai | migration |
| Checkout/saldo | Saldo dan transaksi dimutasi dari browser | RPC checkout atomik dan wallet ledger dalam migration; UI checkout dinonaktifkan | RPC tersedia, integrasi UI belum selesai | migration, `index.html` |
| Top up | Tombol browser dapat menambah saldo lokal tanpa bukti pembayaran | Request RPC dengan expiry server dan approval admin atomik | Fondasi DB tersedia; API/dashboard belum lengkap | migration, `index.html` |
| Voucher | Kode dan penebusan di localStorage | Tabel voucher/redemption dengan RLS | Schema tersedia; RPC redemption belum tersedia | `index.html`, migration |
| Telegram | Endpoint universal menerima event arbitrary, berisi jalur pengiriman password/PIN | Endpoint lama mengembalikan 410; token tak lagi dipakai endpoint publik | Risiko utama dimitigasi; outbox worker belum dibuat | `api/send-telegram.js`, migration |
| Dashboard admin | Tidak ditemukan dashboard terpisah | Route `/admin`, data summary DB, create/list produk | Sebagian; CRUD lengkap belum ada | `admin.html`, `api/admin/summary.js`, `api/admin/products.js` |
| Storage | Tidak ada alur Storage Supabase | Bucket + policy upload admin pada migration | Policy tersedia; UI upload belum tersedia | migration |
| Notifikasi | Beberapa data dikirim langsung dari browser ke Telegram | Tabel notifications dan outbox; worker belum tersedia | Schema tersedia | migration |
| Deployment | Rewrite semua `/api/*` ke endpoint Telegram | Routing `/admin`; API file routing Vercel native | Diperbaiki | `vercel.json` |
| Secret | Password Chat AI hardcoded; endpoint Telegram menerima data sensitif | Password Chat AI lama dinonaktifkan; endpoint Telegram lama dinonaktifkan; contoh env tanpa secret | Sebagian; rotasi rahasia historis disarankan | `index.html`, `.env.example`, `api/send-telegram.js` |
| Data awal | Produk, harga, stok, voucher dan bulletin tertanam | Migrasi tidak melakukan seed produk/saldo/pesanan/user/voucher | Katalog frontend kosong; bulletin lama masih perlu ditinjau untuk menampilkan hanya data DB | `index.html`, migration |

## Catatan bukti keamanan
- Source lama menggunakan `registered_users`, `user_session`, `blurpay_db_aman`, dan `used_vouchers` di localStorage.
- Fungsi lama mengirim password/PIN ke handler Telegram pada alur registrasi, update profil, dan bantuan PIN. Handler tersebut sekarang dinonaktifkan dan payload lama dikurangi.
- Source lama memiliki kredensial admin hardcoded dan password untuk membuka chat AI. Login lama diganti dengan Supabase Auth; pemeriksaan password Chat AI lama dinonaktifkan.
- Tidak ada kredensial Supabase asli dalam ZIP. Admin pertama harus ditetapkan manual oleh operator project menggunakan UUID `auth.users`.

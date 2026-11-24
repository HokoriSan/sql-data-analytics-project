# Proyek Analitik Data dengan SQL

Selamat datang di repositori **Proyek Analitik Data dengan SQL** saya! 📊
Proyek ini adalah latihan saya dalam mengeksplorasi dan menganalisis data penjualan menggunakan SQL Server, mulai dari membuat database, memuat data dari file CSV, sampai menghasilkan insight. Saya masih pemula dan sedang belajar SQL untuk menjadi data engineer, jadi repositori ini juga berfungsi sebagai catatan perjalanan belajar sekaligus portofolio awal saya.

> 📚 **Catatan:** Proyek ini saya kerjakan sambil mengikuti materi dari [Data With Baraa](https://www.youtube.com/@DataWithBaraa) sebagai acuan. Saya menulis ulang dan mengerjakannya sendiri langkah demi langkah untuk memahami konsepnya.

---

## Tujuan Belajar

- Memahami alur dasar analisis data dengan SQL, dari data mentah sampai insight
- Melatih kemampuan SQL: `JOIN`, agregasi, `GROUP BY`, dan window function
- Belajar mengeksplorasi data (*Exploratory Data Analysis*) secara terstruktur
- Terbiasa memakai GitHub untuk menyimpan dan mendokumentasikan proyek

---

## Kebutuhan Proyek

### Menyiapkan Database (Data Engineering)

#### Tujuan
Membuat database `DataWarehouseAnalytics` di SQL Server dan memuat data penjualan dari file CSV agar siap dianalisis.

#### Spesifikasi
- **Sumber Data**: File CSV (`dim_customers`, `dim_products`, `fact_sales`) yang harus diunduh dari sumber masing-masing.
- **Model Data**: Star schema di schema `gold`, terdiri dari dua tabel dimensi dan satu tabel fakta.
- **Pemuatan Data**: Menggunakan `BULK INSERT`.
- **Dokumentasi**: Setiap script diberi komentar dan peringatan dalam bahasa Indonesia.

---

### Analitik dan Eksplorasi Data (Analisis Data)

#### Tujuan
Membuat analisis berbasis SQL untuk mendapatkan insight tentang:

- **Struktur Data**: tabel, kolom, dimensi, dan rentang tanggal
- **Performa Bisnis**: total sales, quantity, harga rata-rata, dan jumlah order
- **Perilaku Pelanggan**: sebaran pelanggan per negara dan gender, revenue per pelanggan
- **Performa Produk**: revenue per kategori, serta produk dengan revenue tertinggi dan terendah

---

## Model Data

| Tabel | Tipe | Deskripsi |
|-------|------|-----------|
| `gold.dim_customers` | Dimensi | Data pelanggan: nama, negara, gender, status pernikahan, tanggal lahir |
| `gold.dim_products` | Dimensi | Data produk: nama, kategori, subkategori, biaya, product line |
| `gold.fact_sales` | Fakta | Transaksi penjualan: order, tanggal, sales amount, quantity, harga |

Relasi:
- `fact_sales.product_key` → `dim_products.product_key`
- `fact_sales.customer_key` → `dim_customers.customer_key`

---

## Struktur Repositori

```
sql-data-analytics-project/
│
├── datasets/
│   └──               # Taruh file CSV di sini
│
├── scripts/
│   ├── init_database.sql
│   └── exploratory_data_analysis.sql
│
├── LICENSE
└── README.md
**
```
---

## Cara Menjalankan

1. Unduh dataset dari sumber masing-masing, lalu simpan di folder `datasets/`.
2. Buka `init_database.sql` dan **ganti path file CSV** pada setiap `BULK INSERT` sesuai lokasi di komputer kamu.
3. Jalankan `init_database.sql` untuk membuat database dan memuat data.
4. Jalankan `exploratory_data_analysis.sql` **blok per blok** untuk melihat hasil tiap analisis.

---

## ⚠️ Peringatan

- `init_database.sql` akan **menghapus database `DataWarehouseAnalytics` secara permanen** jika sudah ada. Pastikan sudah membuat backup dan terhubung ke SQL Server instance yang benar.
- File CSV **tidak disertakan** di repositori ini dan harus diambil dari **sumber datanya masing-masing**. Hasil analisis bisa berbeda jika datamu berbeda.
- Path pada `BULK INSERT` spesifik untuk satu komputer dan wajib diganti.
- Script eksplorasi hanya membaca data (`SELECT`) dan tidak mengubah isi database.

---

## Teknologi yang Digunakan

- SQL Server
- SQL (query, join, agregasi, window function)
- File CSV sebagai sumber data
- GitHub untuk dokumentasi

---

## Status Proyek

🚧 **Sedang dikerjakan.** Saya masih belajar, jadi query dalam repositori ini akan terus diperbaiki dan ditambah seiring bertambahnya pemahaman saya.

- [x] Membuat database dan memuat data CSV ke SQL Server
- [x] Eksplorasi database, dimensi, dan tanggal
- [x] Eksplorasi measure dan analisis per dimensi
- [x] Analisis ranking (top dan bottom produk)
- [ ] Analisis tren waktu
- [ ] Menulis dokumentasi tambahan

---

## Masukan

Karena saya masih pemula, saran dan koreksi sangat saya hargai! Silakan buka *issue* atau hubungi saya jika ada yang bisa diperbaiki.

---

## Lisensi

Proyek ini berlisensi MIT. Silakan digunakan, diubah, dan dibagikan dengan mencantumkan atribusi.

---

## Tentang Saya

Halo, saya Mohamad Hasan Arifa. Saya sedang belajar untuk menjadi data engineer. Saat ini saya fokus mendalami SQL. Saya belum punya pengalaman kerja di bidang IT, tetapi saya serius membangun fondasi dan mendokumentasikan prosesnya di sini.

📫 Terhubung dengan saya: [LinkedIn / GitHub / Email]

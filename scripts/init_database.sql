/*
=============================================================
Membuat Database dan Schema, Lalu Memuat Data
=============================================================
Tujuan Script:
    Membuat database baru bernama 'DataWarehouseAnalytics'. Jika database
    sudah ada, database akan dihapus lalu dibuat ulang. Script ini kemudian
    membuat schema 'gold' beserta tiga tabel (dim_customers, dim_products,
    fact_sales) dan mengisinya dari file CSV menggunakan BULK INSERT.

PERINGATAN:
    Menjalankan script ini akan MENGHAPUS database 'DataWarehouseAnalytics'
    secara permanen jika sudah ada. SEMUA DATA DI DALAMNYA AKAN HILANG.
    Pastikan sudah membuat backup dan pastikan kamu terhubung ke
    SQL Server instance yang benar sebelum menjalankan.

SUMBER DATA:
    File CSV TIDAK disertakan di dalam script ini. Dataset harus diambil
    dari sumber masing-masing (misalnya repository GitHub proyek asalnya),
    lalu diunduh dan disimpan di komputer kamu sendiri. Path pada BULK INSERT
    di bawah hanya contoh dari komputer pembuat script dan WAJIB diganti
    sesuai lokasi file di komputermu.

Sebelum Menjalankan:
    1. Unduh dataset dari sumbernya masing-masing.
    2. Ubah path file CSV pada setiap BULK INSERT sesuai lokasi di komputermu.
    3. Akun service SQL Server harus punya izin baca ke folder tersebut.
    4. Gunakan login yang punya izin membuat dan menghapus database.
*/

USE master;

-- Hapus database jika sudah ada. SINGLE_USER + ROLLBACK IMMEDIATE akan
-- memutus semua koneksi aktif dan membatalkan transaksi yang sedang berjalan
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouseAnalytics')
BEGIN
    ALTER DATABASE DataWarehouseAnalytics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouseAnalytics;
END;

-- Buat database baru
CREATE DATABASE DataWarehouseAnalytics;

USE DataWarehouseAnalytics;

-- Buat schema 'gold' (berisi tabel final yang siap dianalisis).
-- Memakai EXEC karena CREATE SCHEMA harus berada di awal batch, sedangkan GO sudah dihapus
EXEC('CREATE SCHEMA gold');

-- Tabel dimensi: atribut pelanggan
CREATE TABLE gold.dim_customers(
	customer_key int,
	customer_id int,
	customer_number nvarchar(50),
	first_name nvarchar(50),
	last_name nvarchar(50),
	country nvarchar(50),
	marital_status nvarchar(50),
	gender nvarchar(50),
	birthdate date,
	create_date date
);

-- Tabel dimensi: atribut produk
CREATE TABLE gold.dim_products(
	product_key int ,
	product_id int ,
	product_number nvarchar(50) ,
	product_name nvarchar(50) ,
	category_id nvarchar(50) ,
	category nvarchar(50) ,
	subcategory nvarchar(50) ,
	maintenance nvarchar(50) ,
	cost int,
	product_line nvarchar(50),
	start_date date
);

-- Tabel fakta: transaksi penjualan (terhubung ke dimensi lewat product_key dan customer_key)
CREATE TABLE gold.fact_sales(
	order_number nvarchar(50),
	product_key int,
	customer_key int,
	order_date date,
	shipping_date date,
	due_date date,
	sales_amount int,
	quantity tinyint,
	price int
);

/*
Memuat data dari file CSV.
    FIRSTROW = 2       -> lewati baris header
    ROWTERMINATOR      -> 0x0a (LF); ganti ke '0x0d0a' jika file memakai line ending Windows
    CODEPAGE = '65001' -> encoding UTF-8
    TABLOCK            -> kunci tabel agar bulk load lebih cepat
CATATAN:
    - TRUNCATE menghapus semua baris lama sebelum data dimuat.
    - Path file di bawah spesifik untuk satu komputer. Ganti sesuai lokasi
      file CSV dari sumber datamu masing-masing.
*/

TRUNCATE TABLE gold.dim_customers;

BULK INSERT gold.dim_customers
FROM 'D:\Developer\SQL\sql-data-analytics-project\datasets\flat-files\dim_customers.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
	TABLOCK
);

TRUNCATE TABLE gold.dim_products;

BULK INSERT gold.dim_products
FROM 'D:\Developer\SQL\sql-data-analytics-project\datasets\flat-files\dim_products.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
	TABLOCK
);

TRUNCATE TABLE gold.fact_sales;

BULK INSERT gold.fact_sales
FROM 'D:\Developer\SQL\sql-data-analytics-project\datasets\flat-files\fact_sales.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
	TABLOCK
);

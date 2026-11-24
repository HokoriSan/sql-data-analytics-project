/*
=============================================================
Eksplorasi Data: DataWarehouseAnalytics
=============================================================
Tujuan Script:
    Mengeksplorasi database 'DataWarehouseAnalytics' (schema 'gold'):
    struktur database, dimensi, rentang tanggal, ukuran bisnis (measure),
    analisis per dimensi, dan ranking produk berdasarkan revenue.

PERINGATAN:
    - Script ini hanya membaca data (SELECT), tidak mengubah atau menghapus apa pun.
    - Jalankan setelah script init database selesai dan semua tabel sudah terisi.
    - Jalankan query satu per satu (blok per blok), bukan sekaligus.
    - Dataset harus berasal dari sumber masing-masing. Hasil angka bisa
      berbeda jika datamu berbeda dari dataset aslinya.
*/

-- ====================================================================
-- EKSPLORASI DATABASE
-- ====================================================================

-- Daftar semua tabel di database
SELECT *
FROM INFORMATION_SCHEMA.TABLES;

-- Daftar semua kolom beserta tipe datanya
SELECT *
FROM INFORMATION_SCHEMA.COLUMNS;

-- ====================================================================
-- EKSPLORASI DIMENSI
-- ====================================================================

-- Daftar negara asal pelanggan (tanpa duplikat)
SELECT DISTINCT country
FROM gold.dim_customers dc ;

-- Hierarki produk: category > subcategory > product_name
SELECT DISTINCT category, subcategory, dp.product_name 
FROM gold.dim_products dp
ORDER BY 1,2,3;

-- ====================================================================
-- EKSPLORASI TANGGAL
-- ====================================================================

-- Rentang tanggal order, dari order pertama sampai terakhir.
-- PERINGATAN: DATEDIFF(year) menghitung selisih pergantian tahun kalender,
-- bukan selisih tahun penuh (31 Des 2013 ke 1 Jan 2014 dihitung 1 tahun)
SELECT 
	MIN(fs.order_date) AS first_order_date,
	MAX(fs.order_date ) AS last_order_date,
	DATEDIFF(year, MIN(fs.order_date),MAX(fs.order_date)) AS order_range_year
FROM gold.fact_sales fs ;

-- Pelanggan tertua dan termuda berdasarkan tanggal lahir.
-- PERINGATAN: umur bersifat perkiraan (alasan sama dengan DATEDIFF di atas)
-- dan bergantung pada tanggal saat query dijalankan (GETDATE)
SELECT 
	MIN(dc.birthdate ) AS oldest_customer,
	DATEDIFF(year,MIN(dc.birthdate),GETDATE()) AS oldest_age,
	MAX(dc.birthdate ) AS youngest_customer,
	DATEDIFF(year,MAX(dc.birthdate),GETDATE()) as youngest_age
FROM gold.dim_customers dc ;

-- ====================================================================
-- EKSPLORASI MEASURE (UKURAN BISNIS)
-- ====================================================================

-- Total penjualan
SELECT SUM(fs.sales_amount ) AS total_sales
FROM gold.fact_sales fs ;

-- Total item yang terjual
SELECT SUM(fs.quantity) AS total_items
FROM gold.fact_sales fs ;

-- Rata-rata harga jual.
-- PERINGATAN: kolom price bertipe int, sehingga hasil AVG dibulatkan ke bawah
-- (tidak ada desimal). Pakai AVG(CAST(fs.price AS decimal(18,2))) jika butuh presisi
SELECT AVG(fs.price ) AS average_price
FROM gold.fact_sales fs ;

-- Total order unik (satu order bisa berisi banyak baris, maka pakai DISTINCT)
SELECT COUNT(DISTINCT fs.order_number ) AS total_order
FROM gold.fact_sales fs ;

-- Total produk
SELECT COUNT(dp.product_key )
FROM gold.dim_products dp ;

-- Total pelanggan
SELECT COUNT(dc.customer_key  )
FROM gold.dim_customers dc  ;

-- Total pelanggan yang pernah melakukan order
SELECT COUNT(DISTINCT fs.customer_key )
FROM gold.fact_sales fs ;

-- Laporan ringkasan semua measure dalam satu tabel.
-- CATATAN: UNION ALL mensyaratkan jumlah dan tipe kolom yang kompatibel di semua bagian
SELECT 'Total Sales' AS measure_name, SUM(fs.sales_amount ) AS measure_value FROM gold.fact_sales fs
UNION ALL
SELECT 'Total Quantity', SUM(fs.quantity) FROM gold.fact_sales fs
UNION ALL
SELECT 'Average Price', AVG(fs.price ) FROM gold.fact_sales fs
UNION ALL
SELECT 'Total Order', COUNT(DISTINCT fs.order_number ) FROM gold.fact_sales fs
UNION ALL
SELECT 'Total Products', COUNT(dp.product_key ) FROM gold.dim_products dp
UNION ALL
SELECT 'Total Customers', COUNT(dc.customer_key  ) FROM gold.dim_customers dc;

-- ====================================================================
-- ANALISIS BERDASARKAN DIMENSI
-- ====================================================================

-- Total pelanggan per negara, diurutkan dari yang terbanyak.
-- PERINGATAN: DESC harus ada di ORDER BY, bukan di GROUP BY (akan error)
SELECT
	dc.country ,
	COUNT(dc.customer_key) AS total_customers
FROM gold.dim_customers dc 
GROUP BY dc.country
ORDER BY total_customers DESC;

-- Total pelanggan per gender
SELECT
	dc.gender  ,
	COUNT(dc.customer_key) AS total_customers
FROM gold.dim_customers dc 
GROUP BY dc.gender ;

-- Total produk per kategori
SELECT
	dp.category ,
	COUNT(dp.product_key) AS total_products
FROM gold.dim_products dp 
GROUP BY dp.category ;

-- Rata-rata biaya (cost) per kategori.
-- PERINGATAN: cost bertipe int, jadi rata-rata dibulatkan ke bawah
SELECT
	dp.category ,
	AVG(dp.cost ) AS average_cost
FROM gold.dim_products dp 
GROUP BY dp.category 
ORDER BY average_cost DESC;

-- Total revenue per kategori.
-- PERINGATAN: LEFT JOIN memunculkan kategori NULL jika ada penjualan
-- yang product_key-nya tidak ditemukan di dim_products
SELECT
	dp.category ,
	SUM(fs.sales_amount ) AS total_revenue
FROM gold.fact_sales fs 
LEFT JOIN gold.dim_products dp ON dp.product_key = fs.product_key 
GROUP BY dp.category 
ORDER BY total_revenue DESC;

-- Total revenue per pelanggan.
-- CATATAN: customer_key ikut di GROUP BY agar dua pelanggan dengan nama sama tidak tergabung
SELECT
	dc.customer_key ,
	dc.first_name ,
	dc.last_name ,
	SUM(fs.sales_amount ) AS total_revenue
FROM gold.fact_sales fs 
LEFT JOIN gold.dim_customers dc ON dc.customer_key  = fs.customer_key  
GROUP BY 
	dc.customer_key ,
	dc.first_name ,
	dc.last_name
ORDER BY total_revenue DESC;

-- Total item terjual per negara pelanggan
SELECT
	dc.country ,
	SUM(fs.quantity  ) AS total_sold_item
FROM gold.fact_sales fs 
LEFT JOIN gold.dim_customers dc ON dc.customer_key  = fs.customer_key  
GROUP BY dc.country 
ORDER BY total_sold_item  DESC;

-- ====================================================================
-- ANALISIS RANKING
-- ====================================================================

-- 5 produk dengan revenue tertinggi.
-- CATATAN: ROW_NUMBER memberi nomor unik; produk dengan revenue sama
-- tetap mendapat nomor berbeda. Pakai DENSE_RANK jika ingin ranking sama
SELECT TOP 5
	dp.product_name  ,
	SUM(fs.sales_amount ) AS total_revenue,
	ROW_NUMBER() OVER(ORDER BY SUM(fs.sales_amount) DESC) AS ranking_revenue
FROM gold.fact_sales fs 
LEFT JOIN gold.dim_products dp 
	ON dp.product_key = fs.product_key
GROUP BY dp.product_name 
ORDER BY total_revenue DESC;

-- 5 produk dengan revenue terendah.
-- PERINGATAN: urutan di ROW_NUMBER harus ASC agar ranking 1 = revenue terendah.
-- Jika memakai DESC, nomor rankingnya akan terbalik dan menyesatkan (misalnya 97, 96, ...)
SELECT TOP 5
	dp.product_name  ,
	SUM(fs.sales_amount ) AS total_revenue,
	ROW_NUMBER() OVER(ORDER BY SUM(fs.sales_amount) ASC) AS ranking_revenue
FROM gold.fact_sales fs 
LEFT JOIN gold.dim_products dp 
	ON dp.product_key = fs.product_key
GROUP BY dp.product_name 
ORDER BY total_revenue ASC;

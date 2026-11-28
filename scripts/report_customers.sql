/*
===============================================================================
Laporan Pelanggan
===============================================================================
Tujuan:
    - Laporan ini mengonsolidasikan metrik dan perilaku utama pelanggan

Sorotan:
    1. Mengumpulkan kolom-kolom penting seperti nama, usia, dan detail transaksi.
    2. Mengelompokkan pelanggan ke dalam kategori (VIP, Reguler, Baru) dan kelompok usia.
    3. Mengagregasi metrik tingkat pelanggan:
        - total pesanan
        - total penjualan
        - total kuantitas yang dibeli
        - total produk
        - masa aktif (dalam bulan)
    4. Menghitung KPI yang bernilai:
        - recency (jumlah bulan sejak pesanan terakhir)
        - nilai rata-rata pesanan
        - rata-rata pengeluaran bulanan

Peringatan:
    - CREATE OR ALTER VIEW membutuhkan SQL Server 2016 SP1 ke atas.
    - Pernyataan CREATE VIEW harus menjadi pernyataan pertama dalam batch.
      Jalankan terpisah dari query lain (di SSMS, pisahkan dengan GO).
    - Recency dihitung terhadap GETDATE(), bukan terhadap tanggal terakhir di
      data. Jika datanya historis, semua pelanggan akan tampak sangat lama
      tidak aktif. Untuk data historis, ganti GETDATE() dengan
      (SELECT MAX(order_date) FROM gold.fact_sales).
    - DATEDIFF(month, ...) menghitung pergantian bulan kalender, bukan jarak
      penuh 30 hari. 31 Jan sampai 1 Feb dihitung 1 bulan.
    - Batas segmen (5000 dan 12 bulan) serta batas usia (20 dan 50) ditulis
      langsung (hardcode). Sesuaikan dengan kebutuhan bisnis.

PERUBAHAN dari versi awal:
    - CREATE VIEW menjadi CREATE OR ALTER VIEW agar bisa dijalankan ulang
      tanpa error "view sudah ada".
    - LEFT JOIN menjadi INNER JOIN agar baris penjualan tanpa pelanggan tidak
      membentuk satu grup customer_key NULL.
    - Usia dihitung akurat (memperhitungkan apakah ulang tahun tahun ini
      sudah lewat), bukan selisih tahun kalender.
    - Segmen Regular memakai total_sales <= 5000. Sebelumnya (< 5000) membuat
      pelanggan dengan total tepat 5000 salah masuk 'New'.
    - Pelanggan tanpa tanggal lahir kini masuk age_group 'Unknown'. Sebelumnya
      jatuh ke '50 Above' lewat ELSE.
    - Label '50 Above' menjadi 'Above 50' dengan batas eksplisit. Usia tepat
      50 tetap masuk '20-50'.
    - avg_monthly_spend: jika lifespan = 0 (semua pesanan dalam satu bulan),
      hasilnya total_sales, bukan 0, karena 0 menyesatkan untuk pelanggan
      yang jelas punya penjualan.
    - total_sales di-CAST ke DECIMAL agar pembagian tidak dibulatkan ke bawah
      jika sales_amount bertipe integer.
===============================================================================
*/

-- base_query: mengambil data transaksi dan pelanggan, hanya baris dengan order_date valid.
-- customer_aggregation: merangkum metrik per pelanggan (pesanan, penjualan, kuantitas, produk, lifespan).
-- SELECT akhir: menambah segmentasi, recency, AOV, dan rata-rata pengeluaran bulanan.
CREATE OR ALTER VIEW gold.report_customers AS
WITH base_query AS (
	SELECT
		fs.order_number,
		fs.product_key,
		fs.order_date,
		fs.sales_amount,
		fs.quantity,
		dc.customer_key,
		dc.customer_number,
		CONCAT(dc.first_name, ' ', dc.last_name) AS customer_name,
		DATEDIFF(year, dc.birthdate, GETDATE())
			- CASE WHEN DATEADD(year, DATEDIFF(year, dc.birthdate, GETDATE()), dc.birthdate) > GETDATE()
				   THEN 1 ELSE 0 END AS age
	FROM gold.fact_sales fs
	INNER JOIN gold.dim_customers dc
		ON dc.customer_key = fs.customer_key
	WHERE fs.order_date IS NOT NULL
),
customer_aggregation AS (
	SELECT
		customer_key,
		customer_number,
		customer_name,
		age,
		COUNT(DISTINCT order_number) AS total_orders,
		SUM(sales_amount) AS total_sales,
		SUM(quantity) AS total_quantity,
		COUNT(DISTINCT product_key) AS total_products,
		MAX(order_date) AS last_order_date,
		DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
	FROM base_query
	GROUP BY
		customer_key,
		customer_number,
		customer_name,
		age
)
SELECT
	customer_key,
	customer_number,
	customer_name,
	age,
	CASE WHEN age IS NULL THEN 'Unknown'
		 WHEN age < 20 THEN 'Under 20'
		 WHEN age <= 50 THEN '20-50'
		 ELSE 'Above 50'
	END AS age_group,
	CASE WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
		 WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
		 ELSE 'New'
	END AS customer_segment,
	last_order_date,
	DATEDIFF(month, last_order_date, GETDATE()) AS recency,
	total_orders,
	total_sales,
	total_quantity,
	total_products,
	lifespan,
	COALESCE(CAST(total_sales AS DECIMAL(18,2)) / NULLIF(total_orders, 0), 0) AS avg_order_sales,
	CASE WHEN lifespan = 0 THEN total_sales
		 ELSE CAST(total_sales AS DECIMAL(18,2)) / lifespan
	END AS avg_monthly_spend
FROM customer_aggregation;

-- Pengecekan hasil view. Hapus atau jalankan terpisah setelah view dibuat.
SELECT *
FROM gold.report_customers;

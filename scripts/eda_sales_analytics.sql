-- ============================================================================
-- ANALISIS PERUBAHAN TREN DARI WAKTU KE WAKTU
-- ============================================================================

-- Query 1: Tren tahunan memakai DATETRUNC
-- Tujuan: total penjualan, jumlah pelanggan unik, dan total kuantitas per tahun.
-- Peringatan: DATETRUNC hanya tersedia di SQL Server 2022 ke atas.

SELECT
	DATETRUNC(year, fs.order_date) AS order_date,
	SUM(fs.sales_amount) AS total_sales,
	COUNT(DISTINCT fs.customer_key) AS total_customer,
	SUM(fs.quantity) AS total_quantity
FROM gold.fact_sales fs
WHERE fs.order_date IS NOT NULL
GROUP BY DATETRUNC(year, fs.order_date)
ORDER BY DATETRUNC(year, fs.order_date);

-- Query 2: Tren bulanan memakai YEAR dan MONTH
-- Tujuan: sama seperti Query 1, tetapi per tahun dan bulan (dua kolom terpisah).
-- Peringatan: urutan hasil kronologis karena tahun dan bulan berupa angka.

SELECT
	YEAR(fs.order_date) AS order_date_year,
	MONTH(fs.order_date) AS order_date_month,
	SUM(fs.sales_amount) AS total_sales,
	COUNT(DISTINCT fs.customer_key) AS total_customer,
	SUM(fs.quantity) AS total_quantity
FROM gold.fact_sales fs
WHERE fs.order_date IS NOT NULL
GROUP BY YEAR(fs.order_date), MONTH(fs.order_date)
ORDER BY YEAR(fs.order_date), MONTH(fs.order_date);

-- Query 3: Tren bulanan memakai FORMAT
-- Tujuan: sama seperti Query 2, tetapi tahun dan bulan digabung dalam satu kolom teks.
-- Peringatan: FORMAT lebih lambat daripada DATETRUNC atau YEAR/MONTH pada data besar.
-- Juga memakai COUNT(DISTINCT customer_key).
SELECT
	FORMAT(fs.order_date, 'yyyy-MM') AS order_date,
	SUM(fs.sales_amount) AS total_sales,
	COUNT(DISTINCT fs.customer_key) AS total_customer,
	SUM(fs.quantity) AS total_quantity
FROM gold.fact_sales fs
WHERE fs.order_date IS NOT NULL
GROUP BY FORMAT(fs.order_date, 'yyyy-MM')
ORDER BY FORMAT(fs.order_date, 'yyyy-MM');

-- ============================================================================
-- ANALISIS KUMULATIF
-- ============================================================================

-- Query 1: Running total dan rata-rata harga (versi awal)
-- Tujuan: total penjualan bulanan, running total per tahun, dan rata-rata harga.
-- Peringatan:
--   * Running total di-reset setiap tahun karena PARTITION BY tahun.
--   * moving_average_price sebenarnya rata-rata kumulatif dari bulan pertama,
--     bukan moving average, karena tidak ada batasan jendela (ROWS BETWEEN).
--   * AVG(fs.price) adalah rata-rata harga per baris dan tidak memperhitungkan
--     kuantitas, sehingga bisa menyimpang dari harga rata-rata sebenarnya.
SELECT
	t.order_date,
	t.total_sales,
	SUM(t.total_sales) OVER(PARTITION BY DATETRUNC(year, t.order_date) ORDER BY t.order_date ASC) AS running_total_sales,
	AVG(t.average_sales) OVER(ORDER BY t.order_date) AS moving_average_price
FROM (
	SELECT
		DATETRUNC(month, fs.order_date) AS order_date,
		SUM(fs.sales_amount) AS total_sales,
		AVG(fs.price) AS average_sales
	FROM gold.fact_sales fs
	WHERE fs.order_date IS NOT NULL
	GROUP BY DATETRUNC(month, fs.order_date)
) t
ORDER BY t.order_date;

-- Query 2: Running total dan moving average 3 bulan (versi perbaikan)
-- Tujuan: sama seperti Query 1, tetapi harga rata-rata dihitung tertimbang
--         (total sales / total quantity) dan moving average memakai 3 bulan terakhir.
-- Peringatan:
--   * Dua bulan pertama hanya dirata-ratakan dari 1-2 bulan, bukan 3 bulan penuh.
--   * ROWS BETWEEN 2 PRECEDING menghitung 3 baris, bukan 3 bulan kalender.
--     Bulan tanpa transaksi tidak muncul sebagai baris, sehingga jendelanya
--     bisa mencakup lebih dari 3 bulan.
--   * Rata-rata dari avg_price bulanan tidak tertimbang kuantitas bulan tersebut.
SELECT
	t.order_date,
	t.total_sales,
	SUM(t.total_sales) OVER(PARTITION BY YEAR(t.order_date) ORDER BY t.order_date) AS running_total_sales,
	t.avg_price,
	AVG(t.avg_price) OVER(ORDER BY t.order_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_price_3m
FROM (
	SELECT
		DATETRUNC(month, fs.order_date) AS order_date,
		SUM(fs.sales_amount) AS total_sales,
		SUM(fs.sales_amount) / NULLIF(SUM(fs.quantity), 0) AS avg_price
	FROM gold.fact_sales fs
	WHERE fs.order_date IS NOT NULL
	GROUP BY DATETRUNC(month, fs.order_date)
) t
ORDER BY t.order_date;

-- ============================================================================
-- ANALISIS KINERJA
-- ============================================================================

-- Tujuan: bandingkan penjualan tahunan tiap produk dengan rata-rata produk
--         itu sendiri dan dengan tahun sebelumnya.
-- Peringatan:
--   * average_sales adalah rata-rata dari total per tahun, dan hanya mencakup
--     tahun yang punya transaksi.
WITH yearly_product_sales AS (
	SELECT
		YEAR(fs.order_date) AS order_year,
		dp.product_key,
		dp.product_name,
		SUM(fs.sales_amount) AS total_sales
	FROM gold.fact_sales fs
	LEFT JOIN gold.dim_products dp ON dp.product_key = fs.product_key
	WHERE fs.order_date IS NOT NULL
	GROUP BY YEAR(fs.order_date), dp.product_key, dp.product_name
)
SELECT
	order_year,
	product_name,
	total_sales,
	AVG(total_sales) OVER(PARTITION BY product_key) AS average_sales,
	total_sales - AVG(total_sales) OVER(PARTITION BY product_key) AS diff_avg,
	CASE WHEN total_sales - AVG(total_sales) OVER(PARTITION BY product_key) > 0 THEN 'Above Avg'
		 WHEN total_sales - AVG(total_sales) OVER(PARTITION BY product_key) < 0 THEN 'Below Avg'
		 ELSE 'Avg'
	END AS avg_change,
	LAG(total_sales) OVER(PARTITION BY product_key ORDER BY order_year) AS previous_year,
	total_sales - LAG(total_sales) OVER(PARTITION BY product_key ORDER BY order_year) AS diff_previous_year,
	CASE WHEN LAG(total_sales) OVER(PARTITION BY product_key ORDER BY order_year) IS NULL THEN 'No Data'
		 WHEN total_sales - LAG(total_sales) OVER(PARTITION BY product_key ORDER BY order_year) > 0 THEN 'Increase'
		 WHEN total_sales - LAG(total_sales) OVER(PARTITION BY product_key ORDER BY order_year) < 0 THEN 'Decrease'
		 ELSE 'No Change'
	END AS previous_year_change
FROM yearly_product_sales
ORDER BY product_name, order_year;

-- ============================================================================
-- ANALISIS PART-TO-WHOLE
-- ============================================================================

-- Tujuan: kontribusi penjualan tiap kategori terhadap total penjualan.
-- Peringatan: produk yang tidak ditemukan di dim_products akan muncul sebagai
-- kategori NULL.
WITH category_sales AS (
	SELECT
		dp.category,
		SUM(fs.sales_amount) AS total_sales
	FROM gold.fact_sales fs
	LEFT JOIN gold.dim_products dp ON dp.product_key = fs.product_key
	WHERE fs.order_date IS NOT NULL
	GROUP BY dp.category
)
SELECT
	category,
	total_sales,
	SUM(total_sales) OVER() AS overall_sales,
	ROUND(CAST(total_sales AS FLOAT) / SUM(total_sales) OVER() * 100, 2) AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC;

-- ============================================================================
-- SEGMENTASI DATA
-- ============================================================================

-- Query 1: Segmentasi produk berdasarkan rentang biaya
-- Tujuan: jumlah produk di setiap rentang cost.

WITH product_segments AS (
	SELECT
		dp.product_key,
		dp.product_name,
		dp.cost,
		CASE WHEN dp.cost IS NULL THEN 'Unknown'
			 WHEN dp.cost < 100 THEN 'Below 100'
			 WHEN dp.cost < 500 THEN '100-500'
			 WHEN dp.cost < 1000 THEN '500-1000'
			 ELSE 'Above 1000'
		END AS cost_range
	FROM gold.dim_products dp
)
SELECT
	cost_range,
	COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC;

-- Query 2: Segmentasi pelanggan (VIP, Regular, New)
-- Tujuan: jumlah pelanggan di setiap segmen berdasarkan total belanja dan lifespan.
-- Aturan: VIP = belanja > 5000 dan lifespan >= 12 bulan,
--         Regular = belanja <= 5000 dan lifespan >= 12 bulan, selain itu New.
-- Peringatan:
--   * DATEDIFF(month, ...) menghitung pergantian bulan kalender, bukan jarak
--     penuh 30 hari. 31 Jan sampai 1 Feb dihitung 1 bulan.
--   * Batas 5000 dan 12 bulan ditulis langsung (hardcode). Sesuaikan dengan
--     kebutuhan bisnis.
WITH customer_spending AS (
	SELECT
		dc.customer_key,
		SUM(fs.sales_amount) AS total_spending,
		MIN(fs.order_date) AS first_order,
		MAX(fs.order_date) AS last_order,
		DATEDIFF(month, MIN(fs.order_date), MAX(fs.order_date)) AS lifespan
	FROM gold.fact_sales fs
	INNER JOIN gold.dim_customers dc ON dc.customer_key = fs.customer_key
	WHERE fs.order_date IS NOT NULL
	GROUP BY dc.customer_key
)
SELECT
	flag,
	COUNT(customer_key) AS total_customer
FROM (
	SELECT
		customer_key,
		CASE WHEN total_spending > 5000 AND lifespan >= 12 THEN 'VIP'
			 WHEN total_spending <= 5000 AND lifespan >= 12 THEN 'Regular'
			 ELSE 'New'
		END AS flag
	FROM customer_spending
) AS t
GROUP BY flag
ORDER BY total_customer DESC;

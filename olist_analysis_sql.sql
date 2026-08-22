CREATE DATABASE olist_analysis;

USE olist_analysis;
##create orders 
CREATE TABLE orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_status VARCHAR(30),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME
);
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 9.7/Uploads/olist_orders_dataset.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, customer_id, order_status, @purchase_ts, @approved_ts, @carrier_ts, @customer_ts, @estimated_ts)
SET
    order_purchase_timestamp = NULLIF(@purchase_ts, ''),
    order_approved_at = NULLIF(@approved_ts, ''),
    order_delivered_carrier_date = NULLIF(@carrier_ts, ''),
    order_delivered_customer_date = NULLIF(@customer_ts, ''),
    order_estimated_delivery_date = NULLIF(@estimated_ts, '');
    
    SELECT COUNT(*) FROM orders;
    ##create order list
    CREATE TABLE order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price FLOAT,
    freight_value FLOAT,
    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 9.7/Uploads/olist_order_items_dataset.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, order_item_id, product_id, seller_id, @shipping_ts, price, freight_value)
SET shipping_limit_date = NULLIF(@shipping_ts, '');

SELECT COUNT(*) FROM order_items;
##create products
CREATE TABLE products (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_lenght FLOAT,
    product_description_lenght FLOAT,
    product_photos_qty FLOAT,
    product_weight_g FLOAT,
    product_length_cm FLOAT,
    product_height_cm FLOAT,
    product_width_cm FLOAT
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 9.7/Uploads/olist_products_dataset.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_id, product_category_name, @nl, @dl, @pq, @wg, @lc, @hc, @wc)
SET
    product_name_lenght = NULLIF(@nl, ''),
    product_description_lenght = NULLIF(@dl, ''),
    product_photos_qty = NULLIF(@pq, ''),
    product_weight_g = NULLIF(@wg, ''),
    product_length_cm = NULLIF(@lc, ''),
    product_height_cm = NULLIF(@hc, ''),
    product_width_cm = NULLIF(@wc, '');
    
    SELECT COUNT(*) FROM products;
    ##create tables
    CREATE TABLE sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix INT,
    seller_city VARCHAR(100),
    seller_state VARCHAR(10)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 9.7/Uploads/olist_sellers_dataset.csv'
INTO TABLE sellers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM sellers;
##create customers
CREATE TABLE customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(100),
    customer_state VARCHAR(10)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 9.7/Uploads/olist_customers_dataset.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM customers;
#3create orders review
CREATE TABLE order_reviews (
    review_id VARCHAR(50) PRIMARY KEY,
    order_id VARCHAR(50),
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME,
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 9.7/Uploads/olist_order_reviews_dataset.csv'
IGNORE
INTO TABLE order_reviews
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(review_id, order_id, review_score, review_comment_title, review_comment_message, @created_ts, @answered_ts)
SET
    review_creation_date = NULLIF(@created_ts, ''),
    review_answer_timestamp = NULLIF(@answered_ts, '');
    
    SELECT COUNT(*) FROM order_reviews;
    
    -- ============================
-- PART 2: Analytical Queries
-- ============================
CREATE VIEW delivered_orders AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    o.customer_id,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS delay_days,
    CASE WHEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) > 0 THEN 1 ELSE 0 END AS is_late,
    p.product_category_name,
    s.seller_state,
    c.customer_state,
    r.review_score
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN sellers s ON oi.seller_id = s.seller_id
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL;

SELECT COUNT(*) FROM delivered_orders;

##Seller-level aggregation with the low-volume filter----

SELECT
    seller_id,
    seller_state,
    COUNT(*) AS total_orders,
    SUM(is_late) AS late_orders,
    ROUND(AVG(is_late), 4) AS late_rate,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM delivered_orders
GROUP BY seller_id, seller_state
HAVING COUNT(*) >= 20
ORDER BY late_rate DESC
LIMIT 10;

##region/category confound control using window functions---------

WITH seller_agg AS (
    SELECT
        seller_id,
        seller_state,
        COUNT(*) AS total_orders,
        SUM(is_late) AS late_orders,
        AVG(is_late) AS late_rate
    FROM delivered_orders
    GROUP BY seller_id, seller_state
    HAVING COUNT(*) >= 20
),
state_baseline AS (
    SELECT
        customer_state,
        AVG(is_late) AS state_avg_late_rate
    FROM delivered_orders
    GROUP BY customer_state
),
seller_expected AS (
    SELECT
        d.seller_id,
        AVG(sb.state_avg_late_rate) AS expected_late_rate
    FROM delivered_orders d
    JOIN state_baseline sb ON d.customer_state = sb.customer_state
    GROUP BY d.seller_id
)
SELECT
    sa.seller_id,
    sa.seller_state,
    sa.total_orders,
    ROUND(sa.late_rate, 4) AS late_rate,
    ROUND(se.expected_late_rate, 4) AS expected_late_rate,
    ROUND(sa.late_rate - se.expected_late_rate, 4) AS late_rate_vs_expected
FROM seller_agg sa
JOIN seller_expected se ON sa.seller_id = se.seller_id
ORDER BY late_rate_vs_expected DESC
LIMIT 10;

##add category confoun d control------

WITH seller_agg AS (
    SELECT
        seller_id,
        seller_state,
        COUNT(*) AS total_orders,
        SUM(is_late) AS late_orders,
        AVG(is_late) AS late_rate
    FROM delivered_orders
    GROUP BY seller_id, seller_state
    HAVING COUNT(*) >= 20
),
state_baseline AS (
    SELECT customer_state, AVG(is_late) AS state_avg_late_rate
    FROM delivered_orders
    GROUP BY customer_state
),
category_baseline AS (
    SELECT product_category_name, AVG(is_late) AS category_avg_late_rate
    FROM delivered_orders
    GROUP BY product_category_name
),
seller_expected_state AS (
    SELECT d.seller_id, AVG(sb.state_avg_late_rate) AS expected_late_rate_state
    FROM delivered_orders d
    JOIN state_baseline sb ON d.customer_state = sb.customer_state
    GROUP BY d.seller_id
),
seller_expected_category AS (
    SELECT d.seller_id, AVG(cb.category_avg_late_rate) AS expected_late_rate_category
    FROM delivered_orders d
    JOIN category_baseline cb ON d.product_category_name = cb.product_category_name
    GROUP BY d.seller_id
)
SELECT
    sa.seller_id,
    sa.seller_state,
    sa.total_orders,
    ROUND(sa.late_rate, 4) AS late_rate,
    ROUND(ses.expected_late_rate_state, 4) AS expected_state,
    ROUND(sec.expected_late_rate_category, 4) AS expected_category,
    ROUND((ses.expected_late_rate_state + sec.expected_late_rate_category) / 2, 4) AS combined_expected,
    ROUND(sa.late_rate - (ses.expected_late_rate_state + sec.expected_late_rate_category) / 2, 4) AS late_rate_vs_combined_expected
FROM seller_agg sa
JOIN seller_expected_state ses ON sa.seller_id = ses.seller_id
JOIN seller_expected_category sec ON sa.seller_id = sec.seller_id
ORDER BY late_rate_vs_combined_expected DESC
LIMIT 10;

##Revenue-at-risk in SQL, with the same correction applied-----

WITH seller_agg AS (
    SELECT seller_id, seller_state, COUNT(*) AS total_orders, AVG(is_late) AS late_rate
    FROM delivered_orders
    GROUP BY seller_id, seller_state
    HAVING COUNT(*) >= 20
),
state_baseline AS (
    SELECT customer_state, AVG(is_late) AS state_avg_late_rate
    FROM delivered_orders GROUP BY customer_state
),
category_baseline AS (
    SELECT product_category_name, AVG(is_late) AS category_avg_late_rate
    FROM delivered_orders GROUP BY product_category_name
),
seller_expected AS (
    SELECT
        d.seller_id,
        AVG(sb.state_avg_late_rate) AS expected_state,
        AVG(cb.category_avg_late_rate) AS expected_category
    FROM delivered_orders d
    JOIN state_baseline sb ON d.customer_state = sb.customer_state
    JOIN category_baseline cb ON d.product_category_name = cb.product_category_name
    GROUP BY d.seller_id
),
seller_late_revenue AS (
    SELECT oi.seller_id, SUM(oi.price) AS late_order_revenue
    FROM delivered_orders d
    JOIN order_items oi ON d.order_id = oi.order_id AND d.order_item_id = oi.order_item_id
    WHERE d.is_late = 1
    GROUP BY oi.seller_id
)
SELECT
    sa.seller_id,
    sa.seller_state,
    sa.total_orders,
    ROUND(sa.late_rate - (se.expected_state + se.expected_category)/2, 4) AS late_rate_vs_expected,
    ROUND(COALESCE(slr.late_order_revenue, 0), 2) AS late_order_revenue,
    ROUND(COALESCE(slr.late_order_revenue, 0) * 0.50, 2) AS revenue_at_risk
FROM seller_agg sa
JOIN seller_expected se ON sa.seller_id = se.seller_id
LEFT JOIN seller_late_revenue slr ON sa.seller_id = slr.seller_id
WHERE sa.late_rate - (se.expected_state + se.expected_category)/2 > 0
ORDER BY revenue_at_risk DESC
LIMIT 10;
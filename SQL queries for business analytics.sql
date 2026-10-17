-- 1) Demand forecasting & capacity planning
-- Peak demand by outlet × day-of-week × hour (last 8 weeks)
SELECT
  Outlet_ID,
  DATE_FORMAT(Order_Datetime, '%a') AS dow,
  HOUR(Order_Datetime) AS hr,
  COUNT(*) AS orders,
  ROUND(SUM(Grand_Total),2) AS revenue
FROM CUSTOMER_ORDER
WHERE Order_Status = 'paid'
  AND Order_Datetime >= DATE_SUB(CURDATE(), INTERVAL 56 DAY)
GROUP BY Outlet_ID, dow, hr
ORDER BY orders DESC, revenue DESC;


-- 2) Reservation reliability & table utilisation
-- No-show & cancellation rates by outlet (last 90 days)
SELECT
  Outlet_ID,
  COUNT(*) AS reservations,
  SUM(Reservation_Status = 'no_show')    AS no_shows,
  SUM(Reservation_Status = 'cancelled')  AS cancellations,
  ROUND(SUM(Reservation_Status = 'no_show')
        / NULLIF(SUM(Reservation_Status IN ('requested','confirmed')),0), 3) AS no_show_rate,
  ROUND(SUM(Reservation_Status = 'cancelled') / NULLIF(COUNT(*),0), 3)       AS cancel_rate
FROM RESERVATION
WHERE Reservation_Datetime >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
GROUP BY Outlet_ID
ORDER BY no_show_rate DESC, cancel_rate DESC;

-- 3) Channel profitability
-- Net revenue & refund rate by channel
WITH pay AS (
  SELECT
    co.Order_ID,
    co.Order_Type,
    SUM(CASE WHEN p.Payment_Status = 'approved' THEN p.Amount ELSE 0 END) AS approved_amt,
    SUM(CASE WHEN p.Payment_Status = 'refunded' THEN p.Amount ELSE 0 END) AS refunded_amt
  FROM CUSTOMER_ORDER co
  LEFT JOIN PAYMENT p ON p.Order_ID = co.Order_ID
  GROUP BY co.Order_ID, co.Order_Type
)
SELECT
  Order_Type,
  COUNT(*) AS orders,
  ROUND(SUM(approved_amt),2) AS gross_collected,
  ROUND(SUM(refunded_amt),2) AS refunds,
  ROUND(SUM(approved_amt - refunded_amt),2) AS net_revenue,
  ROUND(SUM(refunded_amt)/NULLIF(SUM(approved_amt),0),3) AS refund_rate
FROM pay
GROUP BY Order_Type
ORDER BY net_revenue ASC, refund_rate DESC;


-- 4) Menu engineering & optimisation
-- Product performance (last 60 days): low performers first
SELECT
  pc.Category_Name,
  p.Product_ID,
  p.Product_Name,
  SUM(od.Quantity) AS qty_sold,
  ROUND(SUM(od.Line_Total),2) AS revenue
FROM ORDER_DETAIL od
JOIN CUSTOMER_ORDER co ON co.Order_ID = od.Order_ID
JOIN PRODUCT p         ON p.Product_ID = od.Product_ID
JOIN PRODUCT_CATEGORY pc ON pc.Category_ID = p.Category_ID
WHERE co.Order_Status = 'paid'
  AND co.Order_Datetime >= DATE_SUB(CURDATE(), INTERVAL 60 DAY)
GROUP BY pc.Category_Name, p.Product_ID, p.Product_Name
ORDER BY qty_sold ASC, revenue ASC;


-- 5) Staff scheduling & performance
SELECT
  r.Outlet_ID,
  r.Staff_ID,
  DATE(COALESCE(r.Actual_Start_Time, r.Scheduled_Start_Time)) AS work_date,
  ROUND(TIMESTAMPDIFF(MINUTE, r.Scheduled_Start_Time, r.Scheduled_End_Time)/60, 2) AS scheduled_hours,
  ROUND(COALESCE(r.Hours_Worked,
                 TIMESTAMPDIFF(MINUTE, r.Scheduled_Start_Time, r.Scheduled_End_Time)/60), 2) AS actual_hours,
  ROUND(
    COALESCE(r.Hours_Worked,
             TIMESTAMPDIFF(MINUTE, r.Scheduled_Start_Time, r.Scheduled_End_Time)/60)
    - (TIMESTAMPDIFF(MINUTE, r.Scheduled_Start_Time, r.Scheduled_End_Time)/60), 2
  ) AS variance_hours,                                  -- + = over, - = under
  TIMESTAMPDIFF(MINUTE, r.Scheduled_Start_Time, r.Actual_Start_Time) AS start_delta_min, -- + = late, - = early
  TIMESTAMPDIFF(MINUTE, r.Scheduled_End_Time, r.Actual_End_Time)     AS end_delta_min    -- + = stayed late, - = left early
FROM ROSTER r
ORDER BY work_date, r.Outlet_ID, r.Staff_ID;

SELECT
  r.Outlet_ID,
  r.Staff_ID,
  DATE(COALESCE(r.Actual_Start_Time, r.Scheduled_Start_Time)) AS work_date,
  COUNT(*) AS shifts_that_day,
  ROUND(SUM(COALESCE(r.Hours_Worked,
                     TIMESTAMPDIFF(MINUTE, r.Scheduled_Start_Time, r.Scheduled_End_Time)/60)), 2) AS hours_in_day
FROM ROSTER r
GROUP BY r.Outlet_ID, r.Staff_ID, work_date
HAVING COUNT(*) > 1
ORDER BY hours_in_day DESC;

SELECT
  s.Outlet_ID,
  s.Staff_ID,
  s.Staff_First_Name, s.Staff_Last_Name,
  COUNT(*) AS shifts,
  SUM(r.Actual_Start_Time IS NOT NULL AND TIMESTAMPDIFF(MINUTE, r.Scheduled_Start_Time, r.Actual_Start_Time) > 0) 
  AS late_starts,
  ROUND(100.0 * SUM(r.Actual_Start_Time IS NULL OR TIMESTAMPDIFF
  (MINUTE, r.Scheduled_Start_Time, r.Actual_Start_Time) <= 0) / COUNT(*), 1) AS on_time_start_pct
FROM ROSTER r
JOIN STAFF s ON s.Staff_ID = r.Staff_ID
GROUP BY s.Outlet_ID, s.Staff_ID, s.Staff_First_Name, s.Staff_Last_Name
ORDER BY on_time_start_pct ASC, shifts DESC
LIMIT 15;

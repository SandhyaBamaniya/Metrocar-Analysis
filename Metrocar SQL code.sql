--1. How many times was the app downloaded?
SELECT COUNT(*)
FROM app_downloads;

--2. How many users signed up on the app?
SELECT COUNT(*)
FROM signups;

--3. How many rides were requested through the app?
SELECT COUNT(*)
FROM ride_requests;

--4. How many rides were requested and completed through the app?
SELECT COUNT(*) AS rides_completed
FROM transactions
UNION
SELECT COUNT(*) AS rides_requested
FROM ride_requests;

--5. How many rides were requested and how many unique users requested a ride?
SELECT COUNT(DISTINCT user_id)
FROM ride_requests
UNION
SELECT COUNT(*)
FROM ride_requests;

--6. What is the average time of a ride from pick up to drop off?
SELECT avg(dropoff_ts - pickup_ts)
FROM ride_requests;

--7. How many rides were accepted by a driver?
SELECT COUNT(accept_ts)
FROM ride_requests;

--8. How many rides did we successfully collect payments and how much was collected?
SELECT COUNT(*), SUM(purchase_amount_usd)
FROM transactions
WHERE charge_status = 'Approved';

--9.How many ride requests happened on each platform?
WITH t1 AS (
    SELECT COUNT(*) AS android
FROM app_downloads a
JOIN signups AS s
ON s.session_id = a.app_download_key
JOIN ride_requests AS r
ON r.user_id = s.user_id
WHERE platform = 'android'),
t2 AS (
    SELECT COUNT(*) AS ios
FROM app_downloads a
JOIN signups AS s
ON s.session_id = a.app_download_key
JOIN ride_requests AS r
ON r.user_id = s.user_id
WHERE platform = 'ios'
),
t3 AS (
    SELECT COUNT(*) AS web
FROM app_downloads a
JOIN signups AS s
ON s.session_id = a.app_download_key
JOIN ride_requests AS r
ON r.user_id = s.user_id
WHERE platform = 'web'
)
SELECT t1.android, t2.ios, t3.web
FROM t1, t2, t3;

--10. What is the drop-off from users signing up to users requesting a ride?
SELECT (COUNT(s.user_id)-COUNT(r.user_id))*100/COUNT(DISTINCT s.user_id)::NUMERIC
FROM signups AS s
LEFT JOIN ride_requests AS r
ON s.user_id = r.user_id;

--SECOND SPRINT
--3. How many unique users requested a ride through the Metrocar app?
SELECT COUNT(DISTINCT user_id)
FROM ride_requests;

--4.How many unique users completed a ride through the Metrocar app?
SELECT COUNT(DISTINCT user_id)
FROM ride_requests
WHERE dropoff_ts IS NOT NULL;

--5. Of the users that signed up on the app, what percentage these users requested a ride?
SELECT COUNT(DISTINCT r.user_id)* 100 :: FLOAT/COUNT(DISTINCT s.user_id) :: FLOAT AS percent_users
FROM signups AS s
LEFT JOIN ride_requests AS r
ON s.user_id = r.user_id;

--6. Of the users that signed up on the app, what percentage these users completed a ride?
   WITH signedup_users AS (
  SELECT COUNT(DISTINCT user_id) :: FLOAT AS signed_up 
  FROM signups),
 completed_users AS (
   SELECT COUNT(DISTINCT user_id) :: FLOAT AS ride_completed 
   FROM ride_requests
   WHERE dropoff_ts IS NOT NULL)
SELECT ROUND(CAST(completed_users.ride_completed * 100/signedup_users.signed_up AS NUMERIC), 2)
FROM signedup_users, completed_users;

--7.Using the percent of previous approach, what are the user-level conversion rates for the first 3 stages of the funnel (app download to signup and signup to ride requested)?
WITH total_download AS (
  SELECT app_download_key
  FROM app_downloads 
  GROUP BY app_download_key),
t2 AS (
  SELECT COUNT(*) AS total_app_downloads
  FROM total_download AS a
  LEFT JOIN signups AS s
  ON a.app_download_key = s.session_id),
t3 AS (
  SELECT user_id 
  FROM ride_requests AS r
  GROUP BY user_id),
t4 AS (
  SELECT COUNT(*) AS total_sign_ups, COUNT(DISTINCT t3.user_id) AS ride_requested
  FROM signups AS s
  LEFT JOIN t3
  ON s.user_id = t3.user_id),
funnel_stages AS (
  SELECT 1 AS funnel_step, 'app_downloads' AS funnel_name, total_app_downloads AS funnel_value
  FROM t2
  UNION
  SELECT 2 AS funnel_step, 'signups' AS funnel_name, total_sign_ups AS funnel_value
  FROM t4
  UNION
  SELECT 3 AS funnel_step, 'rides_requested' AS funnel_name, ride_requested AS funnel_value
  FROM t4)
SELECT *, funnel_value::FLOAT/ LAG(funnel_value) OVER (ORDER BY funnel_step) AS previous_value
FROM funnel_stages
ORDER BY funnel_step;

--8. Using the percent of top approach, what are the user-level conversion rates for the first 3 stages of the funnel (app download to signup and signup to ride requested)?
WITH total_download AS (
  SELECT app_download_key
  FROM app_downloads 
  GROUP BY app_download_key),
t2 AS (
  SELECT COUNT(*) AS total_app_downloads
  FROM total_download AS a
  LEFT JOIN signups AS s
  ON a.app_download_key = s.session_id),
t3 AS (
  SELECT user_id 
  FROM ride_requests AS r
  GROUP BY user_id),
t4 AS (
  SELECT COUNT(*) AS total_sign_ups, COUNT(DISTINCT t3.user_id) AS ride_requested
  FROM signups AS s
  LEFT JOIN t3
  ON s.user_id = t3.user_id),
funnel_stages AS (
  SELECT 1 AS funnel_step, 'app_downloads' AS funnel_name, total_app_downloads AS funnel_value
  FROM t2
  UNION
  SELECT 2 AS funnel_step, 'signups' AS funnel_name, total_sign_ups AS funnel_value
  FROM t4
  UNION
  SELECT 3 AS funnel_step, 'rides_requested' AS funnel_name, ride_requested AS funnel_value
  FROM t4)
SELECT *, funnel_value::FLOAT/ FIRST_VALUE(funnel_value) OVER (ORDER BY funnel_step) AS first_value
FROM funnel_stages
ORDER BY funnel_step;

--9. Using the percent of previous approach, what are the user-level conversion rates for the following 3 stages of the funnel? 1. signup, 2. ride requested, 3. ride completed
WITH total_download AS (
  SELECT app_download_key
  FROM app_downloads 
  GROUP BY app_download_key),
t2 AS (
  SELECT COUNT(*) AS total_app_downloads
  FROM total_download AS a
  LEFT JOIN signups AS s
  ON a.app_download_key = s.session_id),
t3 AS (
  SELECT user_id 
  FROM ride_requests AS r
  GROUP BY user_id),
t4 AS (
  SELECT COUNT(*) AS total_sign_ups, COUNT(DISTINCT t3.user_id) AS ride_requested
  FROM signups AS s
  LEFT JOIN t3
  ON s.user_id = t3.user_id),
 t5 AS (
   SELECT COUNT(DISTINCT r.user_id) AS rides_completed
   FROM ride_requests AS r
   WHERE dropoff_ts IS NOT NULL),
funnel_stages AS (
  SELECT 1 AS funnel_step, 'app_downloads' AS funnel_name, total_app_downloads AS funnel_value
  FROM t2
  UNION
  SELECT 2 AS funnel_step, 'signups' AS funnel_name, total_sign_ups AS funnel_value
  FROM t4
  UNION
  SELECT 3 AS funnel_step, 'rides_requested' AS funnel_name, ride_requested AS funnel_value
  FROM t4
  UNION
  SELECT 4 AS funnel_step, 'rides_completed' AS funnel_name, rides_completed AS funnel_value
  FROM t5)
SELECT *, value::FLOAT/ LAG(value) OVER (ORDER BY funnel_step) AS previous_value
FROM funnel_stages
ORDER BY funnel_step;

--10. Using the percent of top approach, what are the user-level conversion rates for the following 3 stages of the funnel? 1. signup, 2. ride requested, 3. ride completed (hint: signup is the top of this funnel
WITH t1 AS (
  SELECT user_id 
  FROM ride_requests AS r
  GROUP BY user_id),
t2 AS (
  SELECT COUNT(*) AS total_sign_ups, COUNT(DISTINCT t1.user_id) AS ride_requested
  FROM signups AS s
  LEFT JOIN t1
  ON s.user_id = t1.user_id),
t3 AS (
   SELECT COUNT(DISTINCT r.user_id) AS rides_completed
   FROM ride_requests AS r
   WHERE dropoff_ts IS NOT NULL),
funnel_stages AS (
  SELECT 1 AS funnel_step, 'signups' AS funnel_name, total_sign_ups AS funnel_value
  FROM t2
  UNION
  SELECT 2 AS funnel_step, 'rides_requested' AS funnel_name, ride_requested AS funnel_value
  FROM t2
  UNION
  SELECT 3 AS funnel_step, 'rides_completed' AS funnel_name, rides_completed AS funnel_value
  FROM t3)
SELECT *, funnel_valuevalue::FLOAT/ FIRST_VALUE(funnel_value) OVER (ORDER BY funnel_step) AS first_value
FROM funnel_stages
ORDER BY funnel_step;

--Final Query for the Dashboard
WITH user_platform AS (
  SELECT app_download_key, user_id, platform, age_range, date(download_ts) AS download_dt
	FROM app_downloads AS a
	LEFT JOIN signups AS s
  ON a.app_download_key = s.session_id),
t1 AS (
  SELECT 0 AS step, 'downloads' AS name, platform, age_range, download_dt, 
  			COUNT(DISTINCT app_download_key) AS user_count, 
         0 AS ride_count
  FROM user_platform 
  GROUP BY platform, age_range, download_dt),
t2 AS (
  SELECT 1 AS step, 'signups' AS name, u.platform, u.age_range, u.download_dt,
  			COUNT(DISTINCT s.user_id) AS user_count, 0 AS ride_count
  FROM signups AS s
  INNER JOIN user_platform AS u
  ON s.user_id = u.user_id
  GROUP BY u.platform, u.age_range, u.download_dt),
t3 AS (
  SELECT 2 AS step, 'rides_requested' AS name, u.platform, u.age_range, u.download_dt,
  			COUNT(DISTINCT r.user_id) AS user_count, COUNT(DISTINCT r.ride_id) AS ride_count
  FROM ride_requests AS r
  JOIN user_platform AS u
  ON r.user_id = u.user_id
  WHERE request_ts IS NOT NULL 
  GROUP BY u.platform, u.age_range, u.download_dt),
t4 AS (
  SELECT 3 AS step, 'rides_accepted' AS name, u.platform, u.age_range, u.download_dt,
        COUNT(DISTINCT r.user_id) AS user_count, COUNT(DISTINCT r.ride_id) AS ride_count
  FROM ride_requests AS r
  JOIN user_platform AS u
  ON r.user_id = u.user_id
  WHERE accept_ts IS NOT NULL 
  GROUP BY u.platform, u.age_range, u.download_dt),
t5 AS (
  SELECT 4 AS step, 'rides_completed' AS name,u.platform, u.age_range, u.download_dt,
  			COUNT(DISTINCT r.user_id) AS user_count, COUNT(DISTINCT r.ride_id) AS ride_count
  FROM ride_requests AS r
  JOIN user_platform AS u
  ON r.user_id = u.user_id
  WHERE dropoff_ts IS NOT NULL
  GROUP BY u.platform, u.age_range, u.download_dt),
t6 AS (
  SELECT 5 AS step, 'payment' AS name, u.platform, u.age_range, u.download_dt,
        COUNT(DISTINCT r.user_id) AS user_count, COUNT(DISTINCT r.ride_id) AS ride_count
  FROM ride_requests AS r
  JOIN user_platform AS u
  ON r.user_id = u.user_id
  JOIN transactions AS t
  ON t.ride_id = r.ride_id
  WHERE charge_status = 'Approved' 
  GROUP BY u.platform, u.age_range, u.download_dt ),
t7 AS (
  SELECT 6 AS step, 'review' AS name, u.platform, u.age_range, u.download_dt,
  			COUNT(DISTINCT r.user_id) AS user_count,COUNT(DISTINCT r.ride_id) AS ride_count
  FROM ride_requests AS r
  JOIN user_platform AS u
  ON r.user_id = u.user_id
  JOIN reviews AS rr
  ON r.user_id = rr.user_id
  GROUP BY u.platform, u.age_range, u.download_dt)
  
SELECT *
FROM t1
UNION
SELECT *
FROM t2
UNION
SELECT *
FROM t3
UNION
SELECT *
FROM t4
UNION
SELECT *
FROM t5
UNION
SELECT *
FROM t6
UNION
SELECT *
FROM t7
ORDER BY step

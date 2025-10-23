USE RedditDB;
GO

/* =======================================================
   02_load_dw.sql
   This script fills the Data Warehouse (DW) with data
   from the RedditDB main database.
   ======================================================= */

-- 1) First, clean the old DW data
DELETE FROM dw.fact_post_daily;
DELETE FROM dw.fact_comment_vote;
DELETE FROM dw.fact_post_vote;

DELETE FROM dw.dim_comment;
DELETE FROM dw.dim_post;
DELETE FROM dw.dim_flair;
DELETE FROM dw.dim_sub;
DELETE FROM dw.dim_user;
DELETE FROM dw.dim_date;

------------------------------------------------------------
-- 2) Fill the small DW tables (dimensions)
------------------------------------------------------------

-- make the date table (for year 2025)
;WITH d AS (
  SELECT CAST('2025-01-01' AS DATE) AS dt
  UNION ALL
  SELECT DATEADD(DAY,1,dt) FROM d WHERE dt < '2025-12-31'
)
INSERT INTO dw.dim_date(date_key, date_value, year, month, day)
SELECT CONVERT(INT, FORMAT(dt,'yyyyMMdd')),
       dt, YEAR(dt), MONTH(dt), DAY(dt)
FROM d
OPTION (MAXRECURSION 370);

-- copy users
INSERT INTO dw.dim_user(user_id, username, status)
SELECT id, username, status
FROM dbo.[user];

-- copy subreddits
INSERT INTO dw.dim_sub(sub_id, name, is_private)
SELECT id, name, is_private
FROM dbo.subreddit;

-- copy flairs
INSERT INTO dw.dim_flair(flair_id, sub_id, text)
SELECT id, subreddit_id, [text]
FROM dbo.flair;

-- copy posts
INSERT INTO dw.dim_post(post_id, title, type, created_date_key, user_id, sub_id, flair_id)
SELECT p.id,
       p.title,
       p.[type],
       CONVERT(INT, FORMAT(CAST(p.created_at AS DATE),'yyyyMMdd')),
       p.user_id,
       p.subreddit_id,
       p.flair_id
FROM dbo.post p;

-- copy comments
INSERT INTO dw.dim_comment(post_id, seq, user_id, created_date_key)
SELECT c.post_id,
       c.seq,
       c.user_id,
       CONVERT(INT, FORMAT(CAST(c.created_at AS DATE),'yyyyMMdd'))
FROM dbo.comment c;

------------------------------------------------------------
-- 3) Fill the big DW tables (facts)
------------------------------------------------------------

-- 3.1 post votes
WITH m_user AS (
  SELECT du.user_key, du.user_id FROM dw.dim_user du
),
m_sub AS (
  SELECT ds.sub_key, ds.sub_id FROM dw.dim_sub ds
),
m_post AS (
  SELECT dp.post_key, dp.post_id, dp.sub_id, dp.flair_id FROM dw.dim_post dp
),
m_flair AS (
  SELECT df.flair_key, df.flair_id FROM dw.dim_flair df
)
INSERT INTO dw.fact_post_vote(date_key, user_key, sub_key, post_key, flair_key, vote_value, vote_count)
SELECT
  CONVERT(INT, FORMAT(CAST(v.voted_at AS DATE),'yyyyMMdd')),
  mu.user_key,
  ms.sub_key,
  mp.post_key,
  mf.flair_key,
  v.value,
  1
FROM dbo.post_vote v
JOIN m_user mu   ON mu.user_id = v.user_id
JOIN m_post mp   ON mp.post_id = v.post_id
JOIN m_sub  ms   ON ms.sub_id  = mp.sub_id
LEFT JOIN m_flair mf ON mf.flair_id = mp.flair_id;


-- 3.2 comment votes
WITH m_user AS (
  SELECT du.user_key, du.user_id FROM dw.dim_user du
),
m_sub AS (
  SELECT ds.sub_key, ds.sub_id FROM dw.dim_sub ds
),
m_post AS (
  SELECT dp.post_key, dp.post_id, dp.sub_id, dp.flair_id FROM dw.dim_post dp
),
m_comment AS (
  SELECT dc.comment_key, dc.post_id, dc.seq FROM dw.dim_comment dc
)
INSERT INTO dw.fact_comment_vote(date_key, user_key, sub_key, post_key, comment_key, vote_value, vote_count)
SELECT
  CONVERT(INT, FORMAT(CAST(cv.voted_at AS DATE),'yyyyMMdd')),
  mu.user_key,
  ms.sub_key,
  mp.post_key,
  mc.comment_key,
  cv.value,
  1
FROM dbo.comment_vote cv
JOIN m_user mu    ON mu.user_id = cv.user_id
JOIN m_post mp    ON mp.post_id = cv.post_id
JOIN m_comment mc ON mc.post_id = cv.post_id AND mc.seq = cv.seq
JOIN m_sub  ms    ON ms.sub_id  = mp.sub_id;


-- 3.3 post daily info
WITH m_user AS (
  SELECT du.user_key, du.user_id FROM dw.dim_user du
),
m_sub AS (
  SELECT ds.sub_key, ds.sub_id FROM dw.dim_sub ds
),
m_post AS (
  SELECT dp.post_key, dp.post_id, dp.sub_id, dp.flair_id FROM dw.dim_post dp
),
m_flair AS (
  SELECT df.flair_key, df.flair_id FROM dw.dim_flair df
)
INSERT INTO dw.fact_post_daily(date_key, sub_key, post_key, user_key, flair_key, post_score, comment_count, vote_count)
SELECT
  CONVERT(INT, FORMAT(CAST(p.created_at AS DATE),'yyyyMMdd')),
  ms.sub_key,
  mp.post_key,
  mu.user_key,
  mf.flair_key,
  p.score,
  (SELECT COUNT(*) FROM dbo.comment c
     WHERE c.post_id = p.id
       AND CAST(c.created_at AS DATE) = CAST(p.created_at AS DATE)),
  (SELECT COUNT(*) FROM dbo.post_vote pv
     WHERE pv.post_id = p.id
       AND CAST(pv.voted_at AS DATE) = CAST(p.created_at AS DATE))
FROM dbo.post p
JOIN m_post mp   ON mp.post_id = p.id
JOIN m_user mu   ON mu.user_id = p.user_id
JOIN m_sub  ms   ON ms.sub_id  = p.subreddit_id
LEFT JOIN m_flair mf ON mf.flair_id = p.flair_id;

------------------------------------------------------------
-- 4) Check if it worked (counts)
------------------------------------------------------------
SELECT (SELECT COUNT(*) FROM dw.dim_date)      AS date_rows,
       (SELECT COUNT(*) FROM dw.dim_user)      AS user_rows,
       (SELECT COUNT(*) FROM dw.dim_sub)       AS sub_rows,
       (SELECT COUNT(*) FROM dw.dim_flair)     AS flair_rows,
       (SELECT COUNT(*) FROM dw.dim_post)      AS post_rows,
       (SELECT COUNT(*) FROM dw.dim_comment)   AS comment_rows,
       (SELECT COUNT(*) FROM dw.fact_post_vote)    AS post_vote_rows,
       (SELECT COUNT(*) FROM dw.fact_comment_vote) AS comment_vote_rows,
       (SELECT COUNT(*) FROM dw.fact_post_daily)   AS post_daily_rows;
GO

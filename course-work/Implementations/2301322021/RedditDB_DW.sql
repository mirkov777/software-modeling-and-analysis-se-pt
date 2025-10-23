USE RedditDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name='dw') EXEC('CREATE SCHEMA dw');

-- dimentions
IF OBJECT_ID('dw.dim_date') IS NOT NULL DROP TABLE dw.dim_date;
CREATE TABLE dw.dim_date (
  date_key INT PRIMARY KEY,
  date_value DATE,
  year INT,
  month INT,
  day INT
);

-- users
IF OBJECT_ID('dw.dim_user') IS NOT NULL DROP TABLE dw.dim_user;
CREATE TABLE dw.dim_user (
  user_key INT IDENTITY PRIMARY KEY,
  user_id INT,-- [user].id
  username NVARCHAR(50),
  status NVARCHAR(20)
);

-- subreddits
IF OBJECT_ID('dw.dim_sub') IS NOT NULL DROP TABLE dw.dim_sub;
CREATE TABLE dw.dim_sub (
  sub_key INT IDENTITY PRIMARY KEY,
  sub_id INT, -- subreddit.id
  name NVARCHAR(50),
  is_private BIT
);

-- flairs
IF OBJECT_ID('dw.dim_flair') IS NOT NULL DROP TABLE dw.dim_flair;
CREATE TABLE dw.dim_flair (
  flair_key INT IDENTITY PRIMARY KEY,
  flair_id INT,   -- flair.id
  sub_id INT,    -- subreddit.id
  text NVARCHAR(50)
);

-- posts
IF OBJECT_ID('dw.dim_post') IS NOT NULL DROP TABLE dw.dim_post;
CREATE TABLE dw.dim_post (
  post_key INT IDENTITY PRIMARY KEY,
  post_id INT,      -- post.id
  title NVARCHAR(255),
  type NVARCHAR(20),
  created_date_key INT, -- FK to dim_date (value only)
  user_id INT,
  sub_id INT,
  flair_id INT NULL
);

-- comments
IF OBJECT_ID('dw.dim_comment') IS NOT NULL DROP TABLE dw.dim_comment;
CREATE TABLE dw.dim_comment (
  comment_key INT IDENTITY PRIMARY KEY,
  post_id INT,
  seq INT,
  user_id INT,
  created_date_key INT
);


--facts
-- one row per post vote
IF OBJECT_ID('dw.fact_post_vote') IS NOT NULL DROP TABLE dw.fact_post_vote;
CREATE TABLE dw.fact_post_vote (
  date_key INT,
  user_key INT,
  sub_key INT,
  post_key INT,
  flair_key INT NULL,
  vote_value SMALLINT,     -- -1 / +1
  vote_count INT           -- always 1
);

-- one row per comment vote
IF OBJECT_ID('dw.fact_comment_vote') IS NOT NULL DROP TABLE dw.fact_comment_vote;
CREATE TABLE dw.fact_comment_vote (
  date_key INT,
  user_key INT,
  sub_key INT,
  post_key INT,
  comment_key INT,
  vote_value SMALLINT,
  vote_count INT
);

-- one row per post per day (simple snapshot)
IF OBJECT_ID('dw.fact_post_daily') IS NOT NULL DROP TABLE dw.fact_post_daily;
CREATE TABLE dw.fact_post_daily (
  date_key INT,
  sub_key INT,
  post_key INT,
  user_key INT,
  flair_key INT NULL,
  post_score INT,
  comment_count INT,
  vote_count INT
);
GO
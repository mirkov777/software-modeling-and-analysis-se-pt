USE RedditDB;
GO

-- reset in FK order
DELETE FROM comment_vote;
DELETE FROM post_vote;
DELETE FROM subscription;
DELETE FROM comment;
DELETE FROM post;
DELETE FROM flair;
DELETE FROM subreddit;
DELETE FROM [user];

-- reseed identities
DBCC CHECKIDENT ('[user]', RESEED, 0);
DBCC CHECKIDENT ('subreddit', RESEED, 0);
DBCC CHECKIDENT ('flair', RESEED, 0);
DBCC CHECKIDENT ('post', RESEED, 0);

-- quick tally 1..500
;WITH n AS (
  SELECT 1 AS i
  UNION ALL SELECT i+1 FROM n WHERE i < 500
)
SELECT i INTO #tally FROM n OPTION (MAXRECURSION 0);

-- users (30)
INSERT INTO [user](username, email, password_hash, status, karma)
SELECT TOP (30)
  CONCAT('user', i),
  CONCAT('user', i, '@mail.com'),
  CONCAT('hash', i),
  CASE WHEN i % 20 = 0 THEN 'suspended' ELSE 'active' END,
  0
FROM #tally ORDER BY i;

-- subreddits (8)
INSERT INTO subreddit(name, description, is_private)
SELECT TOP (8)
  CONCAT('sub', i),
  CONCAT('Subreddit #', i),
  CASE WHEN i % 8 = 0 THEN 1 ELSE 0 END
FROM #tally ORDER BY i;

-- flairs (2 per subreddit)
INSERT INTO flair(subreddit_id, text, color)
SELECT s.id, x.txt, x.color
FROM subreddit s
CROSS APPLY (VALUES (N'Discussion',N'blue'),(N'Question',N'green')) x(txt,color);

-- posts (~120), no hardcoded IDs
;WITH u AS (SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn FROM [user]),
     s AS (SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn FROM subreddit),
     src AS (
       SELECT TOP (120)
              u.id AS user_id,
              s.id AS subreddit_id,
              CONCAT(N'Post ', t.i) AS title,
              CONCAT(N'Body of post ', t.i) AS content,
              CASE WHEN t.i % 10 IN (0,1) THEN N'image'
                   WHEN t.i % 10 IN (2,3) THEN N'link'
                   ELSE N'text' END AS type
       FROM #tally t
       JOIN u ON u.rn = ((t.i-1) % (SELECT COUNT(*) FROM u)) + 1
       JOIN s ON s.rn = ((t.i-1) % (SELECT COUNT(*) FROM s)) + 1
       ORDER BY t.i
     )
INSERT INTO post(user_id, subreddit_id, flair_id, title, content, type)
SELECT src.user_id,
       src.subreddit_id,
       (SELECT TOP 1 f.id FROM flair f WHERE f.subreddit_id = src.subreddit_id ORDER BY f.id),
       src.title, src.content, src.type
FROM src;

-- comments (2 per post) with seq 1,2
INSERT INTO comment(post_id, seq, user_id, content)
SELECT p.id, seq.seq, u.id, CONCAT(N'Comment ', p.id, N'-', seq.seq)
FROM post p
CROSS APPLY (VALUES (1),(2)) seq(seq)
JOIN [user] u ON u.id = 1 + ((p.id + seq.seq) % (SELECT COUNT(*) FROM [user]));

-- subscriptions (~100 distinct pairs)
;WITH pairs AS (
  SELECT DISTINCT u.id AS user_id, s.id AS subreddit_id,
         ROW_NUMBER() OVER (ORDER BY u.id, s.id) AS rn
  FROM [user] u CROSS JOIN subreddit s
)
INSERT INTO subscription(user_id, subreddit_id)
SELECT user_id, subreddit_id FROM pairs WHERE rn <= 100;

-- post votes: unique (user_id, post_id), ~400 rows
DELETE FROM post_vote;
;WITH u AS (SELECT id AS user_id FROM [user]),
     p AS (SELECT id AS post_id FROM post),
     pairs AS (
       SELECT TOP (400)
              u.user_id, p.post_id,
              ROW_NUMBER() OVER (ORDER BY NEWID()) AS rn
       FROM u CROSS JOIN p
     )
INSERT INTO post_vote(user_id, post_id, value, voted_at)
SELECT user_id, post_id,
       CASE WHEN rn % 3 = 0 THEN -1 ELSE 1 END,
       SYSUTCDATETIME()
FROM pairs;

-- comment votes: unique (user_id, post_id, seq), ~300 rows
DELETE FROM comment_vote;
;WITH u AS (SELECT id AS user_id FROM [user]),
     p AS (SELECT id AS post_id FROM post),
     s AS (SELECT 1 AS seq UNION ALL SELECT 2),
     triples AS (
       SELECT TOP (300)
              u.user_id, p.post_id, s.seq,
              ROW_NUMBER() OVER (ORDER BY NEWID()) AS rn
       FROM u CROSS JOIN p CROSS JOIN s
     )
INSERT INTO comment_vote(user_id, post_id, seq, value, voted_at)
SELECT user_id, post_id, seq,
       CASE WHEN rn % 4 IN (0,1) THEN 1 ELSE -1 END,
       SYSUTCDATETIME()
FROM triples;

DROP TABLE #tally;

-- quick counts
SELECT (SELECT COUNT(*) FROM [user]) AS users,
       (SELECT COUNT(*) FROM subreddit) AS subreddits,
       (SELECT COUNT(*) FROM flair) AS flairs,
       (SELECT COUNT(*) FROM post) AS posts,
       (SELECT COUNT(*) FROM comment) AS comments,
       (SELECT COUNT(*) FROM subscription) AS subscriptions,
       (SELECT COUNT(*) FROM post_vote) AS post_votes,
       (SELECT COUNT(*) FROM comment_vote) AS comment_votes;
GO
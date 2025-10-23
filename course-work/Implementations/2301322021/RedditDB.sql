USE master;
IF DB_ID('RedditDB') IS NOT NULL
BEGIN
  ALTER DATABASE RedditDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE RedditDB;
END;
GO

CREATE DATABASE RedditDB;
GO
USE RedditDB;
GO

-- tables
CREATE TABLE [user] (
  id INT IDENTITY PRIMARY KEY,
  username NVARCHAR(50) NOT NULL UNIQUE,
  email NVARCHAR(100),
  password_hash NVARCHAR(128),
  created_at DATETIME2 DEFAULT SYSUTCDATETIME(),
  status NVARCHAR(20) DEFAULT 'active',
  karma INT DEFAULT 0
);

CREATE TABLE subreddit (
  id INT IDENTITY PRIMARY KEY,
  name NVARCHAR(50) NOT NULL UNIQUE,
  description NVARCHAR(255),
  created_at DATETIME2 DEFAULT SYSUTCDATETIME(),
  is_private BIT DEFAULT 0,
  subscribers_count INT DEFAULT 0
);

CREATE TABLE flair (
  id INT IDENTITY PRIMARY KEY,
  subreddit_id INT NOT NULL
    FOREIGN KEY REFERENCES subreddit(id) -- prevent multi-path iseue
    ,
  text NVARCHAR(50),
  color NVARCHAR(20)
);

CREATE TABLE post (
  id INT IDENTITY PRIMARY KEY,
  user_id INT NOT NULL
    FOREIGN KEY REFERENCES [user](id),
  subreddit_id INT NOT NULL
    FOREIGN KEY REFERENCES subreddit(id) ON DELETE CASCADE,
  flair_id INT NULL
    FOREIGN KEY REFERENCES flair(id) ON DELETE SET NULL,
  title NVARCHAR(255),
  content NVARCHAR(MAX),
  type NVARCHAR(20),
  created_at DATETIME2 DEFAULT SYSUTCDATETIME(),
  score INT DEFAULT 0
);

CREATE TABLE comment (
  post_id INT NOT NULL
    FOREIGN KEY REFERENCES post(id) ON DELETE CASCADE,
  seq INT NOT NULL,
  user_id INT NOT NULL
    FOREIGN KEY REFERENCES [user](id),
  content NVARCHAR(MAX),
  created_at DATETIME2 DEFAULT SYSUTCDATETIME(),
  score INT DEFAULT 0,
  depth INT DEFAULT 0,
  PRIMARY KEY (post_id, seq)
);

CREATE TABLE subscription (
  user_id INT NOT NULL
    FOREIGN KEY REFERENCES [user](id) ON DELETE CASCADE,
  subreddit_id INT NOT NULL
    FOREIGN KEY REFERENCES subreddit(id) ON DELETE CASCADE,
  since DATETIME2 DEFAULT SYSUTCDATETIME(),
  PRIMARY KEY (user_id, subreddit_id)
);

CREATE TABLE post_vote (
  user_id INT NOT NULL
    FOREIGN KEY REFERENCES [user](id) ON DELETE CASCADE,
  post_id INT NOT NULL
    FOREIGN KEY REFERENCES post(id) ON DELETE CASCADE,
  value SMALLINT CHECK (value IN (-1, 1)),
  voted_at DATETIME2 DEFAULT SYSUTCDATETIME(),
  PRIMARY KEY (user_id, post_id)
);

CREATE TABLE comment_vote (
  user_id INT NOT NULL
    FOREIGN KEY REFERENCES [user](id) ON DELETE CASCADE,
  post_id INT NOT NULL,
  seq INT NOT NULL,
  value SMALLINT CHECK (value IN (-1, 1)),
  voted_at DATETIME2 DEFAULT SYSUTCDATETIME(),
  PRIMARY KEY (user_id, post_id, seq),
  FOREIGN KEY (post_id, seq) REFERENCES comment(post_id, seq) ON DELETE CASCADE
);
GO

-- functions
CREATE FUNCTION post_count(@user_id INT)
RETURNS INT
AS
BEGIN
  RETURN (SELECT COUNT(*) FROM post WHERE user_id = @user_id);
END;
GO

CREATE FUNCTION avg_post_score(@sub_id INT)
RETURNS FLOAT
AS
BEGIN
  RETURN (SELECT AVG(CAST(score AS FLOAT)) FROM post WHERE subreddit_id = @sub_id);
END;
GO

-- procs
CREATE PROCEDURE add_post
  @user_id INT,
  @sub_id INT,
  @title NVARCHAR(255),
  @content NVARCHAR(MAX)
AS
BEGIN
  INSERT INTO post(user_id, subreddit_id, title, content, type)
  VALUES(@user_id, @sub_id, @title, @content, 'text');
END;
GO

CREATE PROCEDURE add_vote
  @user_id INT,
  @post_id INT,
  @value SMALLINT
AS
BEGIN
  IF EXISTS (SELECT 1 FROM post_vote WHERE user_id=@user_id AND post_id=@post_id)
    UPDATE post_vote SET value=@value, voted_at=SYSUTCDATETIME()
    WHERE user_id=@user_id AND post_id=@post_id;
  ELSE
    INSERT INTO post_vote(user_id, post_id, value) VALUES(@user_id, @post_id, @value);
END;
GO

-- triggers
CREATE TRIGGER update_post_score ON post_vote
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
  UPDATE p
  SET score = ISNULL(v.total, 0)
  FROM post p
  OUTER APPLY (SELECT SUM(value) AS total FROM post_vote WHERE post_id=p.id) v
  WHERE p.id IN (
    SELECT post_id FROM inserted
    UNION
    SELECT post_id FROM deleted
  );
END;
GO

CREATE TRIGGER update_comment_score ON comment_vote
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
  UPDATE c
  SET score = ISNULL(v.total, 0)
  FROM comment c
  OUTER APPLY (
    SELECT SUM(value) AS total
    FROM comment_vote
    WHERE post_id=c.post_id AND seq=c.seq
  ) v
  WHERE EXISTS (SELECT 1 FROM inserted i WHERE i.post_id=c.post_id AND i.seq=c.seq)
     OR EXISTS (SELECT 1 FROM deleted  d WHERE d.post_id=c.post_id AND d.seq=c.seq);
END;
GO

-- test seed
INSERT INTO [user](username,email,password_hash) VALUES
 ('martin','martin@mail.com','hash123'),
 ('alex','alex@mail.com','hash321');

INSERT INTO subreddit(name,description) VALUES
 ('programming','Everything about code'),
 ('cars','Car enthusiasts');

INSERT INTO flair(subreddit_id, text, color) VALUES
 (1,'Discussion','blue'),
 (1,'Question','green'),
 (2,'Build','red');

INSERT INTO post(user_id,subreddit_id,flair_id,title,content,type)
VALUES (1,1,1,'Hello world','First post','text'),
       (2,2,3,'Audi mods','Discuss tuning','text');
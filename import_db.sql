CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  fname CHAR(255) NOT NULL,
  lname CHAR(255) NOT NULL
);

CREATE TABLE questions (
  id INTEGER PRIMARY KEY,
  title CHAR(255) NOT NULL,
  body CHAR(255) NOT NULL,
  author_id INTEGER NOT NULL,
  FOREIGN KEY (author_id) REFERENCES users(id)
);

CREATE TABLE question_followers (
  question_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  FOREIGN KEY (question_id) REFERENCES questions(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE replies (
  id INTEGER PRIMARY KEY,
  question_id INTEGER NOT NULL,
  parent_id INTEGER,
  user_id INTEGER NOT NULL,
  body CHAR(255) NOT NULL,
  FOREIGN KEY (question_id) REFERENCES questions(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE question_likes (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL
);

CREATE TABLE tags (
  id INTEGER PRIMARY KEY,
  tag CHAR(255)
);

CREATE TABLE question_tags (
  tag_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,
  FOREIGN KEY (tag_id) REFERENCES tags(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);

INSERT INTO
  users (fname, lname)
VALUES
  ('Rohan', 'Sahai'),
  ('Steve', 'Brokaw');

INSERT INTO
  questions (title, body, author_id)
VALUES
  ('General Inquiry', 'What color is a banana?',
   ( SELECT id FROM users
    WHERE lname = 'Sahai' )),
  ('High School Girls', 'Where do the high-school girls hang out?',
    ( SELECT id FROM users
    WHERE lname = 'Brokaw'));


INSERT INTO
  question_followers(question_id, user_id)
VALUES
  ((SELECT id FROM questions WHERE title = 'General Inquiry'),
   (SELECT id FROM users where lname = 'Brokaw')),

  ((SELECT id FROM questions WHERE title = 'High School Girls'),
   (SELECT id FROM users where lname = 'Sahai')),

  ((SELECT id FROM questions WHERE title = 'High School Girls'),
   (SELECT id FROM users where lname = 'Brokaw'));

INSERT INTO
  replies(question_id, user_id, body)
VALUES
  ((SELECT id FROM questions WHERE title = 'General Inquiry'),
  (SELECT id FROM users WHERE lname = 'Brokaw'),
  "Yellow, duh!");

INSERT INTO
  question_likes(user_id, question_id)
VALUES
  ((SELECT id FROM users WHERE lname = 'Sahai'),
  (SELECT id FROM questions WHERE title = 'General Inquiry')),

  ((SELECT id FROM users WHERE lname = 'Brokaw'),
  (SELECT id FROM questions WHERE title = 'General Inquiry')),

  ((SELECT id FROM users WHERE lname = 'Brokaw'),
  (SELECT id FROM questions WHERE title = 'High School Girls'));

INSERT INTO
  tags (tag)
VALUES
  ('html'),
  ('ruby'),
  ('fruits'),
  ('creep'),
  ('javascript');


INSERT INTO
  question_tags (tag_id, question_id)
VALUES
  ((SELECT id FROM tags WHERE tag = 'fruits'),
  (SELECT id FROM questions WHERE id = 1)),
  ((SELECT id FROM tags WHERE tag = 'creep'),
  (SELECT id FROM questions WHERE id = 2)),
  ((SELECT id FROM tags WHERE tag = 'fruits'),
  (SELECT id FROM questions WHERE id = 2));


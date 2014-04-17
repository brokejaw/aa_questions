require 'singleton'
require 'sqlite3'

class QuestionsDatabase < SQLite3::Database
  include Singleton

  def initialize
    super("questions.db")
    self.results_as_hash = true
    self.type_translation = true
  end
end

class BaseModel
  def save

  end
end

module Save

  def save
    table = self.class.table
    column_names = self.class.column_names

    if self.id.nil?
      QuestionsDatabase.instance.execute(<<-SQL)
      INSERT INTO
        #{table} (#{column_names.join(', ')})
      VALUES
        (?, ?)
      SQL
      self.id = QuestionsDatabase.instance.last_insert_row_id
    else
      QuestionsDatabase.instance.execute(<<-SQL, self.fname, self.lname, self.id)
      UPDATE
        #{table}
      SET
        fname = ?, lname = ?
      WHERE
        id = ?
      SQL
    end
  end
end

class User
  #include Save
  def self.all
    results = QuestionsDatabase.instance.execute("SELECT * FROM users")
    results.map { |result| User.new(result) }
  end

  def self.find_by_id(id)
    results = QuestionsDatabase.instance.execute(<<-SQL, id)
    SELECT *
    FROM users
    WHERE id = ?
    SQL
    user = results[0]
    User.new(user)
  end

  def self.find_by_name(fname, lname)
    results = QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
    SELECT *
    FROM users
    WHERE fname = ? AND lname = ?
    SQL
    name = results[0]
    User.new(name)
  end

  def self.table
    "users"
  end

  def self.columns
    ["id", "fname", "lname"]
  end

  attr_accessor :id, :fname, :lname

  def initialize(options = {})
    @id = options["id"]
    @fname = options["fname"]
    @lname = options["lname"]
  end

  def save
    if self.id.nil?
      QuestionsDatabase.instance.execute(<<-SQL, self.fname, self.lname)
      INSERT INTO
        users (fname, lname)
      VALUES
        (?, ?)
      SQL
      self.id = QuestionsDatabase.instance.last_insert_row_id
    else
      QuestionsDatabase.instance.execute(<<-SQL, self.fname, self.lname, self.id)
      UPDATE
        users
      SET
        fname = ?, lname = ?
      WHERE
        id = ?
      SQL
    end
  end

  def authored_questions
    Question.find_by_author_id(self.id)
  end

  def authored_replies
    Reply.find_by_user_id(self.id)
  end

  def followed_questions
    QuestionFollower.followed_questions_for_user_id(self.id)
  end

  def liked_questions
    QuestionLike.liked_questions_for_user_id(self.id)
  end

  def average_karma
    results = QuestionsDatabase.instance.execute(<<-SQL, self.id)
    SELECT SUM(num_likes)/COUNT(queries)
    FROM
    (SELECT ql.question_id queries, COUNT(ql.user_id) num_likes
    FROM question_likes ql
    WHERE ql.question_id IN
    (SELECT q.id
    FROM questions q JOIN users u ON q.author_id = u.id
    WHERE author_id = ?)
    GROUP BY ql.question_id
    ORDER BY ql.user_id DESC)
    SQL
  end

end

class Question
  def self.all
    results = QuestionsDatabase.instance.execute("SELECT * FROM questions")
    results.map { |result| Question.new(result)}
  end

  def self.find_by_author_id(id)
    results = QuestionsDatabase.instance.execute(<<-SQL, id)
    SELECT *
    FROM questions
    WHERE author_id = ?
    SQL
    results.map { |result| Question.new(result)}
  end

  def self.find_by_id(id)
    results = QuestionsDatabase.instance.execute(<<-SQL, id)
    SELECT *
    FROM questions
    WHERE id = ?
    SQL
    question = results[0]
    Question.new(question)
  end

  def self.most_followed(n)
    QuestionFollower.most_followed_questions(n)
  end

  def self.most_liked(n)
    QuestionLike.most_liked_questions(n)
  end

  attr_accessor :id, :title, :body, :author_id

  def initialize(options = {})
    @id = options["id"]
    @title = options["title"]
    @body = options["body"]
    @author_id = options["author_id"]
  end

  def author
    results = QuestionsDatabase.instance.execute(<<-SQL, self.author_id)
    SELECT *
    FROM users
    WHERE id = ?
    SQL
    author = results[0]
    User.new(author)
  end

  def save
    if self.id.nil?
      QuestionsDatabase.instance.execute(<<-SQL, self.title, self.body, self.author_id)
      INSERT INTO
        questions (title, body, author_id)
      VALUES
        (?, ?, ?)
      SQL
      self.id = QuestionsDatabase.instance.last_insert_row_id
    else
      QuestionsDatabase.instance.execute(<<-SQL, self.title, self.body, self.author_id, self.id)
      UPDATE
        questions
      SET
        title = ?, body = ?, author_id = ?
      WHERE
        id = ?
      SQL
    end
  end

  def replies
    Reply.find_by_question_id(self.id)
  end

  def followers
    QuestionFollower.followers_for_question_id(self.id)
  end

  def likers
    QuestionLike.likers_for_question_id(self.id)
  end

  def num_likes
    QuestionLike.num_likes_for_question_id(self.id)
  end
end

class QuestionFollower
  def self.all
    results = QuestionsDatabase.instance.execute("SELECT * FROM question_followers")
    results.map { |result| QuestionFollower.new(result)}
  end

  def self.followers_for_question_id(question_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, question_id)
    SELECT u.id, u.fname, u.lname
    FROM users u JOIN question_followers q ON u.id = q.user_id
    WHERE q.question_id = ?
    SQL

    results.map { |result| User.new(result) }
  end

  def self.followed_questions_for_user_id(user_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, user_id)
    SELECT q.id, q.title, q.body, q.author_id
    FROM questions q JOIN question_followers qf ON q.id = qf.question_id
    WHERE qf.user_id = ?
    SQL

    results.map { |result| Question.new(result) }
  end

  def self.most_followed_questions(n)
    results = QuestionsDatabase.instance.execute(<<-SQL, n)
    SELECT q.id, q.title, q.body, q.author_id
    FROM questions q
    WHERE q.id IN
    (SELECT question_id
    FROM question_followers
    GROUP BY question_id
    ORDER BY COUNT(user_id) DESC
    LIMIT ?)
    SQL
    results.map { |result| Question.new(result) }
  end

  attr_accessor :question_id, :user_id

  def initialize(options = {})
    @question_id = options["question_id"]
    @user_id = options["user_id"]
  end
end

class Reply
  def self.all
    results = QuestionsDatabase.instance.execute("SELECT * FROM replies")
    results.map { |result| Reply.new(result)}
  end

  def self.find_by_question_id(question_id)
    replies = QuestionsDatabase.instance.execute(<<-SQL, question_id)
    SELECT *
    FROM replies
    WHERE question_id = ?
    SQL
    replies.map { |reply| Reply.new(reply) }
  end

  def self.find_by_user_id(user_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, user_id)
    SELECT *
    FROM replies
    WHERE user_id = ?
    SQL
    results.map { |result| Reply.new(result)}
  end

  def self.find_by_id(id)
    results = QuestionsDatabase.instance.execute(<<-SQL, id)
    SELECT *
    FROM replies
    WHERE id = ?
    SQL
    reply = results[0]

    Reply.new(reply)
  end

  attr_accessor :id, :question_id, :user_id, :parent_id, :body

  def initialize(options = {})
    @id = options["id"]
    @question_id = options["question_id"]
    @user_id = options["user_id"]
    @parent_id = options["parent_id"]
    @body = options["body"]
  end

  def save
    if self.id.nil?
      QuestionsDatabase.instance.execute(<<-SQL, self.question_id, self.user_id, self.parent_id, self.body)
      INSERT INTO
        replies (question_id, user_id, parent_id, body)
      VALUES
        (?, ?, ?, ?)
      SQL
      self.id = QuestionsDatabase.instance.last_insert_row_id
    else
      QuestionsDatabase.instance.execute(<<-SQL, self.question_id, self.user_id, self.parent_id, self.body, self.id)
      UPDATE
      replies
      SET
        question_id = ?, user_id = ?, parent_id = ?, body = ?
      WHERE
        id = ?
      SQL
    end
  end

  def author
    results = QuestionsDatabase.instance.execute(<<-SQL, self.user_id)
    SELECT *
    FROM users
    WHERE id = ?
    SQL
    author = results[0]

    User.new(author)
  end

  def question
    results = QuestionsDatabase.instance.execute(<<-SQL, self.question_id)
    SELECT *
    FROM questions
    WHERE id = ?
    SQL
    question = results[0]

    Question.new(question)
  end

  def parent_reply
    results = QuestionsDatabase.instance.execute(<<-SQL, self.parent_id)
    SELECT *
    FROM replies
    WHERE id = ?
    SQL
    reply = results[0]
    raise "No parent reply" if reply.nil?
    Reply.new(reply)
  end

  def child_replies
    results = QuestionsDatabase.instance.execute(<<-SQL, self.id)
    SELECT *
    FROM replies
    WHERE parent_id = ?
    SQL
    reply = results[0]
    raise "No child reply" if reply.nil?

    Reply.new(reply)
  end
end

class QuestionLike
  def self.all
    results = QuestionsDatabase.instance.execute("SELECT * FROM question_likes")
    results.map { |result| QuestionLike.new(result)}
  end

  def self.find_by_id(id)
    results = QuestionsDatabase.instance.execute(<<-SQL, id)
    SELECT *
    FROM question_likes
    WHERE id = ?
    SQL
    question_like = results[0]

    QuestionLike.new(question_like)
  end

  def self.likers_for_question_id(question_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, question_id)
    SELECT u.id, u.fname, u.lname
    FROM users u JOIN question_likes q ON u.id = q.user_id
    WHERE q.question_id = ?
    SQL
    results.map { |result| User.new(result) }
  end

  def self.num_likes_for_question_id(question_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, question_id)
    SELECT COUNT(*) num_likes
    FROM users u JOIN question_likes q ON u.id = q.user_id
    WHERE q.question_id = ?
    SQL
    results[0]['num_likes']
  end

  def self.liked_questions_for_user_id(user_id)
    results = QuestionsDatabase.instance.execute(<<-SQL, user_id)
    SELECT q.id, q.title, q.body, q.author_id
    FROM questions q JOIN question_likes ql ON q.id = ql.question_id
    WHERE ql.user_id = ?
    SQL

    results.map { |result| Question.new(result) }
  end

  def self.most_liked_questions(n)
    results = QuestionsDatabase.instance.execute(<<-SQL, n)
    SELECT q.id, q.title, q.body, q.author_id
    FROM questions q
    WHERE q.id IN
    (SELECT ql.question_id
    FROM question_likes ql
    GROUP BY ql.question_id
    ORDER BY COUNT(ql.user_id) DESC
    LIMIT ? )
    SQL

    results.map { |result| Question.new(result) }
  end

  attr_accessor :id, :user_id, :question_id

  def initialize(options = {})
    @id = options["id"]
    @user_id = options["user_id"]
    @question_id = options["question_id"]
  end
end

class Tag
  def self.all
    results = QuestionsDatabase.instance.execute("SELECT * FROM tags")
    results.map { |result| Tag.new(result)}
  end

  def self.find_by_id(id)
    results = QuestionsDatabase.instance.execute(<<-SQL, id)
    SELECT *
    FROM tags
    WHERE id = ?
    SQL
    tag = results[0]

    Tag.new(tag)
  end

  def self.most_popular(n)
    results = QuestionsDatabase.instance.execute(<<-SQL, n)
    SELECT t.id, t.tag
    FROM tags t JOIN question_tags qt ON t.id = qt.tag_id
    JOIN question_likes ql ON qt.question_id = ql.question_id
    GROUP BY t.tag
    ORDER BY COUNT(ql.user_id) DESC
    LIMIT ?
    SQL
  end

  attr_accessor :id, :tag

  def initialize(options = {})
    @id = options["id"]
    @tag = options["tag"]
  end

  def most_popular_questions(n)
    results = QuestionsDatabase.instance.execute(<<-SQL, self.id, n)

    SELECT id, title, body, author_id
    FROM questions q JOIN
    (SELECT *
    FROM question_tags qt
    WHERE qt.tag_id = ?) qwt
    ON q.id = qwt.question_id
    WHERE q.id IN
    (SELECT ql.question_id
    FROM question_likes ql
    GROUP BY ql.question_id
    ORDER BY COUNT(ql.user_id) DESC
    LIMIT ? )
    SQL

  end

end
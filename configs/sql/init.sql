CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE IF NOT EXISTS "users"
(
    About    text,
    Email    citext UNIQUE,
    FullName text NOT NULL,
    Nickname citext PRIMARY KEY
);

CREATE INDEX IF NOT EXISTS users_nickname_lower_index ON users (lower(users.Nickname));
CREATE INDEX IF NOT EXISTS users_nickname_index ON users ((users.Nickname));
CREATE INDEX IF NOT EXISTS users_email_index ON users (lower(Email));

CREATE TABLE IF NOT EXISTS forum
(
    "user"  citext,
    Posts   BIGINT DEFAULT 0,
    Slug    citext PRIMARY KEY,
    Threads INT    DEFAULT 0,
    title   text,
    FOREIGN KEY ("user") REFERENCES "users" (nickname)
);

CREATE INDEX IF NOT EXISTS forum_slug_lower_index ON forum (lower(forum.Slug));

CREATE TABLE IF NOT EXISTS thread
(
    author  citext,
    created timestamp with time zone default current_timestamp,
    forum   citext,
    id      SERIAL PRIMARY KEY,
    message text NOT NULL,
    slug    citext UNIQUE,
    title   text not null,
    votes   INT                      default 0,
    FOREIGN KEY (author) REFERENCES "users" (nickname),
    FOREIGN KEY (forum) REFERENCES "forum" (slug)
);

CREATE INDEX IF NOT EXISTS thread_slug_lower_index ON thread (lower(slug));
CREATE INDEX IF NOT EXISTS thread_slug_index ON thread (slug);
CREATE INDEX IF NOT EXISTS thread_slug_id_index ON thread (lower(slug), id);
CREATE INDEX IF NOT EXISTS thread_forum_lower_index ON thread (lower(forum));
CREATE INDEX IF NOT EXISTS thread_id_forum_index ON thread (id, forum);
CREATE INDEX IF NOT EXISTS thread_created_index ON thread (created);

CREATE OR REPLACE FUNCTION update_user_forum() RETURNS TRIGGER AS
$update_users_forum$
BEGIN
    INSERT INTO users_forum (nickname, Slug) VALUES (NEW.author, NEW.forum) on conflict do nothing;
    return NEW;
end
$update_users_forum$ LANGUAGE plpgsql;


CREATE TABLE IF NOT EXISTS post
(
    author   citext NOT NULL,
    created  timestamp with time zone default current_timestamp,
    forum    citext,
    id       BIGSERIAL PRIMARY KEY,
    isEdited BOOLEAN                  DEFAULT FALSE,
    message  text   NOT NULL,
    parent   BIGINT                   DEFAULT 0,
    thread   INT,
    path     BIGINT[]                 default array []::INTEGER[],
    FOREIGN KEY (author) REFERENCES "users" (nickname)
);

CREATE INDEX IF NOT EXISTS post_first_parent_thread_index ON post ((post.path[1]), thread);
CREATE INDEX IF NOT EXISTS post_first_parent_id_index ON post ((post.path[1]), id);
CREATE INDEX IF NOT EXISTS post_first_parent_index ON post ((post.path[1]));
CREATE INDEX IF NOT EXISTS post_path_index ON post ((post.path));
CREATE INDEX IF NOT EXISTS post_thread_index ON post (thread);
CREATE INDEX IF NOT EXISTS post_thread_id_index ON post (thread, id);
CREATE INDEX IF NOT EXISTS post_path_id_index ON post (id, (post.path));
CREATE INDEX IF NOT EXISTS post_thread_path_id_index ON post (thread, (post.parent), id);

CREATE OR REPLACE FUNCTION update_path() RETURNS TRIGGER AS
$update_path$
DECLARE
    parent_path         BIGINT[];
    first_parent_thread INT;
BEGIN
    IF (NEW.parent IS NULL) THEN
        NEW.path := array_append(new.path, new.id);
    ELSE
        SELECT path FROM post WHERE id = new.parent INTO parent_path;
        SELECT thread FROM post WHERE id = parent_path[1] INTO first_parent_thread;
        IF NOT FOUND OR first_parent_thread != NEW.thread THEN
            RAISE EXCEPTION 'parent is from different thread' USING ERRCODE = '00409';
        end if;

        NEW.path := NEW.path || parent_path || new.id;
    end if;
    UPDATE forum SET Posts=Posts + 1 WHERE lower(forum.slug) = lower(new.forum);
    RETURN new;
end
$update_path$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS vote
(
    nickname citext NOT NULL,
    voice    INT,
    idThread INT,

    FOREIGN KEY (nickname) REFERENCES "users" (nickname),
    UNIQUE (nickname, idThread)
);

CREATE INDEX IF NOT EXISTS vote_nickname ON vote (lower(nickname), idThread, voice);

CREATE TABLE IF NOT EXISTS users_forum
(
    nickname citext NOT NULL,
    Slug     citext NOT NULL,
    PRIMARY KEY (nickname, Slug)
);

CREATE INDEX IF NOT EXISTS users_forum_forum_user_index ON users_forum (lower(users_forum.Slug), nickname);
CREATE INDEX IF NOT EXISTS users_forum_user_index ON users_forum (nickname);
CREATE INDEX IF NOT EXISTS users_forum_forum_index ON users_forum ((users_forum.Slug));

CREATE OR REPLACE FUNCTION insert_votes() RETURNS TRIGGER AS
$update_users_forum$
BEGIN
    UPDATE thread SET votes=(votes+NEW.voice) WHERE id=NEW.idThread;
    return NEW;
end
$update_users_forum$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_votes() RETURNS TRIGGER AS
$update_users_forum$
BEGIN
    UPDATE thread SET votes=(votes+NEW.voice*2) WHERE id=NEW.idThread;
    return NEW;
end
$update_users_forum$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_threads_count() RETURNS TRIGGER AS
$update_users_forum$
BEGIN
    UPDATE forum SET Threads=(Threads+1) WHERE LOWER(slug)=LOWER(NEW.forum);
    return NEW;
end
$update_users_forum$ LANGUAGE plpgsql;

CREATE TRIGGER thread_insert_user_forum
    AFTER INSERT
    ON thread
    FOR EACH ROW
EXECUTE PROCEDURE update_user_forum();

CREATE TRIGGER post_insert_user_forum
    AFTER INSERT
    ON post
    FOR EACH ROW
EXECUTE PROCEDURE update_user_forum();

CREATE TRIGGER path_update_trigger
    BEFORE INSERT
    ON post
    FOR EACH ROW
EXECUTE PROCEDURE update_path();

CREATE TRIGGER add_vote
    BEFORE INSERT
    ON vote
    FOR EACH ROW
EXECUTE PROCEDURE insert_votes();

CREATE TRIGGER add_thread_to_forum
    BEFORE INSERT
    ON thread
    FOR EACH ROW
EXECUTE PROCEDURE update_threads_count();

CREATE TRIGGER edit_vote
    BEFORE UPDATE
    ON vote
    FOR EACH ROW
EXECUTE PROCEDURE update_votes();

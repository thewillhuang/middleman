CREATE SCHEMA middleman_priv;
CREATE SCHEMA middleman_pub;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM public;

CREATE FUNCTION middleman_pub.set_updated_at_column() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION middleman_pub.set_geog_column() RETURNS TRIGGER AS $$
BEGIN
  NEW.geog := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE middleman_pub.phone (
  id BIGSERIAL PRIMARY KEY,
  country_code TEXT NOT NULL,
  phone TEXT NOT NULL,
  ext TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER phone_updated_at BEFORE UPDATE
  ON middleman_pub.phone
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_updated_at_column();

COMMENT ON TABLE middleman_pub.phone IS
  E'@omit create,update,delete,filter,all';

CREATE TABLE middleman_pub.person (
  id BIGSERIAL PRIMARY KEY,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  phone_id BIGINT REFERENCES middleman_pub.phone ON UPDATE CASCADE,
  longitude REAL NOT NULL DEFAULT 0,
  latitude REAL NOT NULL DEFAULT 0,
  geog GEOMETRY,
  is_client BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON middleman_pub.person USING GIST (geog);
CREATE INDEX ON middleman_pub.person (is_client) WHERE is_client = FALSE;

CREATE TRIGGER person_updated_at BEFORE UPDATE
  ON middleman_pub.person
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_updated_at_column();

CREATE TRIGGER PERSON_set_geog_column BEFORE INSERT OR UPDATE
  ON middleman_pub.person
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_geog_column();

COMMENT ON TABLE middleman_pub.person IS
  E'@omit create,update,delete,filter,all';

CREATE TABLE middleman_pub.photo (
  id BIGSERIAL PRIMARY KEY,
  url TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER photo_updated_at BEFORE UPDATE
  ON middleman_pub.photo
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_updated_at_column();

COMMENT ON TABLE middleman_pub.photo IS
  E'@omit create,update,delete,filter,all';

CREATE TYPE middleman_pub.task_status AS ENUM (
  'closed', -- task cancled
  'opened', -- task requested
  'scheduled', -- task with fulfiller found
  'pending', -- finished task awaiting client confirmation
  'finished' -- finished tasks
);

CREATE TYPE middleman_pub.task_type AS ENUM (
  'car cabin air filter change',
  'car detail',
  'car headlights upgrade',
  'car oil change',
  'car selling',
  'car tire replacement',
  'car wash',
  'car windshield wiper',
  'elder bathing',
  'elder cooking',
  'elder shopping',
  'elder transportation',
  'home appliance fixing',
  'home cleaning',
  'home pest control',
  'home plumming',
  'home water filter',
  'home water softening',
  'logo design',
  'maid',
  'massage',
  'medical tourism',
  'pet bnb',
  'photoshop',
  'storage pickup',
  'junk dump'
);

CREATE TYPE middleman_pub.task_attribute AS ENUM (
  'car make',
  'car model',
  'car year',
  'car license plate',
  'car color',
  'direction notes'
);

CREATE TYPE middleman_pub.user_type AS ENUM (
  'fulfiller',
  'requester',
  'open fulfiller',
  'none'
);

CREATE TABLE middleman_pub.task_permission (
  current_status middleman_pub.task_status NOT NULL,
  user_type middleman_pub.user_type NOT NULL,
  can_update BOOLEAN,
  can_update_to middleman_pub.task_status,
  PRIMARY KEY (current_status, user_type)
);

COMMENT ON TABLE middleman_pub.task_permission IS
  E'@omit';

INSERT INTO middleman_pub.task_permission (current_status, user_type, can_update_to) VALUES
  ('opened', 'requester', 'closed'),
  ('opened', 'open fulfiller', 'scheduled'),
  ('scheduled', 'fulfiller', 'pending'),
  ('pending', 'requester', 'finished');

CREATE TABLE middleman_pub.task (
  id BIGSERIAL PRIMARY KEY,
  requestor_id BIGINT NOT NULL REFERENCES middleman_pub.person ON UPDATE CASCADE,
  fulfiller_id BIGINT REFERENCES middleman_pub.person ON UPDATE CASCADE,
  longitude REAL NOT NULL,
  latitude REAL NOT NULL,
  scheduled_for TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  geog GEOMETRY,
  rating SMALLINT,
  category middleman_pub.task_type NOT NULL,
  status middleman_pub.task_status NOT NULL DEFAULT 'opened',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON middleman_pub.task USING GIST (geog);
CREATE INDEX ON middleman_pub.task (fulfiller_id);
CREATE INDEX ON middleman_pub.task (status) WHERE status != 'finished' AND status != 'closed';

CREATE TRIGGER task_updated_at BEFORE UPDATE
  ON middleman_pub.task
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_updated_at_column();

CREATE TRIGGER task_set_geog_column BEFORE INSERT OR UPDATE
  ON middleman_pub.task
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_geog_column();

COMMENT ON TABLE middleman_pub.task IS
  E'@omit all,delete,update';

CREATE TABLE middleman_pub.task_detail (
  task_id BIGINT NOT NULL REFERENCES middleman_pub.task ON UPDATE CASCADE,
  attribute middleman_pub.task_attribute NOT NULL,
  detail TEXT NOT NULL,
  PRIMARY KEY (task_id, attribute),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER task_detail_updated_at BEFORE UPDATE
  ON middleman_pub.task_detail
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_updated_at_column();

CREATE UNIQUE INDEX ON middleman_pub.task_detail (task_id, attribute);

COMMENT ON TABLE middleman_pub.task_detail IS
  E'@omit all';

-- CREATE TABLE middleman_pub.reply (
--   id BIGSERIAL PRIMARY KEY,
--   commentary TEXT,
--   person_id BIGINT NOT NULL REFERENCES middleman_pub.person ON UPDATE CASCADE,
--   author_id BIGINT NOT NULL REFERENCES middleman_pub.person ON UPDATE CASCADE,
--   task_id BIGINT NOT NULL REFERENCES middleman_pub.task ON UPDATE CASCADE,
--   stars SMALLINT,
--   deleted BOOLEAN NOT NULL DEFAULT FALSE,
--   created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
--   updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
-- );

-- CREATE INDEX ON middleman_pub.reply (task_id);
-- CREATE INDEX ON middleman_pub.reply (person_id);
-- CREATE INDEX ON middleman_pub.reply (author_id);

-- CREATE TRIGGER comment_updated_at BEFORE UPDATE
--   ON middleman_pub.reply
--   FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_updated_at_column();

-- COMMENT ON TABLE middleman_pub.reply IS
--   E'@omit all,delete';

-- CREATE TABLE middleman_pub.reply_tree (
--   parent_id BIGINT NOT NULL REFERENCES middleman_pub.reply ON UPDATE CASCADE,
--   child_id BIGINT NOT NULL REFERENCES middleman_pub.reply ON UPDATE CASCADE,
--   depth SMALLINT NOT NULL,
--   created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
--   updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
-- );

-- CREATE TRIGGER comment_tree_updated_at BEFORE UPDATE
--   ON middleman_pub.reply_tree
--   FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_updated_at_column();

-- COMMENT ON TABLE middleman_pub.reply_tree IS
--   E'@omit create,update,delete,filter,all';

-- ALTER TABLE middleman_pub.reply_tree ADD CONSTRAINT comment_tree_pkey PRIMARY KEY (parent_id, child_id);

CREATE TABLE middleman_pub.person_type (
  person_id BIGINT NOT NULL REFERENCES middleman_pub.person ON UPDATE CASCADE,
  category middleman_pub.task_type NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER person_type_updated_at BEFORE UPDATE
  ON middleman_pub.person_type
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_updated_at_column();

CREATE UNIQUE INDEX ON middleman_pub.person_type (person_id, category);

COMMENT ON TABLE middleman_pub.person_type IS
  E'@omit create,update,delete,filter,all';

CREATE TABLE middleman_pub.person_photo (
  person_id BIGINT NOT NULL REFERENCES middleman_pub.person ON UPDATE CASCADE,
  photo_id BIGINT NOT NULL REFERENCES middleman_pub.photo ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX ON middleman_pub.person_photo (person_id, photo_id);

CREATE TRIGGER person_photo_updated_at BEFORE UPDATE
  ON middleman_pub.person_photo
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_updated_at_column();

COMMENT ON TABLE middleman_pub.person_photo IS
  E'@omit create,update,delete,filter,all';

CREATE TABLE middleman_pub.task_photo (
  task_id BIGINT NOT NULL REFERENCES middleman_pub.task ON UPDATE CASCADE,
  photo_id BIGINT NOT NULL REFERENCES middleman_pub.photo ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX ON middleman_pub.task_photo (task_id, photo_id);

CREATE TRIGGER task_photo_updated_at BEFORE UPDATE
  ON middleman_pub.task_photo
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_updated_at_column();

COMMENT ON TABLE middleman_pub.task_photo IS
  E'@omit create,update,delete,filter,all';

CREATE TABLE middleman_priv.person_account (
  person_id        BIGINT PRIMARY KEY REFERENCES middleman_pub.person ON UPDATE CASCADE,
  email            TEXT NOT NULL UNIQUE CHECK (email ~* '^.+@.+\..+$'),
  password_hash    TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER person_account_updated_at BEFORE UPDATE
  ON middleman_priv.person_account
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_updated_at_column();

COMMENT ON TABLE middleman_priv.person_account IS
  'Private information about a person’s account.';
COMMENT ON COLUMN middleman_priv.person_account.person_id IS
  'The id of the person associated with this account.';
COMMENT ON COLUMN middleman_priv.person_account.email IS
  'The email address of the person.';
COMMENT ON COLUMN middleman_priv.person_account.password_hash IS
  'An opaque hash of the person’s password.';

-- auth functions
CREATE FUNCTION middleman_pub.register_person(
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  password TEXT,
  is_client BOOLEAN DEFAULT FALSE
) RETURNS middleman_pub.person AS $$
DECLARE
  person middleman_pub.person;
BEGIN
  INSERT INTO middleman_pub.person (first_name, last_name, is_client) VALUES
    (first_name, last_name, is_client)
    RETURNING * INTO person;

  INSERT INTO middleman_priv.person_account (person_id, email, password_hash) VALUES
    (person.id, email, crypt(password, gen_salt('bf')));

  RETURN person;
END;
$$ LANGUAGE plpgsql strict security definer;

COMMENT ON FUNCTION middleman_pub.register_person(TEXT, TEXT, TEXT, TEXT, BOOLEAN) IS
  'Registers a single person and creates an account in our forum.';

CREATE ROLE  middleman_admin LOGIN PASSWORD 'voodoo3d';
CREATE ROLE middleman_visitor;
CREATE ROLE middleman_user;
GRANT middleman_visitor TO middleman_admin;
GRANT middleman_user TO middleman_admin;
GRANT USAGE ON SCHEMA middleman_pub TO middleman_visitor, middleman_user, middleman_admin;

CREATE TYPE middleman_pub.jwt_token AS (
  role TEXT,
  person_id BIGINT
);

CREATE FUNCTION middleman_pub.authenticate(
  email TEXT,
  password TEXT
) RETURNS middleman_pub.jwt_token AS $$
DECLARE
  account middleman_priv.person_account;
BEGIN
  SELECT a.* INTO account
  FROM middleman_priv.person_account AS a
  WHERE a.email = $1;

  IF account.password_hash = crypt(password, account.password_hash) THEN
    RETURN ('middleman_user', account.person_id)::middleman_pub.jwt_token;
  ELSE
    RETURN NULL;
  END IF;
END;
$$ LANGUAGE plpgsql STRICT STABLE SECURITY DEFINER;

COMMENT ON FUNCTION middleman_pub.authenticate(TEXT, TEXT) IS
  'Creates a JWT token that will securely identify a person and give them certain permissions.';

CREATE FUNCTION middleman_pub.current_person() RETURNS middleman_pub.person AS $$
  SELECT *
  FROM middleman_pub.person
  WHERE id = current_setting('jwt.claims.person_id', true)::BIGINT
$$ LANGUAGE SQL STABLE;

COMMENT ON FUNCTION middleman_pub.current_person() IS
  'Gets the person who was identified by our JWT.';

-- tasks functions
CREATE FUNCTION middleman_pub.tasks(
  latitude REAL,
  longitude REAL,
  task_types middleman_pub.task_type[],
  task_status middleman_pub.task_status DEFAULT 'opened'
) RETURNS SETOF middleman_pub.task AS $$
  SELECT *
  FROM middleman_pub.task
  WHERE middleman_pub.task.status = task_status
  AND middleman_pub.task.category = ANY (task_types)
  ORDER BY middleman_pub.task.geog <-> concat('SRID=4326;POINT(', longitude, ' ', latitude, ')');
$$ LANGUAGE SQL STRICT STABLE;

COMMENT ON FUNCTION middleman_pub.tasks(REAL, REAL, middleman_pub.task_type[], middleman_pub.task_status) IS
  'Gets the nearest open tasks given longitude latitude and task type ordered by distance';

CREATE FUNCTION middleman_pub.update_task(
  task_id BIGINT,
  new_task_status middleman_pub.task_status
) RETURNS middleman_pub.task AS $$
  DECLARE
    task middleman_pub.task;
    user_id CONSTANT BIGINT NOT NULL := current_setting('jwt.claims.person_id', true);
    current_task_status CONSTANT middleman_pub.task_status NOT NULL := (SELECT current_task.status FROM middleman_pub.task AS current_task WHERE current_task.id = task_id LIMIT 1);
    current_fulfiller_id CONSTANT BIGINT := (SELECT current_task.fulfiller_id FROM middleman_pub.task AS current_task WHERE current_task.id = task_id LIMIT 1);
    current_requester_id CONSTANT BIGINT := (SELECT current_task.requestor_id FROM middleman_pub.task AS current_task WHERE current_task.id = task_id LIMIT 1);
    is_client CONSTANT BOOLEAN NOT NULL := ((SELECT current_person.is_client FROM middleman_pub.person AS current_person WHERE current_person.id = user_id LIMIT 1) = FALSE);
    current_user_type CONSTANT middleman_pub.user_type NOT NULL := (SELECT
      CASE
        WHEN (current_requester_id = user_id) THEN 'requester'
        WHEN (current_fulfiller_id = user_id) THEN 'fulfiller'
        WHEN ((SELECT COUNT(*)
              FROM middleman_pub.task AS current_task
              WHERE current_task.fulfiller_id = user_id
              AND current_task.status != 'finished'
              AND current_task.status != 'closed') = 0
                AND is_client
              ) THEN 'open fulfiller'
        ELSE 'none'
      END
    );
    can_update CONSTANT BOOLEAN := ((SELECT permission.can_update_to
          FROM middleman_pub.task_permission AS permission
            WHERE permission.current_status = current_task_status
            AND permission.user_type = current_user_type
            LIMIT 1
       ) = new_task_status
    );
  BEGIN
      IF current_task_status = 'closed' OR current_task_status = 'finished' THEN
        RAISE 'You cannot modify a closed or finished task';
      ELSEIF can_update AND (current_user_type = 'requester' OR current_user_type = 'fulfiller') THEN
        UPDATE middleman_pub.task SET status = new_task_status
        WHERE id = task_id
        RETURNING * INTO task;
      ELSEIF can_update AND (current_user_type = 'open fulfiller') THEN
        UPDATE middleman_pub.task SET (status, fulfiller_id) = (new_task_status, user_id)
        WHERE id = task_id
        RETURNING * INTO task;
      ELSE
        RAISE 'You do not have the required permission to do this update';
      END IF;
      RETURN task;
  END;
$$ LANGUAGE plpgsql STRICT SECURITY INVOKER;

COMMENT ON FUNCTION middleman_pub.update_task(BIGINT,middleman_pub.task_status) IS
  'Update task status depending on permissions';

CREATE FUNCTION middleman_pub.add_task_review(
  task_id BIGINT,
  new_rating SMALLINT
) RETURNS middleman_pub.task AS $$
  DECLARE
    task middleman_pub.task;
    user_id CONSTANT BIGINT NOT NULL := current_setting('jwt.claims.person_id', true);
    current_requester_id CONSTANT BIGINT := (SELECT current_task.requestor_id FROM middleman_pub.task AS current_task WHERE current_task.id = task_id LIMIT 1);
    current_task_status CONSTANT middleman_pub.task_status NOT NULL := (SELECT current_task.status FROM middleman_pub.task AS current_task WHERE current_task.id = task_id LIMIT 1);
    can_submit_review BOOLEAN NOT NULL := (
      (current_requester_id = user_id) AND
      (current_task_status = 'finished')
    );
  BEGIN
    IF can_submit_review THEN
      UPDATE middleman_pub.task SET rating = new_rating
      WHERE id = task_id
      RETURNING * into task;
    ELSE
      RAISE 'no permission to update';
    END IF;
    RETURN task;
  END;
$$ LANGUAGE plpgsql STRICT SECURITY INVOKER VOLATILE;

COMMENT ON FUNCTION middleman_pub.add_task_review(BIGINT,SMALLINT) IS
  'Add reviews to the task based on permissions';

-- comment functions

-- CREATE TABLE middleman_pub.reply (
--   id BIGSERIAL PRIMARY KEY,
--   commentary TEXT,
--   person_id BIGINT NOT NULL REFERENCES middleman_pub.person ON UPDATE CASCADE,
--   author_id BIGINT NOT NULL REFERENCES middleman_pub.person ON UPDATE CASCADE,
--   task_id BIGINT NOT NULL REFERENCES middleman_pub.task ON UPDATE CASCADE,
--   stars SMALLINT,
--   deleted BOOLEAN NOT NULL DEFAULT FALSE,
--   created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
--   updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
-- );

-- CREATE FUNCTION middleman_pub.register_person(
--   first_name TEXT,
--   last_name TEXT,
--   email TEXT,
--   password TEXT,
--   is_client BOOLEAN
-- ) RETURNS middleman_pub.person AS $$
-- DECLARE
--   person middleman_pub.person;
-- BEGIN
--   INSERT INTO middleman_pub.person (first_name, last_name, is_client) VALUES
--     (first_name, last_name, is_client)
--     RETURNING * INTO person;

--   INSERT INTO middleman_priv.person_account (person_id, email, password_hash) VALUES
--     (person.id, email, crypt(password, gen_salt('bf')));

--   RETURN person;
-- END;
-- $$ LANGUAGE plpgsql strict security definer;

-- CREATE FUNCTION middleman_pub.create_new_comment(
--   referring_task_id BIGINT,
--   person_stars SMALLINT DEFAULT NULL,
--   person_text TEXT DEFAULT NULL
-- ) RETURNS middleman_pub.reply AS $$
--   -- DECLARE
--   --   reply middleman_pub.reply;
--   --   current_person_id CONSTANT BIGINT NOT NULL := current_setting('jwt.claims.person_id', true);
--   --   task_person_id CONSTANT BIGINT NOT NULL := (SELECT fulfiller_id FROM middleman_pub.task WHERE id = task_id LIMIT 1);
--   --   task_status CONSTANT middleman_pub.task_status NOT NULL := (SELECT status FROM middleman_pub.task WHERE id = task_id LIMIT 1);
--   BEGIN
--     RAISE 'not allowed to comment on unfinished task';
--     -- IF task_status = 'finished' THEN

--     -- INSERT INTO middleman_pub.reply (task_id, stars, commentary, person_id, author_id)
--     --   VALUES (referring_task_id, person_stars, person_text, task_person_id, current_person_id)
--     --   RETURNING * INTO reply;

--     -- INSERT INTO middleman_pub.reply_tree (parent_id, child_id)
--     --   VALUES (reply.id, reply.id);

--     -- ELSE
--     --  RAISE 'not allowed to comment on unfinished task';
--     -- END IF;
--     -- raise notice 'current_person_id: %', current_person_id;
--     -- raise notice 'task_person_id: %', task_person_id;

--     -- IF commentary = NULL AND star = NULL THEN
--     --   RAISE 'at least one of commentary or star must have some value';
--     -- ELSEIF commentary != NULL AND star = NULL THEN
--     --   INSERT
--     --   INTO middleman_pub.reply (commentary, person_id, author_id)
--     --   VALUES (commentary, person_id, author_id)
--     --   RETURNING * INTO reply;
--     -- ELSEIF commentary = NULL AND star != NULL THEN
--     --   INSERT
--     --   INTO middleman_pub.reply (stars, person_id, author_id)
--     --   VALUES (star, person_id, author_id)
--     --   RETURNING * INTO reply;
--     -- ELSEIF commentary != NULL AND star != NULL THEN
--     --   INSERT
--     --   INTO middleman_pub.reply (stars, commentary, person_id, author_id)
--     --   VALUES (star, commentary, person_id, author_id)
--     --   RETURNING * INTO reply;
--     -- ELSE
--     --   RAISE 'error adding comment';
--     -- END IF;
--     RETURN reply;

--   END;
-- $$ LANGUAGE plpgsql STRICT;

-- COMMENT ON FUNCTION middleman_pub.create_new_comment(
--   BIGINT,
--   SMALLINT,
--   TEXT
-- ) IS 'create a comment based on current person and permissions';

-- CREATE FUNCTION middleman_pub.comment_child(
--   id BIGINT
-- ) RETURNS SETOF middleman_pub.reply AS $$
--     SELECT c.*
--     FROM middleman_pub.reply AS c
--       JOIN middleman_pub.reply_tree AS t ON c.id = t.child_id
--     WHERE t.parent_id = id;
-- $$ LANGUAGE sql STRICT STABLE;

-- COMMENT ON FUNCTION middleman_pub.comment_child(BIGINT) IS
--   'get the childs of comment by comment id';

-- CREATE FUNCTION middleman_pub.comment_parent(
--   id BIGINT
-- ) RETURNS SETOF middleman_pub.reply AS $$
--   SELECT c.*
--   FROM middleman_pub.reply AS c
--     JOIN middleman_pub.reply_tree AS t ON c.id = t.parent_id
--   WHERE t.child_id = id;
-- $$ LANGUAGE sql STRICT STABLE;

-- COMMENT ON FUNCTION middleman_pub.comment_parent(BIGINT) IS
--   'get the parents of comment by comment id';

-- CREATE FUNCTION middleman_pub.reply_with_comment(
--   parent_id BIGINT,
--   commentary TEXT
-- ) RETURNS void AS $$
--   DECLARE
--   author_id CONSTANT BIGINT := (SELECT id FROM current_person());
--   person_id CONSTANT BIGINT := (SELECT person_id FROM middleman_pub.reply WHERE id = parent_id);
--   task_id CONSTANT BIGINT := (SELECT task_id FROM middleman_pub.reply WHERE id = parent_id);
--   comment_id BIGINT;
--   BEGIN
--     WITH comment_id AS (
--       INSERT INTO middleman_pub.reply (commentary, author_id, person_id, task_id)
--       VALUES (commentary, author_id, person_id, task_id) RETURNING id
--     )
--     INSERT INTO middleman_pub.reply_tree (parent_id, child_id) (
--       SELECT t.parent_id, comment_id
--       FROM middleman_pub.reply_tree AS t
--       WHERE t.child_id = parent_id
--       UNION ALL (SELECT comment_id, comment_id)
--     );
--   END;
-- $$ LANGUAGE plpgsql STRICT SECURITY INVOKER VOLATILE;

-- COMMENT ON FUNCTION middleman_pub.reply_with_comment(BIGINT, TEXT) IS
--   'reply comment given parent comment id';

-- CREATE FUNCTION middleman_pub.remove_comment(
--   comment_id BIGINT
-- ) RETURNS middleman_pub.reply AS $$
--   BEGIN
--     UPDATE middleman_pub.reply
--     SET deleted = true
--     WHERE id = comment_id
--     RETURNING *;
--   END;
-- $$ LANGUAGE plpgsql STRICT SECURITY INVOKER VOLATILE;

-- COMMENT ON FUNCTION middleman_pub.remove_comment(BIGINT) IS
--   'delete comment by id';

-- permissions
GRANT EXECUTE ON FUNCTION middleman_pub.tasks(REAL, REAL, middleman_pub.task_type[], middleman_pub.task_status) TO middleman_user;
GRANT EXECUTE ON FUNCTION middleman_pub.update_task(BIGINT,middleman_pub.task_status) TO middleman_user;
GRANT EXECUTE ON FUNCTION middleman_pub.add_task_review(BIGINT,SMALLINT) TO middleman_user;
-- GRANT EXECUTE ON FUNCTION middleman_pub.create_new_comment(BIGINT, SMALLINT, TEXT) TO middleman_user;
-- GRANT EXECUTE ON FUNCTION middleman_pub.comment_parent(BIGINT) TO middleman_user, middleman_visitor;
-- GRANT EXECUTE ON FUNCTION middleman_pub.comment_child(BIGINT) TO middleman_user, middleman_visitor;
-- GRANT EXECUTE ON FUNCTION middleman_pub.remove_comment(BIGINT) TO middleman_user;
-- GRANT EXECUTE ON FUNCTION middleman_pub.reply_with_comment(BIGINT, TEXT) TO middleman_user;
GRANT EXECUTE ON FUNCTION middleman_pub.authenticate(TEXT, TEXT) TO middleman_visitor, middleman_user;
GRANT EXECUTE ON FUNCTION middleman_pub.current_person() TO middleman_visitor, middleman_user;
GRANT EXECUTE ON FUNCTION middleman_pub.register_person(TEXT, TEXT, TEXT, TEXT, BOOLEAN) TO middleman_visitor;

-- GRANT USAGE ON SEQUENCE middleman_pub.reply_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE middleman_pub.person_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE middleman_pub.phone_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE middleman_pub.photo_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE middleman_pub.task_id_seq TO middleman_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.person TO middleman_admin;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.reply TO middleman_admin;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.reply_tree TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.phone TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.photo TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.task TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.task_detail TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.person_photo TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.person_type TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.task_photo TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.task_permission TO middleman_admin;

GRANT SELECT ON TABLE middleman_pub.person TO middleman_visitor, middleman_user;
-- GRANT SELECT ON TABLE middleman_pub.reply TO middleman_user, middleman_visitor;
-- GRANT SELECT ON TABLE middleman_pub.reply_tree TO middleman_user, middleman_visitor;
GRANT SELECT ON TABLE middleman_pub.phone TO middleman_user;
GRANT SELECT ON TABLE middleman_pub.photo TO middleman_user;
GRANT SELECT ON TABLE middleman_pub.task TO middleman_user;
GRANT SELECT ON TABLE middleman_pub.task_detail TO middleman_user;
GRANT SELECT ON TABLE middleman_pub.person_photo TO middleman_user;
GRANT SELECT ON TABLE middleman_pub.person_type TO middleman_user;
GRANT SELECT ON TABLE middleman_pub.task_photo TO middleman_user;
GRANT SELECT ON TABLE middleman_pub.task_permission TO middleman_user;

GRANT UPDATE, DELETE ON TABLE middleman_pub.person TO middleman_user;
-- GRANT INSERT, UPDATE ON TABLE middleman_pub.reply TO middleman_user;
-- GRANT INSERT, UPDATE ON TABLE middleman_pub.reply_tree TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.phone TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.photo TO middleman_user;
GRANT INSERT ON TABLE middleman_pub.task TO middleman_user;
GRANT UPDATE (status, fulfiller_id, longitude, latitude, scheduled_for, rating, geog, updated_at) ON TABLE middleman_pub.task TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.task_detail TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.person_photo TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.person_type TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.task_photo TO middleman_user;

-- -- comment permission
-- ALTER TABLE middleman_pub.reply ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY select_comment ON middleman_pub.reply FOR SELECT TO middleman_user, middleman_visitor
--   USING (true);
-- CREATE POLICY insert_comment ON middleman_pub.reply FOR INSERT TO middleman_user
--   -- WITH CHECK (
--   --   (person_id = current_setting('jwt.claims.person_id', true)::BIGINT) AND
--   --   ((SELECT status FROM middleman_pub.task WHERE id = task_id) = 'finished')
--   -- );
--   WITH CHECK (TRUE);
-- CREATE POLICY update_comment ON middleman_pub.reply FOR UPDATE TO middleman_user
--   -- USING (person_id = current_setting('jwt.claims.person_id', true)::BIGINT);
--   USING (TRUE);
-- CREATE POLICY delete_comment ON middleman_pub.reply FOR DELETE TO middleman_user
--   -- USING (person_id = current_setting('jwt.claims.person_id', true)::BIGINT);
--   USING (TRUE);

-- person permission
ALTER TABLE middleman_pub.person ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_person ON middleman_pub.person FOR SELECT TO middleman_user, middleman_visitor
  USING (true);
CREATE POLICY update_person ON middleman_pub.person FOR UPDATE TO middleman_user
  USING (id = current_setting('jwt.claims.person_id', true)::BIGINT);
CREATE POLICY delete_person ON middleman_pub.person FOR DELETE TO middleman_user
  USING (id = current_setting('jwt.claims.person_id', true)::BIGINT);

-- task permissions
ALTER TABLE middleman_pub.task ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_task ON middleman_pub.task FOR SELECT TO middleman_user, middleman_visitor
  USING (true);
CREATE POLICY insert_task ON middleman_pub.task FOR INSERT TO middleman_user
  WITH CHECK ((SELECT is_client FROM middleman_pub.person WHERE id = current_setting('jwt.claims.person_id', true)::BIGINT) = TRUE);
CREATE POLICY update_task ON middleman_pub.task FOR UPDATE TO middleman_user
  USING (
    requestor_id = current_setting('jwt.claims.person_id', true)::BIGINT OR
    fulfiller_id = current_setting('jwt.claims.person_id', true)::BIGINT OR
    (SELECT
      (SELECT COUNT(*) FROM middleman_pub.task AS t
              WHERE t.fulfiller_id = current_setting('jwt.claims.person_id', true)::BIGINT
                AND t.status != 'finished'
      ) = 0
      AND (SELECT (SELECT current_person.is_client FROM middleman_pub.person AS current_person WHERE current_person.id = current_setting('jwt.claims.person_id', true)::BIGINT) = FALSE)
    )
  );

CREATE POLICY delete_task ON middleman_pub.task FOR DELETE TO middleman_user
  USING (false);


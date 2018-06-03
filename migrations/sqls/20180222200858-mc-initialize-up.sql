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
  E'@omit all';

CREATE TABLE middleman_pub.person (
  id BIGSERIAL PRIMARY KEY,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  phone_id BIGINT REFERENCES middleman_pub.phone ON UPDATE CASCADE,
  longitude FLOAT NOT NULL DEFAULT 0,
  latitude FLOAT NOT NULL DEFAULT 0,
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
  E'@omit all';

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
  E'@omit all';

CREATE TABLE middleman_pub.comment (
  id BIGSERIAL PRIMARY KEY,
  commentary TEXT,
  person_id BIGINT NOT NULL REFERENCES middleman_pub.person ON UPDATE CASCADE,
  stars SMALLINT,
  deleted BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON middleman_pub.comment (person_id);

CREATE TRIGGER comment_updated_at BEFORE UPDATE
  ON middleman_pub.comment
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_updated_at_column();

COMMENT ON TABLE middleman_pub.comment IS
  E'@omit all';

CREATE TABLE middleman_pub.comment_tree (
  parent_id BIGINT NOT NULL REFERENCES middleman_pub.comment ON UPDATE CASCADE,
  child_id BIGINT NOT NULL REFERENCES middleman_pub.comment ON UPDATE CASCADE,
  person_id BIGINT NOT NULL REFERENCES middleman_pub.person ON UPDATE CASCADE,
  depth SMALLINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON middleman_pub.comment_tree (person_id);

CREATE TRIGGER comment_tree_updated_at BEFORE UPDATE
  ON middleman_pub.comment_tree
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_updated_at_column();

COMMENT ON TABLE middleman_pub.comment_tree IS
  E'@omit all';

ALTER TABLE middleman_pub.comment_tree ADD CONSTRAINT comment_tree_pkey PRIMARY KEY (parent_id, child_id);

CREATE TYPE middleman_pub.task_mode AS ENUM (
  'scheduled',
  'closed',
  'finished',
  'opened'
);

CREATE TYPE middleman_pub.task_type AS ENUM (
  'car wash',
  'car detail',
  'car oil change',
  'car headlights',
  'car tire replacement',
  'car windshield wiper',
  'car air filter change',
  'photoshop',
  'home plumming',
  'home pest control',
  'home appliance fixing',
  'home water softening',
  'home water filter',
  'home cleaning',
  'elder bathing',
  'elder cooking',
  'elder shopping',
  'maid',
  'medical tourism',
  'storage pickup'
);

CREATE TABLE middleman_pub.task (
  id BIGSERIAL PRIMARY KEY,
  requestor_id BIGINT NOT NULL REFERENCES middleman_pub.person ON UPDATE CASCADE,
  fulfiller_id BIGINT REFERENCES middleman_pub.person ON UPDATE CASCADE,
  longitude FLOAT NOT NULL,
  latitude FLOAT NOT NULL,
  scheduled_for TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  geog GEOMETRY,
  category middleman_pub.task_type NOT NULL,
  mode middleman_pub.task_mode NOT NULL DEFAULT 'opened',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON middleman_pub.task USING GIST (geog);
CREATE INDEX ON middleman_pub.task (mode);
CREATE INDEX ON middleman_pub.task (category);

CREATE TRIGGER task_updated_at BEFORE UPDATE
  ON middleman_pub.task
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_updated_at_column();

CREATE TRIGGER task_set_geog_column BEFORE INSERT OR UPDATE
  ON middleman_pub.task
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_geog_column();

COMMENT ON TABLE middleman_pub.task IS
  E'@omit all';

CREATE TABLE middleman_pub.task_attribute (
  id SERIAL PRIMARY KEY,
  attribute TEXT NOT NULL UNIQUE
);

CREATE TABLE middleman_pub.task_detail (
  task_id BIGINT NOT NULL REFERENCES middleman_pub.task ON UPDATE CASCADE,
  attribute_id INT NOT NULL UNIQUE REFERENCES middleman_pub.task_attribute ON UPDATE CASCADE,
  detail TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER task_detail_updated_at BEFORE UPDATE
  ON middleman_pub.task_detail
  FOR EACH ROW EXECUTE PROCEDURE middleman_pub.set_updated_at_column();

CREATE UNIQUE INDEX ON middleman_pub.task_detail (task_id, attribute_id);

COMMENT ON TABLE middleman_pub.task_detail IS
  E'@omit all';

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
  E'@omit all';

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
  E'@omit all';

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
  E'@omit all';

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

CREATE FUNCTION middleman_pub.register_person(
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  password TEXT
) RETURNS middleman_pub.person AS $$
declare
  person middleman_pub.person;
BEGIN
  INSERT INTO middleman_pub.person (first_name, last_name) VALUES
    (first_name, last_name)
    RETURNING * INTO person;

  INSERT INTO middleman_priv.person_account (person_id, email, password_hash) VALUES
    (person.id, email, crypt(password, gen_salt('bf')));

  RETURN person;
END;
$$ LANGUAGE plpgsql strict security definer;

COMMENT ON FUNCTION middleman_pub.register_person(TEXT, TEXT, TEXT, TEXT) IS
  'Registers a single person and creates an account in our forum.';

CREATE ROLE middleman_admin LOGIN PASSWORD 'voodoo3d';
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
declare
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
$$ LANGUAGE plpgsql strict security definer;

COMMENT ON FUNCTION middleman_pub.authenticate(TEXT, TEXT) IS
  'Creates a JWT token that will securely identify a person and give them certain permissions.';

CREATE FUNCTION middleman_pub.current_person() RETURNS middleman_pub.person AS $$
  SELECT *
  FROM middleman_pub.person
  WHERE id = current_setting('jwt.claims.person_id')::BIGINT
$$ LANGUAGE sql stable;

COMMENT ON FUNCTION middleman_pub.current_person() IS
  'Gets the person who was identified by our JWT.';

CREATE FUNCTION middleman_pub.tasks(
  latitude REAL,
  longitude REAL,
  task_types middleman_pub.task_type[],
  task_status middleman_pub.task_mode default 'opened'
) RETURNS SETOF middleman_pub.task as $$
  SELECT *
  FROM middleman_pub.task
  WHERE middleman_pub.task.mode = task_status
  AND middleman_pub.task.category = ANY (task_types)
  ORDER BY middleman_pub.task.geog <-> concat('SRID=4326;POINT(', longitude, ' ', latitude, ')')::GEOMETRY
  LIMIT 100;
$$ LANGUAGE sql stable;

COMMENT ON FUNCTION middleman_pub.tasks(REAL, REAL, middleman_pub.task_type[], middleman_pub.task_mode) IS
  'Gets the 50 nearest open tasks given longitude latitude and task type';

CREATE FUNCTION middleman_pub.comment_child(
  id BIGINT
) RETURNS SETOF middleman_pub.comment as $$
    SELECT c.*
    FROM middleman_pub.comment AS c
      JOIN middleman_pub.comment_tree AS t ON c.id = t.child_id
    WHERE t.parent_id = id;
$$ LANGUAGE sql stable;

COMMENT ON FUNCTION middleman_pub.comment_child(BIGINT) IS
  'get the childs of comment by id';

CREATE FUNCTION middleman_pub.comment_parent(
  id BIGINT
) RETURNS SETOF middleman_pub.comment as $$
  SELECT c.*
  FROM middleman_pub.comment AS c
    JOIN middleman_pub.comment_tree AS t ON c.id = t.parent_id
  WHERE t.child_id = id;
$$ LANGUAGE sql stable;

COMMENT ON FUNCTION middleman_pub.comment_parent(BIGINT) IS
  'get the parents of comment by id';

CREATE FUNCTION middleman_pub.reply_with_comment(
  parent_id BIGINT,
  commentary TEXT,
  stars SMALLINT
) RETURNS void as $$
  DECLARE
  author_id CONSTANT BIGINT := (SELECT id FROM current_person());
  BEGIN
  WITH comment_id AS (
    INSERT INTO middleman_pub.comment (commentary, person_id, stars)
    VALUES (commentary, author_id, stars) RETURNING id
  ) INSERT INTO middleman_pub.comment_tree (parent_id, comment_id, person_id) (
    SELECT t.parent_id, comment_id, person_id
    FROM middleman_pub.comment_tree AS t
    WHERE t.child_id = parent_id
    UNION ALL
      (SELECT comment_id, comment_id, author_id)
  );
  END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION middleman_pub.reply_with_comment(BIGINT, TEXT, SMALLINT) IS
  'reply comment given parent comment id';

CREATE FUNCTION middleman_pub.remove_comment(
  comment_id BIGINT
) RETURNS middleman_pub.comment AS $$
  BEGIN
    UPDATE middleman_pub.comment
    SET deleted = true
    WHERE id = comment_id;
    -- RETURNS *;
  END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION middleman_pub.remove_comment(BIGINT) IS
  'delete comment by id';

GRANT EXECUTE ON FUNCTION middleman_pub.tasks(REAL, REAL, middleman_pub.task_type[], middleman_pub.task_mode) TO middleman_user;
GRANT EXECUTE ON FUNCTION middleman_pub.comment_parent(BIGINT) TO middleman_user, middleman_visitor;
GRANT EXECUTE ON FUNCTION middleman_pub.comment_child(BIGINT) TO middleman_user, middleman_visitor;
GRANT EXECUTE ON FUNCTION middleman_pub.remove_comment(BIGINT) TO middleman_user;
GRANT EXECUTE ON FUNCTION middleman_pub.reply_with_comment(BIGINT, TEXT, SMALLINT) TO middleman_user;
GRANT EXECUTE ON FUNCTION middleman_pub.tasks(REAL, REAL, middleman_pub.task_type[], middleman_pub.task_mode) TO middleman_user;
GRANT EXECUTE ON FUNCTION middleman_pub.authenticate(TEXT, TEXT) TO middleman_visitor, middleman_user;
GRANT EXECUTE ON FUNCTION middleman_pub.current_person() TO middleman_visitor, middleman_user;
GRANT EXECUTE ON FUNCTION middleman_pub.register_person(TEXT, TEXT, TEXT, TEXT) TO middleman_visitor;

GRANT USAGE ON SEQUENCE middleman_pub.comment_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE middleman_pub.person_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE middleman_pub.phone_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE middleman_pub.photo_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE middleman_pub.task_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE middleman_pub.task_attribute_id_seq TO middleman_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.person TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.comment TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.phone TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.photo TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.task TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.task_attribute TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.task_detail TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.comment_tree TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.person_photo TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.person_type TO middleman_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE middleman_pub.task_photo TO middleman_admin;

GRANT SELECT ON TABLE middleman_pub.person TO middleman_visitor, middleman_user;
GRANT SELECT ON TABLE middleman_pub.comment TO middleman_user, middleman_visitor;
GRANT SELECT ON TABLE middleman_pub.comment_tree TO middleman_user, middleman_visitor;
GRANT SELECT ON TABLE middleman_pub.phone TO middleman_user;
GRANT SELECT ON TABLE middleman_pub.photo TO middleman_user;
GRANT SELECT ON TABLE middleman_pub.task TO middleman_user;
GRANT SELECT ON TABLE middleman_pub.task_attribute TO middleman_user;
GRANT SELECT ON TABLE middleman_pub.task_detail TO middleman_user;
GRANT SELECT ON TABLE middleman_pub.person_photo TO middleman_user;
GRANT SELECT ON TABLE middleman_pub.person_type TO middleman_user;
GRANT SELECT ON TABLE middleman_pub.task_photo TO middleman_user;

GRANT UPDATE, DELETE ON TABLE middleman_pub.person TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.comment TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.phone TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.photo TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.comment_tree TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.task TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.task_attribute TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.task_detail TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.person_photo TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.person_type TO middleman_user;
GRANT INSERT, UPDATE ON TABLE middleman_pub.task_photo TO middleman_user;

ALTER TABLE middleman_pub.comment ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_comment ON middleman_pub.comment FOR SELECT TO middleman_user, middleman_visitor
  USING (true);
CREATE POLICY insert_comment ON middleman_pub.comment FOR INSERT TO middleman_user
  WITH CHECK (person_id = current_setting('jwt.claims.person_id')::INTEGER);
CREATE POLICY update_comment ON middleman_pub.comment FOR UPDATE TO middleman_user
  USING (person_id = current_setting('jwt.claims.person_id')::INTEGER);
CREATE POLICY delete_comment ON middleman_pub.comment FOR DELETE TO middleman_user
  USING (person_id = current_setting('jwt.claims.person_id')::INTEGER);

ALTER TABLE middleman_pub.comment_tree ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_comment_tree ON middleman_pub.comment_tree FOR SELECT TO middleman_user, middleman_visitor
  USING (true);
CREATE POLICY insert_comment_tree ON middleman_pub.comment_tree FOR INSERT TO middleman_user
  WITH CHECK (person_id = current_setting('jwt.claims.person_id')::INTEGER);
CREATE POLICY update_comment_tree ON middleman_pub.comment_tree FOR UPDATE TO middleman_user
  USING (person_id = current_setting('jwt.claims.person_id')::INTEGER);
CREATE POLICY delete_comment_tree ON middleman_pub.comment_tree FOR DELETE TO middleman_user
  USING (person_id = current_setting('jwt.claims.person_id')::INTEGER);

ALTER TABLE middleman_pub.person ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_person ON middleman_pub.person FOR SELECT TO middleman_user, middleman_visitor
  USING (true);
CREATE POLICY update_person ON middleman_pub.person FOR UPDATE TO middleman_user
  USING (id = current_setting('jwt.claims.person_id')::INTEGER);
CREATE POLICY delete_person ON middleman_pub.person FOR delete TO middleman_user
  USING (id = current_setting('jwt.claims.person_id')::INTEGER);

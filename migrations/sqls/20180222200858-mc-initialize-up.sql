CREATE SCHEMA m_priv;
CREATE SCHEMA m_pub;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM public;

CREATE FUNCTION m_pub.set_updated_at() RETURNS TRIGGER AS $$
BEGIN
  new.updated_at := current_timestamp;
  RETURN new;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE m_pub.phone (
  id BIGSERIAL PRIMARY KEY,
  country_code TEXT NOT NULL,
  phone TEXT NOT NULL,
  ext TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER phone_updated_at BEFORE UPDATE
  ON m_pub.phone
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.phone IS E'@omit all';

ALTER TABLE m_pub.phone ADD CONSTRAINT phone_number UNIQUE (country_code, phone, ext);

CREATE TABLE m_pub.person (
  id BIGSERIAL PRIMARY KEY,
  first_name TEXT,
  last_name TEXT,
  phone_id BIGINT REFERENCES m_pub.phone ON UPDATE CASCADE,
  geog geography,
  is_client BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON m_pub.person USING GIST (geog);
CREATE INDEX ON m_pub.person (is_client) WHERE is_client = FALSE;

CREATE TRIGGER person_updated_at BEFORE UPDATE
  ON m_pub.person
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.person IS E'@omit all';

CREATE TABLE m_pub.photo (
  id BIGSERIAL PRIMARY KEY,
  url TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER photo_updated_at BEFORE UPDATE
  ON m_pub.photo
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.photo IS E'@omit all';

CREATE TABLE m_pub.comment (
  id BIGSERIAL PRIMARY KEY,
  commentary TEXT,
  person_id BIGINT NOT NULL REFERENCES m_pub.person ON UPDATE CASCADE,
  stars SMALLINT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON m_pub.comment (person_id);

CREATE TRIGGER comment_updated_at BEFORE UPDATE
  ON m_pub.comment
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.comment IS E'@omit all';

CREATE TABLE m_pub.comment_tree (
  parent_id BIGINT NOT NULL REFERENCES m_pub.comment ON UPDATE CASCADE,
  child_id BIGINT NOT NULL REFERENCES m_pub.comment ON UPDATE CASCADE,
  depth SMALLINT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER comment_tree_updated_at BEFORE UPDATE
  ON m_pub.comment_tree
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.comment_tree IS E'@omit all';

ALTER TABLE m_pub.comment_tree ADD CONSTRAINT comment_tree_pkey PRIMARY KEY (parent_id, child_id);

CREATE TYPE m_pub.job_mode AS ENUM (
  'filled',
  'closed',
  'finished',
  'opened'
);

CREATE TYPE m_pub.job_type AS ENUM (
  'car wash',
  'elder house cleaning',
  'elder cooking',
  'elder shopping',
  'medical tourism',
  'storage'
);

CREATE TABLE m_pub.job (
  id BIGSERIAL PRIMARY KEY,
  requestor_id BIGINT REFERENCES m_pub.person ON UPDATE CASCADE,
  fulfiller_id BIGINT REFERENCES m_pub.person ON UPDATE CASCADE,
  geog geography NOT NULL,
  category m_pub.job_type NOT NULL,
  mode m_pub.job_mode NOT NULL DEFAULT 'opened',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON m_pub.job USING GIST (geog);
CREATE INDEX ON m_pub.job (mode);
CREATE INDEX ON m_pub.job (category);

CREATE TRIGGER job_updated_at BEFORE UPDATE
  ON m_pub.job
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.job IS E'@omit all';

CREATE TABLE m_pub.person_comment (
  person_id BIGINT REFERENCES m_pub.person ON UPDATE CASCADE,
  comment_id BIGINT REFERENCES m_pub.comment ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON m_pub.person_comment (person_id);

CREATE TRIGGER person_comment_updated_at BEFORE UPDATE
  ON m_pub.person_comment
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.person_comment IS E'@omit all';

CREATE TABLE m_pub.person_photo (
  person_id BIGINT REFERENCES m_pub.person ON UPDATE CASCADE,
  photo_id BIGINT REFERENCES m_pub.photo ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON m_pub.person_photo (person_id);

CREATE TRIGGER person_photo_updated_at BEFORE UPDATE
  ON m_pub.person_photo
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.person_photo IS E'@omit all';

CREATE TABLE m_pub.job_photo (
  job_id BIGINT REFERENCES m_pub.job ON UPDATE CASCADE,
  photo_id BIGINT REFERENCES m_pub.photo ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON m_pub.job_photo (job_id);

CREATE TRIGGER job_photo_updated_at BEFORE UPDATE
  ON m_pub.job_photo
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.job_photo IS E'@omit all';

CREATE TABLE m_priv.person_account (
  person_id        BIGINT PRIMARY KEY REFERENCES m_pub.person ON UPDATE CASCADE,
  email            TEXT NOT NULL UNIQUE CHECK (email ~* '^.+@.+\..+$'),
  password_hash    TEXT NOT NULL
);

COMMENT ON TABLE m_priv.person_account IS 'Private information about a person’s account.';
COMMENT ON COLUMN m_priv.person_account.person_id IS 'The id of the person associated with this account.';
COMMENT ON COLUMN m_priv.person_account.email IS 'The email address of the person.';
COMMENT ON COLUMN m_priv.person_account.password_hash IS 'An opaque hash of the person’s password.';

CREATE FUNCTION m_pub.register_person(
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  password TEXT
) RETURNS m_pub.person AS $$
declare
  person m_pub.person;
BEGIN
  INSERT INTO m_pub.person (first_name, last_name) VALUES
    (first_name, last_name)
    RETURNING * INTO person;

  INSERT INTO m_priv.person_account (person_id, email, password_hash) VALUES
    (person.id, email, crypt(password, gen_salt('bf')));

  RETURN person;
END;
$$ LANGUAGE plpgsql strict security definer;

COMMENT ON FUNCTION m_pub.register_person(TEXT, TEXT, TEXT, TEXT) IS 'Registers a single person and creates an account in our forum.';

CREATE ROLE sys_admin LOGIN PASSWORD 'voodoo3d';
CREATE ROLE middleman_visitor;
GRANT middleman_visitor TO sys_admin;
CREATE ROLE middleman_user;
GRANT middleman_user TO sys_admin;

CREATE TYPE m_pub.jwt_token AS (
  role TEXT,
  person_id BIGINT
);

CREATE FUNCTION m_pub.authenticate(
  email TEXT,
  password TEXT
) RETURNS m_pub.jwt_token AS $$
declare
  account m_priv.person_account;
BEGIN
  SELECT a.* INTO account
  FROM m_priv.person_account AS a
  WHERE a.email = $1;

  IF account.password_hash = crypt(password, account.password_hash) THEN
    RETURN ('middleman_user', account.person_id)::m_pub.jwt_token;
  ELSE
    RETURN NULL;
  END IF;
END;
$$ LANGUAGE plpgsql strict security definer;

COMMENT ON FUNCTION m_pub.authenticate(TEXT, TEXT) IS 'Creates a JWT token that will securely identify a person and give them certain permissions.';

CREATE FUNCTION m_pub.current_person() RETURNS m_pub.person AS $$
  SELECT *
  FROM m_pub.person
  WHERE id = current_setting('jwt.claims.person_id')::BIGINT
$$ LANGUAGE sql stable;

COMMENT ON FUNCTION m_pub.current_person() IS 'Gets the person who was identified by our JWT.';

CREATE FUNCTION m_pub.open_jobs(
  lat REAL,
  long REAL,
  job_type m_pub.job_type
) RETURNS m_pub.job as $$
  SELECT *
  FROM m_pub.job
  WHERE m_pub.job.mode = 'opened'
  AND m_pub.job.category = job_type
  ORDER BY m_pub.job.geog <-> concat('SRID=26918;POINT(', long, ' ', lat, ')')::geometry
  LIMIT 50;
$$ LANGUAGE sql stable;

COMMENT ON FUNCTION m_pub.open_jobs(REAL, REAL, m_pub.job_type) IS 'Gets the 50 nearest open jobs given long lat and job type';

GRANT EXECUTE ON FUNCTION m_pub.open_jobs(REAL, REAL, m_pub.job_type) TO middleman_user;
GRANT EXECUTE ON FUNCTION m_pub.authenticate(TEXT, TEXT) TO middleman_visitor, middleman_user;
GRANT EXECUTE ON FUNCTION m_pub.current_person() TO middleman_visitor, middleman_user;
GRANT EXECUTE ON FUNCTION m_pub.register_person(TEXT, TEXT, TEXT, TEXT) TO middleman_visitor;
GRANT USAGE ON SCHEMA m_pub TO middleman_visitor, middleman_user, sys_admin;
GRANT SELECT ON TABLE m_pub.person TO middleman_visitor, middleman_user;
GRANT UPDATE, DELETE ON TABLE m_pub.person TO middleman_user;
ALTER TABLE m_pub.person ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_person ON m_pub.person FOR SELECT TO middleman_user, middleman_visitor
  USING (true);
CREATE POLICY update_person ON m_pub.person FOR UPDATE TO middleman_user
  USING (id = current_setting('jwt.claims.person_id')::INTEGER);
CREATE POLICY delete_person ON m_pub.person FOR delete TO middleman_user
  USING (id = current_setting('jwt.claims.person_id')::INTEGER);

GRANT USAGE ON SEQUENCE m_pub.comment_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE m_pub.person_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE m_pub.phone_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE m_pub.photo_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE m_pub.job_id_seq TO middleman_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.comment TO sys_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.phone TO sys_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.photo TO sys_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.job TO sys_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.comment_tree TO sys_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.person_comment TO sys_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.person_photo TO sys_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.job_photo TO sys_admin;

GRANT SELECT ON TABLE m_pub.comment TO middleman_user, middleman_visitor;
GRANT SELECT ON TABLE m_pub.phone TO middleman_user, middleman_visitor;
GRANT SELECT ON TABLE m_pub.photo TO middleman_user, middleman_visitor;
GRANT SELECT ON TABLE m_pub.comment_tree TO middleman_user, middleman_visitor;
GRANT SELECT ON TABLE m_pub.job TO middleman_user;
GRANT SELECT ON TABLE m_pub.person_comment TO middleman_user, middleman_visitor;
GRANT SELECT ON TABLE m_pub.person_photo TO middleman_user;
GRANT SELECT ON TABLE m_pub.job_photo TO middleman_user;

GRANT INSERT, UPDATE ON TABLE m_pub.comment TO middleman_user;
GRANT INSERT, UPDATE ON TABLE m_pub.phone TO middleman_user;
GRANT INSERT, UPDATE ON TABLE m_pub.photo TO middleman_user;
GRANT INSERT, UPDATE ON TABLE m_pub.comment_tree TO middleman_user;
GRANT INSERT, UPDATE ON TABLE m_pub.job TO middleman_user;
GRANT INSERT, UPDATE ON TABLE m_pub.person_comment TO middleman_user;
GRANT INSERT, UPDATE ON TABLE m_pub.person_photo TO middleman_user;
GRANT INSERT, UPDATE ON TABLE m_pub.job_photo TO middleman_user;

ALTER TABLE m_pub.comment ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_COMMENT ON m_pub.comment FOR SELECT TO middleman_user, middleman_visitor
  USING (true);

CREATE POLICY insert_COMMENT ON m_pub.comment FOR INSERT TO middleman_user
  WITH CHECK (person_id = current_setting('jwt.claims.person_id')::INTEGER);

CREATE POLICY update_COMMENT ON m_pub.comment FOR UPDATE TO middleman_user
  USING (person_id = current_setting('jwt.claims.person_id')::INTEGER);

CREATE POLICY delete_COMMENT ON m_pub.comment FOR DELETE TO middleman_user
  USING (person_id = current_setting('jwt.claims.person_id')::INTEGER);

-- CREATE EXTENSION IF NOT EXISTS postgis;
CREATE schema m_priv;
CREATE schema m_pub;
CREATE EXTENSION IF NOT EXISTS postgis;
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM public;

CREATE FUNCTION m_pub.set_updated_at() RETURNS TRIGGER AS $$
begin
  new.updated_at := current_timestamp;
  return new;
end;
$$ language plpgsql;

CREATE TABLE m_pub.phone (
  id BIGSERIAL PRIMARY KEY,
  country_code SMALLINT NOT NULL,
  area_code SMALLINT NOT NULL,
  phone integer NOT NULL,
  ext integer,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER phone_updated_at BEFORE UPDATE
  ON m_pub.phone
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.phone IS E'@omit all';

ALTER TABLE m_pub.phone ADD CONSTRAINT phone_number UNIQUE (country_code, area_code, phone, ext);

CREATE TABLE m_pub.person (
  id BIGSERIAL PRIMARY KEY,
  first_name TEXT,
  last_name TEXT,
  phone_id BIGINT REFERENCES m_pub.phone(id) ON UPDATE CASCADE,
  geog geography,
  is_client BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON m_pub.person USING GIST (geog);

CREATE TRIGGER person_updated_at BEFORE UPDATE
  ON m_pub.person
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.person IS E'@omit all';

CREATE TABLE m_pub.tag (
  id BIGSERIAL PRIMARY KEY,
  tag TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER tag_updated_at BEFORE UPDATE
  ON m_pub.tag
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.tag IS E'@omit all';

CREATE TABLE m_pub.url (
  id BIGSERIAL PRIMARY KEY,
  url TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER url_updated_at BEFORE UPDATE
  ON m_pub.url
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.url IS E'@omit all';

CREATE TABLE m_pub.photo (
  id BIGSERIAL PRIMARY KEY,
  url_id BIGINT NOT NULL REFERENCES m_pub.url(id) ON UPDATE CASCADE,
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
  person_id BIGINT NOT NULL REFERENCES m_pub.person(id) ON UPDATE CASCADE,
  stars SMALLINT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX on m_pub.comment (person_id);

CREATE TRIGGER comment_updated_at BEFORE UPDATE
  ON m_pub.comment
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.comment IS E'@omit all';

CREATE TABLE m_pub.comment_tree (
  parent_id BIGINT NOT NULL REFERENCES m_pub.comment(id) ON UPDATE CASCADE,
  child_id BIGINT NOT NULL REFERENCES m_pub.comment(id) ON UPDATE CASCADE,
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

CREATE TABLE m_pub.person_comment (
  person_id BIGINT REFERENCES m_pub.person(id) ON UPDATE CASCADE,
  comment_id BIGINT REFERENCES m_pub.comment(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER person_comment_updated_at BEFORE UPDATE
  ON m_pub.person
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.person_comment IS E'@omit all';

CREATE TABLE m_pub.person_tag (
  person_id BIGINT REFERENCES m_pub.person(id) ON UPDATE CASCADE,
  tag_id BIGINT REFERENCES m_pub.tag(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER person_tag_updated_at BEFORE UPDATE
  ON m_pub.person
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

CREATE INDEX ON m_pub.person_tag (person_id);

COMMENT ON TABLE m_pub.person_tag IS E'@omit all';

CREATE TYPE m_pub.mode AS ENUM (
  'filled',
  'closed',
  'finished',
  'opened'
);

CREATE TABLE m_pub.job (
  id BIGSERIAL PRIMARY KEY,
  person_id BIGINT REFERENCES m_pub.person(id) ON UPDATE CASCADE,
  geog geography NOT NULL,
  mode m_pub.mode,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON m_pub.job USING GIST (geog);
CREATE INDEX ON m_pub.job (mode);

CREATE TRIGGER job_updated_at BEFORE UPDATE
  ON m_pub.job
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

CREATE TABLE m_pub.job_tag (
  job_id BIGINT REFERENCES m_pub.job(id) ON UPDATE CASCADE,
  tag_id BIGINT REFERENCES m_pub.tag(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER job_tag_updated_at BEFORE UPDATE
  ON m_pub.job
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

CREATE INDEX ON m_pub.job_tag (job_id);

CREATE TABLE m_priv.person_account (
  person_id        BIGINT PRIMARY KEY REFERENCES m_pub.person(id) ON UPDATE CASCADE,
  email            TEXT NOT NULL UNIQUE CHECK (email ~* '^.+@.+\..+$'),
  password_hash    TEXT NOT NULL
);

COMMENT ON TABLE m_priv.person_account is 'Private information about a person’s account.';
COMMENT ON COLUMN m_priv.person_account.person_id is 'The id of the person associated with this account.';
COMMENT ON COLUMN m_priv.person_account.email is 'The email address of the person.';
COMMENT ON COLUMN m_priv.person_account.password_hash is 'An opaque hash of the person’s password.';

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE FUNCTION m_pub.register_person(
  first_name text,
  last_name text,
  email text,
  password text
) RETURNS m_pub.person AS $$
declare
  person m_pub.person;
begin
  INSERT INTO m_pub.person (first_name, last_name) values
    (first_name, last_name)
    returning * INTO person;

  INSERT INTO m_priv.person_account (person_id, email, password_hash) values
    (person.id, email, crypt(password, gen_salt('bf')));

  return person;
end;
$$ language plpgsql strict security definer;

COMMENT ON FUNCTION m_pub.register_person(TEXT, TEXT, TEXT, TEXT) is 'Registers a single person and creates an account in our forum.';

CREATE ROLE sys_admin LOGIN PASSWORD 'voodoo3d';
CREATE ROLE middleman_visitor;
GRANT middleman_visitor TO sys_admin;
CREATE ROLE middleman_user;
GRANT middleman_user TO sys_admin;

CREATE TYPE m_pub.jwt_token AS (
  role text,
  person_id BIGINT
);

CREATE FUNCTION m_pub.authenticate(
  email text,
  password text
) RETURNS m_pub.jwt_token AS $$
declare
  account m_priv.person_account;
begin
  SELECT a.* INTO account
  from m_priv.person_account AS a
  where a.email = $1;

  if account.password_hash = crypt(password, account.password_hash) then
    return ('middleman_user', account.person_id)::m_pub.jwt_token;
  else
    return null;
  end if;
end;
$$ language plpgsql strict security definer;

COMMENT ON FUNCTION m_pub.authenticate(TEXT, TEXT) is 'Creates a JWT token that will securely identify a person and give them certain permissions.';

CREATE FUNCTION m_pub.current_person() RETURNS m_pub.person AS $$
  SELECT *
  from m_pub.person
  where id = current_setting('jwt.claims.person_id')::BIGINT
$$ language sql stable;

COMMENT ON FUNCTION m_pub.current_person() is 'Gets the person who was identified by our JWT.';

CREATE FUNCTION m_pub.open_jobs(
  lat REAL,
  long REAL
) RETURNS m_pub.job as $$
  SELECT *
  FROM m_pub.job
  WHERE m_pub.job.mode = 'opened'
  ORDER BY m_pub.job.geog <-> concat('SRID=26918;POINT(', long, ' ', lat, ')')::geometry
  LIMIT 50;
$$ language sql stable;

COMMENT ON FUNCTION m_pub.open_jobs(REAL, REAL) is 'Gets the 50 nearest open jobs via knn with use of index';

GRANT EXECUTE ON FUNCTION m_pub.open_jobs(REAL, REAL) TO middleman_user;
GRANT EXECUTE ON FUNCTION m_pub.authenticate(TEXT, TEXT) TO middleman_visitor, middleman_user;
GRANT EXECUTE ON FUNCTION m_pub.current_person() TO middleman_visitor, middleman_user;
GRANT EXECUTE ON FUNCTION m_pub.register_person(TEXT, TEXT, TEXT, TEXT) TO middleman_visitor;
GRANT usage on schema m_pub TO middleman_visitor, middleman_user, sys_admin;
GRANT SELECT ON TABLE m_pub.person TO middleman_visitor, middleman_user;
GRANT UPDATE, DELETE ON TABLE m_pub.person TO middleman_user;
ALTER TABLE m_pub.person enable row level security;
CREATE POLICY select_person on m_pub.person for SELECT TO middleman_user, middleman_visitor
  USING (true);
CREATE POLICY update_person on m_pub.person for UPDATE TO middleman_user
  USING (id = current_setting('jwt.claims.person_id')::INTEGER);
CREATE POLICY delete_person on m_pub.person for delete TO middleman_user
  USING (id = current_setting('jwt.claims.person_id')::INTEGER);

GRANT USAGE ON SEQUENCE m_pub.comment_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE m_pub.person_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE m_pub.phone_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE m_pub.photo_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE m_pub.tag_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE m_pub.url_id_seq TO middleman_user;
GRANT USAGE ON SEQUENCE m_pub.job_id_seq TO middleman_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.comment TO sys_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.phone TO sys_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.photo TO sys_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.tag TO sys_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.url TO sys_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.comment_tree TO sys_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.person_comment TO sys_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.job TO sys_admin;

GRANT SELECT ON TABLE m_pub.comment TO middleman_user, middleman_visitor;
GRANT SELECT ON TABLE m_pub.phone TO middleman_user, middleman_visitor;
GRANT SELECT ON TABLE m_pub.photo TO middleman_user, middleman_visitor;
GRANT SELECT ON TABLE m_pub.tag TO middleman_user, middleman_visitor;
GRANT SELECT ON TABLE m_pub.url TO middleman_user, middleman_visitor;
GRANT SELECT ON TABLE m_pub.comment_tree TO middleman_user, middleman_visitor;
GRANT SELECT ON TABLE m_pub.person_comment TO middleman_user, middleman_visitor;
GRANT SELECT ON TABLE m_pub.job TO middleman_user;

GRANT INSERT, UPDATE ON TABLE m_pub.comment TO middleman_user;
GRANT INSERT, UPDATE ON TABLE m_pub.phone TO middleman_user;
GRANT INSERT, UPDATE ON TABLE m_pub.photo TO middleman_user;
GRANT INSERT, UPDATE ON TABLE m_pub.tag TO middleman_user;
GRANT INSERT, UPDATE ON TABLE m_pub.url TO middleman_user;
GRANT INSERT, UPDATE ON TABLE m_pub.comment_tree TO middleman_user;
GRANT INSERT, UPDATE ON TABLE m_pub.person_comment TO middleman_user;
GRANT INSERT, UPDATE ON TABLE m_pub.job TO middleman_user;

ALTER TABLE m_pub.comment enable row level security;

CREATE POLICY select_COMMENT ON m_pub.comment for SELECT TO middleman_user, middleman_visitor
  USING (true);

CREATE POLICY insert_COMMENT ON m_pub.comment for INSERT TO middleman_user
  WITH CHECK (person_id = current_setting('jwt.claims.person_id')::INTEGER);

CREATE POLICY update_COMMENT ON m_pub.comment for UPDATE TO middleman_user
  USING (person_id = current_setting('jwt.claims.person_id')::INTEGER);

CREATE POLICY delete_COMMENT ON m_pub.comment for DELETE TO middleman_user
  USING (person_id = current_setting('jwt.claims.person_id')::INTEGER);

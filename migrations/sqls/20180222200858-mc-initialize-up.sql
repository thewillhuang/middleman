
create schema m_priv;
create schema m_pub;

alter DEFAULT privileges revoke execute on functions from public;

create function m_pub.set_updated_at() returns trigger as $$
begin
  new.updated_at := current_timestamp;
  return new;
end;
$$ language plpgsql;

CREATE TABLE m_pub.coordinate (
  id BIGSERIAL PRIMARY KEY,
  geohash TEXT NOT NULL UNIQUE,
  address TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER coordinate_updated_at BEFORE UPDATE
  ON m_pub.coordinate
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.coordinate is E'@omit all';

CREATE TABLE m_pub.phone (
  id BIGSERIAL PRIMARY KEY,
  country_code SMALLINT NOT NULL,
  area_code SMALLINT NOT NULL,
  phone integer NOT NULL,
  ext integer,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER phone_updated_at BEFORE UPDATE
  ON m_pub.phone
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.phone is E'@omit all';

ALTER TABLE m_pub.phone ADD CONSTRAINT phone_number UNIQUE (country_code, area_code, phone, ext);

CREATE TABLE m_pub.person (
  id BIGSERIAL PRIMARY KEY,
  first_name TEXT,
  last_name TEXT,
  phone_id BIGINT REFERENCES m_pub.phone(id) ON UPDATE CASCADE,
  coordinate_id BIGINT REFERENCES m_pub.coordinate(id) ON UPDATE CASCADE,
  is_client BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER person_updated_at BEFORE UPDATE
  ON m_pub.person
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.person is E'@omit all';

CREATE TABLE m_pub.tag (
  id BIGSERIAL PRIMARY KEY,
  tag TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER tag_updated_at BEFORE UPDATE
  ON m_pub.tag
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.tag is E'@omit all';

CREATE TABLE m_pub.url (
  id BIGSERIAL PRIMARY KEY,
  url TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER url_updated_at BEFORE UPDATE
  ON m_pub.url
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.url is E'@omit all';

CREATE TABLE m_pub.photo (
  id BIGSERIAL PRIMARY KEY,
  url_id BIGINT NOT NULL REFERENCES m_pub.url(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER photo_updated_at BEFORE UPDATE
  ON m_pub.photo
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.photo is E'@omit all';

CREATE TABLE m_pub.comment (
  id BIGSERIAL PRIMARY KEY,
  commentary TEXT,
  person_id BIGINT NOT NULL REFERENCES m_pub.person(id) ON UPDATE CASCADE,
  stars SMALLINT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX on m_pub.comment (person_id);

CREATE TRIGGER comment_updated_at BEFORE UPDATE
  ON m_pub.comment
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.comment is E'@omit all';

CREATE TABLE m_pub.comment_tree (
  parent_id BIGINT NOT NULL REFERENCES m_pub.comment(id) ON UPDATE CASCADE,
  child_id BIGINT NOT NULL REFERENCES m_pub.comment(id) ON UPDATE CASCADE,
  depth SMALLINT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER comment_tree_updated_at BEFORE UPDATE
  ON m_pub.comment_tree
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.comment_tree is E'@omit all';

ALTER TABLE m_pub.comment_tree ADD CONSTRAINT comment_tree_pkey PRIMARY KEY (parent_id, child_id);

CREATE TABLE m_pub.person_comment (
  person_id BIGINT REFERENCES m_pub.person(id) ON UPDATE CASCADE,
  comment_id BIGINT REFERENCES m_pub.comment(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER person_comment_updated_at BEFORE UPDATE
  ON m_pub.person
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

COMMENT ON TABLE m_pub.person_comment is E'@omit all';

CREATE TABLE m_pub.person_tag (
  person_id BIGINT REFERENCES m_pub.person(id) ON UPDATE CASCADE,
  tag_id BIGINT REFERENCES m_pub.tag(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER person_tag_updated_at BEFORE UPDATE
  ON m_pub.person
  FOR EACH ROW
  EXECUTE PROCEDURE m_pub.set_updated_at();

CREATE INDEX ON m_pub.person_tag (person_id);

COMMENT ON TABLE m_pub.person_tag is E'@omit all';

create table m_priv.person_account (
  person_id        BIGINT PRIMARY KEY REFERENCES m_pub.person(id) ON UPDATE cascade,
  email            TEXT NOT NULL UNIQUE CHECK (email ~* '^.+@.+\..+$'),
  password_hash    TEXT NOT NULL
);

COMMENT ON TABLE m_priv.person_account is 'Private information about a person’s account.';
COMMENT ON COLUMN m_priv.person_account.person_id is 'The id of the person associated with this account.';
COMMENT ON COLUMN m_priv.person_account.email is 'The email address of the person.';
COMMENT ON COLUMN m_priv.person_account.password_hash is 'An opaque hash of the person’s password.';

create extension if not exists pgcrypto;

create function m_pub.register_person(
  first_name text,
  last_name text,
  email text,
  password text
) returns m_pub.person as $$
declare
  person m_pub.person;
begin
  insert into m_pub.person (first_name, last_name) values
    (first_name, last_name)
    returning * into person;

  insert into m_priv.person_account (person_id, email, password_hash) values
    (person.id, email, crypt(password, gen_salt('bf')));

  return person;
end;
$$ language plpgsql strict security definer;

COMMENT ON function m_pub.register_person(text, text, text, text) is 'Registers a single person and creates an account in our forum.';

create role sys_admin login password 'voodoo3d';
create role app_visitor;
grant app_visitor to sys_admin;
create role app_user;
grant app_user to sys_admin;

create type m_pub.jwt_token as (
  role text,
  person_id BIGINT
);

create function m_pub.authenticate(
  email text,
  password text
) returns m_pub.jwt_token as $$
declare
  account m_priv.person_account;
begin
  select a.* into account
  from m_priv.person_account as a
  where a.email = $1;

  if account.password_hash = crypt(password, account.password_hash) then
    return ('person', account.person_id)::m_pub.jwt_token;
  else
    return null;
  end if;
end;
$$ language plpgsql strict security definer;

COMMENT ON function m_pub.authenticate(text, text) is 'Creates a JWT token that will securely identify a person and give them certain permissions.';

create function m_pub.current_person() returns m_pub.person as $$
  select *
  from m_pub.person
  where id = current_setting('jwt.claims.person_id')::BIGINT
$$ language sql stable;

COMMENT ON function m_pub.current_person() is 'Gets the person who was identified by our JWT.';

grant execute on function m_pub.authenticate(text, text) to app_visitor, app_user;
grant execute on function m_pub.current_person() to app_visitor, app_user;
grant execute on function m_pub.register_person(text, text, text, text) to app_visitor;
grant usage on schema m_pub to app_visitor, app_user, sys_admin;
grant select on table m_pub.person to app_visitor, app_user;
grant update, delete on table m_pub.person to app_user;
alter table m_pub.person enable row level security;
create policy select_person on m_pub.person for select to app_user, app_visitor
  using (true);
create policy update_person on m_pub.person for update to person
  using (id = current_setting('jwt.claims.person_id')::integer);
create policy delete_person on m_pub.person for delete to person
  using (id = current_setting('jwt.claims.person_id')::integer);

grant usage on sequence m_pub.comment_id_seq to app_user;
grant usage on sequence m_pub.coordinate_id_seq to app_user;
grant usage on sequence m_pub.person_id_seq to app_user;
grant usage on sequence m_pub.phone_id_seq to app_user;
grant usage on sequence m_pub.photo_id_seq to app_user;
grant usage on sequence m_pub.tag_id_seq to app_user;
grant usage on sequence m_pub.url_id_seq to app_user;

grant select, insert, update, delete on table m_pub.comment to sys_admin;
grant select, insert, update, delete on table m_pub.coordinate to sys_admin;
grant select, insert, update, delete on table m_pub.phone to sys_admin;
grant select, insert, update, delete on table m_pub.photo to sys_admin;
grant select, insert, update, delete on table m_pub.tag to sys_admin;
grant select, insert, update, delete on table m_pub.url to sys_admin;
grant select, insert, update, delete on table m_pub.comment_tree to sys_admin;
grant select, insert, update, delete on table m_pub.person_comment to sys_admin;

grant select on table m_pub.comment to app_user, app_visitor;
grant select on table m_pub.coordinate to app_user, app_visitor;
grant select on table m_pub.phone to app_user, app_visitor;
grant select on table m_pub.photo to app_user, app_visitor;
grant select on table m_pub.tag to app_user, app_visitor;
grant select on table m_pub.url to app_user, app_visitor;
grant select on table m_pub.comment_tree to app_user, app_visitor;
grant select on table m_pub.person_comment to app_user, app_visitor;


grant insert, update on table m_pub.comment to app_user;
grant insert, update on table m_pub.coordinate to app_user;
grant insert, update on table m_pub.phone to app_user;
grant insert, update on table m_pub.photo to app_user;
grant insert, update on table m_pub.tag to app_user;
grant insert, update on table m_pub.url to app_user;
grant insert, update on table m_pub.comment_tree to app_user;
grant insert, update on table m_pub.person_comment to app_user;

alter table m_pub.comment enable row level security;

create policy select_COMMENT ON m_pub.comment for select to app_user, app_visitor
  using (true);

create policy insert_COMMENT ON m_pub.comment for insert to app_user
  with check (person_id = current_setting('jwt.claims.person_id')::integer);

create policy update_COMMENT ON m_pub.comment for update to app_user
  using (person_id = current_setting('jwt.claims.person_id')::integer);

create policy delete_COMMENT ON m_pub.comment for delete to app_user
  using (person_id = current_setting('jwt.claims.person_id')::integer);

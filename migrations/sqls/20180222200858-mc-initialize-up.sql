
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

create trigger coordinate_updated_at before update
  on m_pub.coordinate
  for each row
  execute procedure m_pub.set_updated_at();

CREATE TABLE m_pub.phone (
  id BIGSERIAL PRIMARY KEY,
  country_code SMALLINT NOT NULL,
  area_code SMALLINT NOT NULL,
  phone integer NOT NULL,
  ext integer,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger phone_updated_at before update
  on m_pub.phone
  for each row
  execute procedure m_pub.set_updated_at();

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

create trigger person_updated_at before update
  on m_pub.person
  for each row
  execute procedure m_pub.set_updated_at();


CREATE TABLE m_pub.tag (
  id BIGSERIAL PRIMARY KEY,
  tag TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger tag_updated_at before update
  on m_pub.tag
  for each row
  execute procedure m_pub.set_updated_at();

CREATE TABLE m_pub.url (
  id BIGSERIAL PRIMARY KEY,
  url TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger url_updated_at before update
  on m_pub.url
  for each row
  execute procedure m_pub.set_updated_at();

CREATE TABLE m_pub.photo (
  id BIGSERIAL PRIMARY KEY,
  url_id BIGINT NOT NULL REFERENCES m_pub.url(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger photo_updated_at before update
  on m_pub.photo
  for each row
  execute procedure m_pub.set_updated_at();

CREATE TABLE m_pub.comment (
  id BIGSERIAL PRIMARY KEY,
  commentary TEXT NOT NULL,
  person_id BIGINT NOT NULL REFERENCES m_pub.person(id) ON UPDATE CASCADE,
  stars SMALLINT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX on m_pub.comment (person_id);

create trigger comment_updated_at before update
  on m_pub.comment
  for each row
  execute procedure m_pub.set_updated_at();

CREATE TABLE m_pub.comment_tree (
  parent_id BIGINT NOT NULL REFERENCES m_pub.comment(id) ON UPDATE CASCADE,
  child_id BIGINT NOT NULL REFERENCES m_pub.comment(id) ON UPDATE CASCADE,
  depth SMALLINT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger comment_tree_updated_at before update
  on m_pub.comment_tree
  for each row
  execute procedure m_pub.set_updated_at();

ALTER TABLE m_pub.comment_tree ADD CONSTRAINT comment_tree_pkey PRIMARY KEY (parent_id, child_id);

create table m_priv.person_account (
  person_id        BIGINT PRIMARY KEY REFERENCES m_pub.person(id) ON UPDATE cascade,
  email            TEXT NOT NULL UNIQUE CHECK (email ~* '^.+@.+\..+$'),
  password_hash    TEXT NOT NULL
);

comment on table m_priv.person_account is 'Private information about a person’s account.';
comment on column m_priv.person_account.person_id is 'The id of the person associated with this account.';
comment on column m_priv.person_account.email is 'The email address of the person.';
comment on column m_priv.person_account.password_hash is 'An opaque hash of the person’s password.';

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

comment on function m_pub.register_person(text, text, text, text) is 'Registers a single person and creates an account in our forum.';

create role system_admin login password 'voodoo3d';
create role person_anonymous;
grant person_anonymous to system_admin;
create role person;
grant person to system_admin;

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

comment on function m_pub.authenticate(text, text) is 'Creates a JWT token that will securely identify a person and give them certain permissions.';

create function m_pub.current_person() returns m_pub.person as $$
  select *
  from m_pub.person
  where id = current_setting('jwt.claims.person_id')::BIGINT
$$ language sql stable;

comment on function m_pub.current_person() is 'Gets the person who was identified by our JWT.';

grant execute on function m_pub.authenticate(text, text) to person_anonymous, person;
grant execute on function m_pub.current_person() to person_anonymous, person;
grant execute on function m_pub.register_person(text, text, text, text) to person_anonymous;
grant usage on schema m_pub to person_anonymous, person, system_admin;
grant select on table m_pub.person to person_anonymous, person;
grant update, delete on table m_pub.person to person;
alter table m_pub.person enable row level security;
create policy select_person on m_pub.person for select to person, person_anonymous
  using (true);
create policy update_person on m_pub.person for update to person
  using (id = current_setting('jwt.claims.person_id')::integer);
create policy delete_person on m_pub.person for delete to person
  using (id = current_setting('jwt.claims.person_id')::integer);

grant usage on sequence m_pub.comment_id_seq to person;
grant usage on sequence m_pub.coordinate_id_seq to person;
grant usage on sequence m_pub.person_id_seq to person;
grant usage on sequence m_pub.phone_id_seq to person;
grant usage on sequence m_pub.photo_id_seq to person;
grant usage on sequence m_pub.tag_id_seq to person;
grant usage on sequence m_pub.url_id_seq to person;

grant select, insert, update, delete on table m_pub.comment to system_admin;
grant select, insert, update, delete on table m_pub.coordinate to system_admin;
grant select, insert, update, delete on table m_pub.phone to system_admin;
grant select, insert, update, delete on table m_pub.photo to system_admin;
grant select, insert, update, delete on table m_pub.tag to system_admin;
grant select, insert, update, delete on table m_pub.url to system_admin;
grant select, insert, update, delete on table m_pub.comment_tree to system_admin;

grant select on table m_pub.comment to person, person_anonymous;
grant select on table m_pub.coordinate to person, person_anonymous;
grant select on table m_pub.phone to person, person_anonymous;
grant select on table m_pub.photo to person, person_anonymous;
grant select on table m_pub.tag to person, person_anonymous;
grant select on table m_pub.url to person, person_anonymous;
grant select on table m_pub.comment_tree to person, person_anonymous;

grant insert, update on table m_pub.comment to person;
grant insert, update on table m_pub.coordinate to person;
grant insert, update on table m_pub.phone to person;
grant insert, update on table m_pub.photo to person;
grant insert, update on table m_pub.tag to person;
grant insert, update on table m_pub.url to person;
grant insert, update on table m_pub.comment_tree to person;

alter table m_pub.comment enable row level security;

create policy select_comment on m_pub.comment for select to person, person_anonymous
  using (true);

create policy insert_comment on m_pub.comment for insert to person
  with check (person_id = current_setting('jwt.claims.person_id')::integer);

create policy update_comment on m_pub.comment for update to person
  using (person_id = current_setting('jwt.claims.person_id')::integer);

create policy delete_comment on m_pub.comment for delete to person
  using (person_id = current_setting('jwt.claims.person_id')::integer);

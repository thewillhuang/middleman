
create schema mc_priv;
create schema mc_pub;

alter DEFAULT privileges revoke execute on functions from public;

create function mc_pub.set_updated_at() returns trigger as $$
begin
  new.updated_at := current_timestamp;
  return new;
end;
$$ language plpgsql;


CREATE TABLE mc_pub.coordinate (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  geohash TEXT NOT NULL UNIQUE,
  address TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger coordinate_updated_at before update
  on mc_pub.coordinate
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE TABLE mc_pub.phone (
  id BIGSERIAL PRIMARY KEY,
  country_code SMALLINT NOT NULL,
  area_code SMALLINT NOT NULL,
  phone integer NOT NULL,
  ext integer,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger phone_updated_at before update
  on mc_pub.phone
  for each row
  execute procedure mc_pub.set_updated_at();

ALTER TABLE mc_pub.phone ADD CONSTRAINT phone_number UNIQUE (country_code, area_code, phone, ext);

CREATE TABLE mc_pub.person (
  id BIGSERIAL PRIMARY KEY,
  first_name TEXT,
  last_name TEXT,
  phone_id BIGINT REFERENCES mc_pub.phone(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger person_updated_at before update
  on mc_pub.person
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE TABLE mc_pub.item (
  id BIGSERIAL PRIMARY KEY,
  metaphone_hash_one TEXT NOT NULL,
  metaphone_hash_two TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger item_updated_at before update
  on mc_pub.item
  for each row
  execute procedure mc_pub.set_updated_at();

ALTER TABLE mc_pub.item ADD CONSTRAINT item_metaphone_hash UNIQUE (metaphone_hash_one, metaphone_hash_two);

CREATE TABLE mc_pub.store (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  phone_id BIGINT NOT NULL REFERENCES mc_pub.phone(id) ON UPDATE CASCADE,
  coordinate_id BIGINT NOT NULL REFERENCES mc_pub.coordinate(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger store_updated_at before update
  on mc_pub.store
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE TABLE mc_pub.tag (
  id BIGSERIAL PRIMARY KEY,
  tag TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger tag_updated_at before update
  on mc_pub.tag
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE TABLE mc_pub.url (
  id BIGSERIAL PRIMARY KEY,
  url TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger url_updated_at before update
  on mc_pub.url
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE TABLE mc_pub.barcode (
  id BIGSERIAL PRIMARY KEY,
  barcode TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger barcode_updated_at before update
  on mc_pub.barcode
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE TABLE mc_pub.name (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger name_updated_at before update
  on mc_pub.name
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE TABLE mc_pub.photo (
  id BIGSERIAL PRIMARY KEY,
  url_id BIGINT NOT NULL REFERENCES mc_pub.url(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger photo_updated_at before update
  on mc_pub.photo
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE TABLE mc_pub.comment (
  id BIGSERIAL PRIMARY KEY,
  commentary TEXT NOT NULL,
  person_id BIGINT NOT NULL REFERENCES mc_pub.person(id) ON UPDATE CASCADE,
  stars SMALLINT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX on mc_pub.comment (person_id);

create trigger comment_updated_at before update
  on mc_pub.comment
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE TABLE mc_pub.lab (
  id BIGSERIAL PRIMARY KEY,
  coordinate_id BIGINT NOT NULL REFERENCES mc_pub.coordinate(id) ON UPDATE CASCADE,
  lab_name TEXT NOT NULL UNIQUE,
  phone_id BIGINT NOT NULL REFERENCES mc_pub.phone(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger lab_updated_at before update
  on mc_pub.lab
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE TABLE mc_pub.campaign (
  id BIGSERIAL PRIMARY KEY,
  needed FLOAT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger campaign_updated_at before update
  on mc_pub.campaign
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE TABLE mc_pub.result (
  id BIGSERIAL PRIMARY KEY,
  lab_id BIGINT NOT NULL REFERENCES mc_pub.lab(id) ON UPDATE CASCADE,
  url_id BIGINT NOT NULL REFERENCES mc_pub.url(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX on mc_pub.result (lab_id);

create trigger result_updated_at before update
  on mc_pub.result
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE TABLE mc_pub.comment_tree (
  parent_id BIGINT NOT NULL REFERENCES mc_pub.comment(id) ON UPDATE CASCADE,
  child_id BIGINT NOT NULL REFERENCES mc_pub.comment(id) ON UPDATE CASCADE,
  depth SMALLINT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger comment_tree_updated_at before update
  on mc_pub.comment_tree
  for each row
  execute procedure mc_pub.set_updated_at();

ALTER TABLE mc_pub.comment_tree ADD CONSTRAINT comment_tree_pkey PRIMARY KEY (parent_id, child_id);

CREATE TABLE mc_pub.campaign_donation (
  person_id BIGINT NOT NULL REFERENCES mc_pub.person(id) ON UPDATE CASCADE,
  campaign_id BIGINT NOT NULL PRIMARY KEY REFERENCES mc_pub.campaign(id) ON UPDATE CASCADE,
  amount FLOAT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger campaign_donation_updated_at before update
  on mc_pub.campaign_donation
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE INDEX on mc_pub.campaign_donation (person_id);

CREATE TABLE mc_pub.item_store (
  item_id BIGINT NOT NULL PRIMARY KEY REFERENCES mc_pub.item(id) ON UPDATE CASCADE,
  store_id BIGINT NOT NULL UNIQUE REFERENCES mc_pub.store(id) ON UPDATE CASCADE,
  person_id BIGINT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger item_store_updated_at before update
  on mc_pub.item_store
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE INDEX ON mc_pub.item_store (person_id);

CREATE TABLE mc_pub.item_url (
  item_id BIGINT NOT NULL PRIMARY KEY REFERENCES mc_pub.item(id) ON UPDATE CASCADE,
  url_id BIGINT NOT NULL UNIQUE REFERENCES mc_pub.url(id) ON UPDATE CASCADE,
  person_id BIGINT NOT NULL REFERENCES mc_pub.person(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger item_url_updated_at before update
  on mc_pub.item_url
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE INDEX ON mc_pub.item_url (person_id);

CREATE TABLE mc_pub.item_name (
  item_id BIGINT NOT NULL PRIMARY KEY REFERENCES mc_pub.item(id) ON UPDATE CASCADE,
  name_id BIGINT NOT NULL UNIQUE REFERENCES mc_pub.name(id) ON UPDATE CASCADE,
  person_id BIGINT NOT NULL REFERENCES mc_pub.person(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger item_name_updated_at before update
  on mc_pub.item_name
  for each row
  execute procedure mc_pub.set_updated_at();


CREATE INDEX ON mc_pub.item_name (person_id);

CREATE TABLE mc_pub.item_result (
  item_id BIGINT NOT NULL PRIMARY KEY REFERENCES mc_pub.item(id) ON UPDATE CASCADE,
  result_id BIGINT NOT NULL UNIQUE REFERENCES mc_pub.result(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger item_result_updated_at before update
  on mc_pub.item_result
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE TABLE mc_pub.item_comment (
  item_id BIGINT NOT NULL PRIMARY KEY REFERENCES mc_pub.item(id) ON UPDATE CASCADE,
  comment_id BIGINT NOT NULL UNIQUE REFERENCES mc_pub.comment(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger item_comment_updated_at before update
  on mc_pub.item_comment
  for each row
  execute procedure mc_pub.set_updated_at();


CREATE TABLE mc_pub.item_photo (
  item_id BIGINT NOT NULL PRIMARY KEY REFERENCES mc_pub.item(id) ON UPDATE CASCADE,
  photo_id BIGINT NOT NULL REFERENCES mc_pub.photo(id) ON UPDATE CASCADE,
  person_id BIGINT NOT NULL REFERENCES mc_pub.person(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger item_photo_updated_at before update
  on mc_pub.item_photo
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE INDEX ON mc_pub.item_photo (person_id);

CREATE TABLE mc_pub.tag_item (
  tag_id BIGINT NOT NULL PRIMARY KEY REFERENCES mc_pub.tag(id) ON UPDATE CASCADE,
  item_id BIGINT NOT NULL REFERENCES mc_pub.item(id) ON UPDATE CASCADE,
  person_id BIGINT NOT NULL REFERENCES mc_pub.person(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger tag_item_updated_at before update
  on mc_pub.tag_item
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE INDEX ON mc_pub.tag_item (person_id);
CREATE INDEX ON mc_pub.tag_item (tag_id);
CREATE INDEX ON mc_pub.tag_item (item_id);

CREATE TABLE mc_pub.item_campaign (
  item_id BIGINT NOT NULL PRIMARY KEY REFERENCES mc_pub.item(id) ON UPDATE CASCADE,
  campaign_id BIGINT NOT NULL UNIQUE REFERENCES mc_pub.campaign(id) ON UPDATE CASCADE,
  person_id BIGINT NOT NULL REFERENCES mc_pub.person(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger item_campaign_updated_at before update
  on mc_pub.item_campaign
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE INDEX ON mc_pub.item_campaign (person_id);
CREATE INDEX ON mc_pub.item_campaign (campaign_id);

CREATE TABLE mc_pub.item_location (
  item_id BIGINT NOT NULL PRIMARY KEY REFERENCES mc_pub.item(id) ON UPDATE CASCADE,
  coordinate_id BIGINT NOT NULL UNIQUE REFERENCES mc_pub.coordinate(id) ON UPDATE CASCADE,
  person_id BIGINT NOT NULL REFERENCES mc_pub.person(id) ON UPDATE CASCADE,
  cost FLOAT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

create trigger item_location_updated_at before update
  on mc_pub.item_location
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE INDEX ON mc_pub.item_location (person_id);
CREATE INDEX ON mc_pub.item_location (coordinate_id);

CREATE TABLE mc_pub.barcode_item (
  barcode_id BIGINT NOT NULL PRIMARY KEY REFERENCES mc_pub.barcode(id) ON UPDATE CASCADE,
  item_id BIGINT NOT NULL REFERENCES mc_pub.item(id) ON UPDATE CASCADE,
  person_id BIGINT NOT NULL REFERENCES mc_pub.person(id) ON UPDATE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

comment on table mc_pub.barcode_item is 'contains different items with the same barcode along with users who submitted the barcode';
comment on column mc_pub.barcode_item.barcode_id is 'barcode id of the barcode';
comment on column mc_pub.barcode_item.item_id is 'item id of the barcode';
comment on column mc_pub.barcode_item.person_id is 'person id of the barcode';

create trigger barcode_item_updated_at before update
  on mc_pub.barcode_item
  for each row
  execute procedure mc_pub.set_updated_at();

CREATE INDEX ON mc_pub.barcode_item (person_id);
CREATE INDEX ON mc_pub.barcode_item (item_id);

create table mc_priv.person_account (
  person_id        BIGINT PRIMARY KEY REFERENCES mc_pub.person(id) ON UPDATE cascade,
  email            TEXT NOT NULL UNIQUE CHECK (email ~* '^.+@.+\..+$'),
  password_hash    TEXT NOT NULL
);

comment on table mc_priv.person_account is 'Private information about a person’s account.';
comment on column mc_priv.person_account.person_id is 'The id of the person associated with this account.';
comment on column mc_priv.person_account.email is 'The email address of the person.';
comment on column mc_priv.person_account.password_hash is 'An opaque hash of the person’s password.';

create extension if not exists pgcrypto;

create function mc_pub.register_person(
  first_name text,
  last_name text,
  email text,
  password text
) returns mc_pub.person as $$
declare
  person mc_pub.person;
begin
  insert into mc_pub.person (first_name, last_name) values
    (first_name, last_name)
    returning * into person;

  insert into mc_priv.person_account (person_id, email, password_hash) values
    (person.id, email, crypt(password, gen_salt('bf')));

  return person;
end;
$$ language plpgsql strict security definer;

comment on function mc_pub.register_person(text, text, text, text) is 'Registers a single person and creates an account in our forum.';

create role system_admin login password 'voodoo3d';
create role person_anonymous;
grant person_anonymous to system_admin;
create role person;
grant person to system_admin;

create type mc_pub.jwt_token as (
  role text,
  person_id BIGINT
);

create function mc_pub.authenticate(
  email text,
  password text
) returns mc_pub.jwt_token as $$
declare
  account mc_priv.person_account;
begin
  select a.* into account
  from mc_priv.person_account as a
  where a.email = $1;

  if account.password_hash = crypt(password, account.password_hash) then
    return ('person', account.person_id)::mc_pub.jwt_token;
  else
    return null;
  end if;
end;
$$ language plpgsql strict security definer;

comment on function mc_pub.authenticate(text, text) is 'Creates a JWT token that will securely identify a person and give them certain permissions.';

create function mc_pub.current_person() returns mc_pub.person as $$
  select *
  from mc_pub.person
  where id = current_setting('jwt.claims.person_id')::BIGINT
$$ language sql stable;

comment on function mc_pub.current_person() is 'Gets the person who was identified by our JWT.';

grant execute on function mc_pub.authenticate(text, text) to person_anonymous, person;
grant execute on function mc_pub.current_person() to person_anonymous, person;
grant execute on function mc_pub.register_person(text, text, text, text) to person_anonymous;
grant usage on schema mc_pub to person_anonymous, person, system_admin;
grant select on table mc_pub.person to person_anonymous, person;
grant update, delete on table mc_pub.person to person;
alter table mc_pub.person enable row level security;
create policy select_person on mc_pub.person for select to person, person_anonymous
  using (true);
create policy update_person on mc_pub.person for update to person
  using (id = current_setting('jwt.claims.person_id')::integer);
create policy delete_person on mc_pub.person for delete to person
  using (id = current_setting('jwt.claims.person_id')::integer);

grant usage on sequence mc_pub.barcode_id_seq to person;
grant usage on sequence mc_pub.campaign_id_seq to person;
grant usage on sequence mc_pub.comment_id_seq to person;
grant usage on sequence mc_pub.coordinate_id_seq to person;
grant usage on sequence mc_pub.item_id_seq to person;
grant usage on sequence mc_pub.lab_id_seq to person;
grant usage on sequence mc_pub.name_id_seq to person;
grant usage on sequence mc_pub.person_id_seq to person;
grant usage on sequence mc_pub.phone_id_seq to person;
grant usage on sequence mc_pub.photo_id_seq to person;
-- grant usage on sequence mc_pub.result_id_seq to person;
grant usage on sequence mc_pub.store_id_seq to person;
grant usage on sequence mc_pub.tag_id_seq to person;
grant usage on sequence mc_pub.url_id_seq to person;

grant select, insert, update, delete on table mc_pub.barcode to system_admin;
grant select, insert, update, delete on table mc_pub.campaign to system_admin;
grant select, insert, update, delete on table mc_pub.comment to system_admin;
grant select, insert, update, delete on table mc_pub.coordinate to system_admin;
grant select, insert, update, delete on table mc_pub.item to system_admin;
grant select, insert, update, delete on table mc_pub.lab to system_admin;
grant select, insert, update, delete on table mc_pub.name to system_admin;
grant select, insert, update, delete on table mc_pub.phone to system_admin;
grant select, insert, update, delete on table mc_pub.photo to system_admin;
grant select, insert, update, delete on table mc_pub.result to system_admin;
grant select, insert, update, delete on table mc_pub.store to system_admin;
grant select, insert, update, delete on table mc_pub.tag to system_admin;
grant select, insert, update, delete on table mc_pub.url to system_admin;
grant select, insert, update, delete on table mc_pub.barcode_item to system_admin;
grant select, insert, update, delete on table mc_pub.campaign_donation to system_admin;
grant select, insert, update, delete on table mc_pub.comment_tree to system_admin;
grant select, insert, update, delete on table mc_pub.item_campaign to system_admin;
grant select, insert, update, delete on table mc_pub.item_comment to system_admin;
grant select, insert, update, delete on table mc_pub.item_location to system_admin;
grant select, insert, update, delete on table mc_pub.item_name to system_admin;
grant select, insert, update, delete on table mc_pub.item_photo to system_admin;
grant select, insert, update, delete on table mc_pub.item_result to system_admin;
grant select, insert, update, delete on table mc_pub.item_store to system_admin;
grant select, insert, update, delete on table mc_pub.tag_item to system_admin;
grant select, insert, update, delete on table mc_pub.item_url to system_admin;

grant select on table mc_pub.barcode to person, person_anonymous;
grant select on table mc_pub.campaign to person, person_anonymous;
grant select on table mc_pub.comment to person, person_anonymous;
grant select on table mc_pub.coordinate to person, person_anonymous;
grant select on table mc_pub.item to person, person_anonymous;
grant select on table mc_pub.lab to person, person_anonymous;
grant select on table mc_pub.name to person, person_anonymous;
grant select on table mc_pub.phone to person, person_anonymous;
grant select on table mc_pub.photo to person, person_anonymous;
grant select on table mc_pub.result to person, person_anonymous;
grant select on table mc_pub.store to person, person_anonymous;
grant select on table mc_pub.tag to person, person_anonymous;
grant select on table mc_pub.url to person, person_anonymous;
grant select on table mc_pub.barcode_item to person, person_anonymous;
grant select on table mc_pub.campaign_donation to person, person_anonymous;
grant select on table mc_pub.comment_tree to person, person_anonymous;
grant select on table mc_pub.item_campaign to person, person_anonymous;
grant select on table mc_pub.item_comment to person, person_anonymous;
grant select on table mc_pub.item_location to person, person_anonymous;
grant select on table mc_pub.item_name to person, person_anonymous;
grant select on table mc_pub.item_photo to person, person_anonymous;
grant select on table mc_pub.item_result to person, person_anonymous;
grant select on table mc_pub.item_store to person, person_anonymous;
grant select on table mc_pub.tag_item to person, person_anonymous;
grant select on table mc_pub.item_url to person, person_anonymous;

grant insert, update on table mc_pub.barcode to person;
grant insert, update on table mc_pub.campaign to person;
grant insert, update on table mc_pub.comment to person;
grant insert, update on table mc_pub.coordinate to person;
grant insert, update on table mc_pub.item to person;
grant insert, update on table mc_pub.lab to person;
grant insert, update on table mc_pub.name to person;
grant insert, update on table mc_pub.phone to person;
grant insert, update on table mc_pub.photo to person;
-- grant insert, update on table mc_pub.result to person;
grant insert, update on table mc_pub.store to person;
grant insert, update on table mc_pub.tag to person;
grant insert, update on table mc_pub.url to person;
grant insert, update on table mc_pub.barcode_item to person;
grant insert, update on table mc_pub.campaign_donation to person;
grant insert, update on table mc_pub.comment_tree to person;
grant insert, update on table mc_pub.item_campaign to person;
grant insert, update on table mc_pub.item_comment to person;
grant insert, update on table mc_pub.item_location to person;
grant insert, update on table mc_pub.item_name to person;
grant insert, update on table mc_pub.item_photo to person;
-- grant insert, update on table mc_pub.item_result to person;
grant insert, update on table mc_pub.item_store to person;
grant insert, update on table mc_pub.tag_item to person;
grant insert, update on table mc_pub.item_url to person;

alter table mc_pub.comment enable row level security;

create policy select_comment on mc_pub.comment for select to person, person_anonymous
  using (true);

create policy insert_comment on mc_pub.comment for insert to person
  with check (person_id = current_setting('jwt.claims.person_id')::integer);

create policy update_comment on mc_pub.comment for update to person
  using (person_id = current_setting('jwt.claims.person_id')::integer);

create policy delete_comment on mc_pub.comment for delete to person
  using (person_id = current_setting('jwt.claims.person_id')::integer);

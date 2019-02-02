CREATE SCHEMA m_priv;
CREATE SCHEMA m_pub;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM public;

CREATE FUNCTION m_pub.set_updated_at_column() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION m_pub.set_geog_column() RETURNS TRIGGER AS $$
BEGIN
  NEW.geog := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE m_pub.phone (
  id BIGSERIAL PRIMARY KEY,
  country_code TEXT NOT NULL,
  phone TEXT NOT NULL,
  ext TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER phone_updated_at BEFORE UPDATE
  ON m_pub.phone
  FOR EACH ROW EXECUTE PROCEDURE m_pub.set_updated_at_column();

COMMENT ON TABLE m_pub.phone IS
  E'@omit create,update,delete,filter,all';

CREATE TABLE m_pub.person (
  id BIGSERIAL PRIMARY KEY,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  longitude REAL NOT NULL DEFAULT 0,
  latitude REAL NOT NULL DEFAULT 0,
  geog GEOMETRY,
  is_client BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON m_pub.person USING GIST (geog);
CREATE INDEX ON m_pub.person (is_client) WHERE is_client = FALSE;

CREATE TRIGGER person_updated_at BEFORE UPDATE
  ON m_pub.person
  FOR EACH ROW EXECUTE PROCEDURE m_pub.set_updated_at_column();

CREATE TRIGGER PERSON_set_geog_column BEFORE INSERT OR UPDATE
  ON m_pub.person
  FOR EACH ROW EXECUTE PROCEDURE m_pub.set_geog_column();

COMMENT ON TABLE m_pub.person IS
  E'@omit create,update,delete,filter,all';

CREATE TABLE m_pub.photo (
  id BIGSERIAL PRIMARY KEY,
  url TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER photo_updated_at BEFORE UPDATE
  ON m_pub.photo
  FOR EACH ROW EXECUTE PROCEDURE m_pub.set_updated_at_column();

COMMENT ON TABLE m_pub.photo IS
  E'@omit create,update,delete,filter,all';

CREATE TYPE m_pub.task_status AS ENUM (
  'closed', -- task cancled
  'opened', -- task requested
  'scheduled', -- task with fulfiller found
  'pending', -- finished task awaiting client confirmation
  'finished' -- finished tasks
);

CREATE TYPE m_pub.task_type AS ENUM (
  'boat rentals',
  'car battery switch',
  'car cabin air filter change',
  'car delivery',
  'car detail',
  'car detailing ',
  'car headlights upgrade',
  'car light switching',
  'car oil change',
  'car rentals',
  'car selling',
  'car tire replacement',
  'car towing',
  'car wash',
  'car windshield swap',
  'car windshield wiper',
  'charity pickup',
  'dry cleaning',
  'ecommerce delivery',
  'elder bathing',
  'elder cooking',
  'elder shopping',
  'elder transportation',
  'equipment maintenance schedule for companies',
  'food delivery',
  'gas refilling',
  'gear rentals',
  'grocery delivery',
  'home appliance fixing',
  'home cleaning',
  'home pest control',
  'home plumming',
  'home water filter',
  'home water softening',
  'junk dump',
  'logo design',
  'maid',
  'massage',
  'medical tourism',
  'dental splints',
  'dental custom impression trays',
  'dental guards',
  'dental models',
  'dental denture',
  'dental surgical guide',
  'dental bridge',
  'dental crown',
  'dental aligners',
  'pet bnb',
  'pet hair cutting ',
  'pet services',
  'pet walking',
  'photoshop',
  'property management',
  'event management',
  'rent management',
  'hoa management',
  'rent A bf',
  'rent A gf',
  'rent A pet',
  'rent A suit',
  'road side assistance',
  'rv rentals',
  'storage pickup',
  'tire changing',
  'trucking',
  'used car selling',
  'weed delivery'
);

CREATE TYPE m_pub.user_type AS ENUM (
  'fulfiller',
  'requester',
  'open fulfiller',
  'none'
);

CREATE TABLE m_pub.task_permission (
  current_status m_pub.task_status NOT NULL,
  user_type m_pub.user_type NOT NULL,
  can_update BOOLEAN,
  can_update_to m_pub.task_status,
  PRIMARY KEY (current_status, user_type)
);

COMMENT ON TABLE m_pub.task_permission IS
  E'@omit';

INSERT INTO m_pub.task_permission (current_status, user_type, can_update_to) VALUES
  ('opened', 'requester', 'closed'),
  ('opened', 'open fulfiller', 'scheduled'),
  ('scheduled', 'fulfiller', 'pending'),
  ('pending', 'requester', 'finished');

CREATE TABLE m_pub.task (
  id BIGSERIAL PRIMARY KEY,
  requestor_id BIGINT NOT NULL REFERENCES m_pub.person ON UPDATE CASCADE,
  fulfiller_id BIGINT REFERENCES m_pub.person ON UPDATE CASCADE,
  longitude REAL NOT NULL,
  latitude REAL NOT NULL,
  scheduled_for TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  geog GEOMETRY,
  fulfiller_rating SMALLINT,
  category m_pub.task_type NOT NULL,
  status m_pub.task_status NOT NULL DEFAULT 'opened',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON m_pub.task USING GIST (geog);
CREATE INDEX ON m_pub.task (fulfiller_id);
CREATE INDEX ON m_pub.task (status) WHERE status != 'finished' AND status != 'closed';

CREATE TRIGGER task_updated_at BEFORE UPDATE
  ON m_pub.task
  FOR EACH ROW EXECUTE PROCEDURE m_pub.set_updated_at_column();

CREATE TRIGGER task_set_geog_column BEFORE INSERT OR UPDATE
  ON m_pub.task
  FOR EACH ROW EXECUTE PROCEDURE m_pub.set_geog_column();

COMMENT ON TABLE m_pub.task IS
  E'@omit all,delete,update';

CREATE TABLE m_pub.task_detail (
  task_id BIGINT NOT NULL REFERENCES m_pub.task ON UPDATE CASCADE,
  attribute TEXT NOT NULL,
  value TEXT NOT NULL,
  PRIMARY KEY (task_id, attribute),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER task_detail_updated_at BEFORE UPDATE
  ON m_pub.task_detail
  FOR EACH ROW EXECUTE PROCEDURE m_pub.set_updated_at_column();

COMMENT ON TABLE m_pub.task_detail IS
  E'@omit all';

CREATE TABLE m_pub.rating (
  person_id BIGINT NOT NULL REFERENCES m_pub.person ON UPDATE CASCADE,
  task_id BIGINT NOT NULL REFERENCES m_pub.task ON UPDATE CASCADE,
  rating SMALLINT NOT NULL,
  PRIMARY KEY (task_id, person_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER rating_updated_at BEFORE UPDATE
  ON m_pub.rating
  FOR EACH ROW EXECUTE PROCEDURE m_pub.set_updated_at_column();

COMMENT ON TABLE m_pub.rating IS
  E'@omit';

CREATE TABLE m_pub.person_photo (
  person_id BIGINT NOT NULL REFERENCES m_pub.person ON UPDATE CASCADE,
  photo_id BIGINT NOT NULL REFERENCES m_pub.photo ON UPDATE CASCADE,
  PRIMARY KEY (person_id, photo_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER person_photo_updated_at BEFORE UPDATE
  ON m_pub.person_photo
  FOR EACH ROW EXECUTE PROCEDURE m_pub.set_updated_at_column();

COMMENT ON TABLE m_pub.person_photo IS
  E'@omit create,update,delete,filter,all';

CREATE TABLE m_pub.task_photo (
  task_id BIGINT NOT NULL REFERENCES m_pub.task ON UPDATE CASCADE,
  photo_id BIGINT NOT NULL REFERENCES m_pub.photo ON UPDATE CASCADE,
  PRIMARY KEY (task_id, photo_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER task_photo_updated_at BEFORE UPDATE
  ON m_pub.task_photo
  FOR EACH ROW EXECUTE PROCEDURE m_pub.set_updated_at_column();

COMMENT ON TABLE m_pub.task_photo IS
  E'@omit create,update,delete,filter,all';

CREATE TABLE m_priv.person_account (
  person_id        BIGINT PRIMARY KEY REFERENCES m_pub.person ON UPDATE CASCADE,
  email            TEXT NOT NULL UNIQUE CHECK (email ~* '^.+@.+\..+$'),
  password_hash    TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER person_account_updated_at BEFORE UPDATE
  ON m_priv.person_account
  FOR EACH ROW EXECUTE PROCEDURE m_pub.set_updated_at_column();

COMMENT ON TABLE m_priv.person_account IS
  'Private information about a person’s account.';
COMMENT ON COLUMN m_priv.person_account.person_id IS
  'The id of the person associated with this account.';
COMMENT ON COLUMN m_priv.person_account.email IS
  'The email address of the person.';
COMMENT ON COLUMN m_priv.person_account.password_hash IS
  'An opaque hash of the person’s password.';

CREATE TABLE m_pub.company (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  phone_id BIGINT NOT NULL REFERENCES m_pub.phone ON UPDATE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER company_updated_at BEFORE UPDATE
  ON m_pub.company
  FOR EACH ROW EXECUTE PROCEDURE m_pub.set_updated_at_column();

COMMENT ON TABLE m_pub.company IS
  E'@omit create,update,delete,filter,all';

CREATE TABLE m_pub.company_person (
  company_id BIGINT NOT NULL REFERENCES m_pub.company ON UPDATE CASCADE,
  person_id BIGINT NOT NULL REFERENCES m_pub.person ON UPDATE CASCADE,
  PRIMARY KEY (company_id, person_id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER company_person_updated_at BEFORE UPDATE
  ON m_pub.company_person
  FOR EACH ROW EXECUTE PROCEDURE m_pub.set_updated_at_column();

COMMENT ON TABLE m_pub.company_person IS
  E'@omit create,update,delete,filter,all';

-- auth functions
CREATE FUNCTION m_pub.register_person(
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  password TEXT,
  is_client BOOLEAN DEFAULT FALSE
) RETURNS m_pub.person AS $$
DECLARE
  person m_pub.person;
BEGIN
  INSERT INTO m_pub.person (first_name, last_name, is_client) VALUES
    (first_name, last_name, is_client)
    RETURNING * INTO person;

  INSERT INTO m_priv.person_account (person_id, email, password_hash) VALUES
    (person.id, email, crypt(password, gen_salt('bf')));

  RETURN person;
END;
$$ LANGUAGE plpgsql strict security definer;

COMMENT ON FUNCTION m_pub.register_person(TEXT, TEXT, TEXT, TEXT, BOOLEAN) IS
  'Registers a single person and creates an account in our forum.';

CREATE ROLE  m_admin LOGIN PASSWORD 'voodoo3d';
CREATE ROLE m_visitor;
CREATE ROLE m_user;
GRANT m_visitor TO m_admin;
GRANT m_user TO m_admin;
GRANT USAGE ON SCHEMA m_pub TO m_visitor, m_user, m_admin;

CREATE TYPE m_pub.jwt_token AS (
  role TEXT,
  person_id BIGINT
);

CREATE FUNCTION m_pub.authenticate(
  email TEXT,
  password TEXT
) RETURNS m_pub.jwt_token AS $$
DECLARE
  account m_priv.person_account;
BEGIN
  SELECT a.* INTO account
  FROM m_priv.person_account AS a
  WHERE a.email = $1;

  IF account.password_hash = crypt(password, account.password_hash) THEN
    RETURN ('m_user', account.person_id)::m_pub.jwt_token;
  ELSE
    RETURN NULL;
  END IF;
END;
$$ LANGUAGE plpgsql STRICT SECURITY DEFINER;

COMMENT ON FUNCTION m_pub.authenticate(TEXT, TEXT) IS
  'Creates a JWT token that will securely identify a person and give them certain permissions.';

CREATE FUNCTION m_pub.current_person() RETURNS m_pub.person AS $$
  SELECT *
  FROM m_pub.person
  WHERE id = current_setting('jwt.claims.person_id', true)::BIGINT
$$ LANGUAGE SQL STABLE;

COMMENT ON FUNCTION m_pub.current_person() IS
  'Gets the person who was identified by our JWT.';

-- tasks functions
CREATE FUNCTION m_pub.tasks(
  latitude REAL,
  longitude REAL,
  task_types m_pub.task_type[],
  task_status m_pub.task_status DEFAULT 'opened'
) RETURNS SETOF m_pub.task AS $$
  DECLARE
   _latitude CONSTANT REAL := latitude;
   _longitude CONSTANT REAL := longitude;
   _task_types CONSTANT m_pub.task_type[] := task_types;
   _task_status CONSTANT m_pub.task_status := task_status;
  BEGIN
    RETURN QUERY
      SELECT *
      FROM m_pub.task
      WHERE m_pub.task.status = _task_status
      AND m_pub.task.category = ANY (_task_types)
      ORDER BY m_pub.task.geog <-> concat('SRID=4326;POINT(', _longitude, ' ', _latitude, ')');
  END;
$$ LANGUAGE plpgsql STRICT STABLE;

COMMENT ON FUNCTION m_pub.tasks(REAL, REAL, m_pub.task_type[], m_pub.task_status) IS
  'Gets the nearest open tasks given longitude latitude and task type ordered by distance';

CREATE FUNCTION m_pub.update_task(
  task_id BIGINT,
  new_task_status m_pub.task_status
) RETURNS m_pub.task AS $$
  DECLARE
    task m_pub.task;
    user_id CONSTANT BIGINT NOT NULL := current_setting('jwt.claims.person_id', true);
    current_task_status CONSTANT m_pub.task_status NOT NULL := (SELECT current_task.status FROM m_pub.task AS current_task WHERE current_task.id = task_id LIMIT 1);
    current_fulfiller_id CONSTANT BIGINT := (SELECT current_task.fulfiller_id FROM m_pub.task AS current_task WHERE current_task.id = task_id LIMIT 1);
    current_requester_id CONSTANT BIGINT := (SELECT current_task.requestor_id FROM m_pub.task AS current_task WHERE current_task.id = task_id LIMIT 1);
    is_client CONSTANT BOOLEAN NOT NULL := ((SELECT current_person.is_client FROM m_pub.person AS current_person WHERE current_person.id = user_id LIMIT 1) = FALSE);
    current_user_type CONSTANT m_pub.user_type NOT NULL := (SELECT
      CASE
        WHEN (current_requester_id = user_id) THEN 'requester'
        WHEN (current_fulfiller_id = user_id) THEN 'fulfiller'
        WHEN ((SELECT COUNT(*)
              FROM m_pub.task AS current_task
              WHERE current_task.fulfiller_id = user_id
              AND current_task.status != 'finished'
              AND current_task.status != 'closed') = 0
                AND is_client
              ) THEN 'open fulfiller'
        ELSE 'none'
      END
    );
    can_update CONSTANT BOOLEAN := ((SELECT permission.can_update_to
          FROM m_pub.task_permission AS permission
            WHERE permission.current_status = current_task_status
            AND permission.user_type = current_user_type
            LIMIT 1
       ) = new_task_status
    );
  BEGIN
      IF current_task_status = 'closed' OR current_task_status = 'finished' THEN
        RAISE 'You cannot modify a closed or finished task';
      ELSEIF can_update AND (current_user_type = 'requester' OR current_user_type = 'fulfiller') THEN
        UPDATE m_pub.task SET status = new_task_status
        WHERE id = task_id
        RETURNING * INTO task;
      ELSEIF can_update AND (current_user_type = 'open fulfiller') THEN
        UPDATE m_pub.task SET (status, fulfiller_id) = (new_task_status, user_id)
        WHERE id = task_id
        RETURNING * INTO task;
      ELSE
        RAISE 'You do not have the required permission to do this update';
      END IF;
      RETURN task;
  END;
$$ LANGUAGE plpgsql STRICT SECURITY INVOKER;

COMMENT ON FUNCTION m_pub.update_task(BIGINT,m_pub.task_status) IS
  'Update task status depending on permissions';

CREATE FUNCTION m_pub.add_client_review(
  new_task_id BIGINT,
  new_rating SMALLINT
) RETURNS m_pub.task AS $$
  DECLARE
    task m_pub.task;
    user_id CONSTANT BIGINT NOT NULL := current_setting('jwt.claims.person_id', true);
    current_fulfiller_id CONSTANT BIGINT := (SELECT current_task.fulfiller_id FROM m_pub.task AS current_task WHERE current_task.id = new_task_id LIMIT 1);
    current_requester_id CONSTANT BIGINT := (SELECT current_task.requestor_id FROM m_pub.task AS current_task WHERE current_task.id = new_task_id LIMIT 1);
    current_task_status CONSTANT m_pub.task_status NOT NULL := (SELECT current_task.status FROM m_pub.task AS current_task WHERE current_task.id = new_task_id LIMIT 1);
    not_reviewed CONSTANT BOOLEAN NOT NULL := (SELECT COUNT(*) FROM m_pub.rating AS rating WHERE rating.task_id = new_task_id AND rating.person_id = current_requester_id) = 0;
    can_submit_review BOOLEAN NOT NULL := (
      (current_fulfiller_id = user_id) AND
      (current_task_status = 'finished') AND
      not_reviewed
    );
  BEGIN
    IF can_submit_review THEN
      INSERT INTO m_pub.rating (rating, person_id, task_id) VALUES
      (new_rating, current_requester_id, new_task_id);

      SELECT * INTO task FROM m_pub.task WHERE id = new_task_id;
    ELSE
      RAISE 'no permission to update';
    END IF;
    RETURN task;
  END;
$$ LANGUAGE plpgsql STRICT SECURITY INVOKER VOLATILE;

COMMENT ON FUNCTION m_pub.add_client_review(BIGINT,SMALLINT) IS
  'Add reviews to requester of the task based on permissions';

CREATE FUNCTION m_pub.add_task_review(
  new_task_id BIGINT,
  new_rating SMALLINT
) RETURNS m_pub.task AS $$
  DECLARE
    task m_pub.task;
    user_id CONSTANT BIGINT NOT NULL := current_setting('jwt.claims.person_id', true);
    current_fulfiller_id CONSTANT BIGINT := (SELECT current_task.fulfiller_id FROM m_pub.task AS current_task WHERE current_task.id = new_task_id LIMIT 1);
    current_requester_id CONSTANT BIGINT := (SELECT current_task.requestor_id FROM m_pub.task AS current_task WHERE current_task.id = new_task_id LIMIT 1);
    current_task_status CONSTANT m_pub.task_status NOT NULL := (SELECT current_task.status FROM m_pub.task AS current_task WHERE current_task.id = new_task_id LIMIT 1);
    not_reviewed CONSTANT BOOLEAN NOT NULL := (SELECT COUNT(*) FROM m_pub.rating AS rating WHERE rating.task_id = new_task_id AND rating.person_id = current_fulfiller_id) = 0;
    can_submit_review BOOLEAN NOT NULL := (
      (current_requester_id = user_id) AND
      (current_task_status = 'finished') AND
      not_reviewed
    );
  BEGIN
    IF can_submit_review THEN
      INSERT INTO m_pub.rating (rating, person_id, task_id) VALUES
      (new_rating, current_fulfiller_id, new_task_id);

      SELECT * INTO task FROM m_pub.task WHERE id = new_task_id;
    ELSE
      RAISE 'no permission to update';
    END IF;
    RETURN task;
  END;
$$ LANGUAGE plpgsql STRICT SECURITY INVOKER VOLATILE;

COMMENT ON FUNCTION m_pub.add_task_review(BIGINT,SMALLINT) IS
  'Add reviews to the task based on permissions';

CREATE FUNCTION m_pub.person_rating(p m_pub.person)
RETURNS NUMERIC AS $$
  SELECT AVG(rating) FROM m_pub.rating WHERE person_id = p.id;
$$ LANGUAGE SQL STABLE;

COMMENT ON FUNCTION m_pub.person_rating(m_pub.person) IS
  'average review of this person';

-- permissions
GRANT EXECUTE ON FUNCTION m_pub.tasks(REAL, REAL, m_pub.task_type[], m_pub.task_status) TO m_user;
GRANT EXECUTE ON FUNCTION m_pub.update_task(BIGINT,m_pub.task_status) TO m_user;
GRANT EXECUTE ON FUNCTION m_pub.add_task_review(BIGINT,SMALLINT) TO m_user;
GRANT EXECUTE ON FUNCTION m_pub.add_client_review(BIGINT,SMALLINT) TO m_user;
GRANT EXECUTE ON FUNCTION m_pub.person_rating(m_pub.person) TO m_user, m_visitor;

GRANT EXECUTE ON FUNCTION m_pub.authenticate(TEXT, TEXT) TO m_visitor, m_user;
GRANT EXECUTE ON FUNCTION m_pub.current_person() TO m_visitor, m_user;
GRANT EXECUTE ON FUNCTION m_pub.register_person(TEXT, TEXT, TEXT, TEXT, BOOLEAN) TO m_visitor;

GRANT USAGE ON SEQUENCE m_pub.person_id_seq TO m_user;
GRANT USAGE ON SEQUENCE m_pub.phone_id_seq TO m_user;
GRANT USAGE ON SEQUENCE m_pub.photo_id_seq TO m_user;
GRANT USAGE ON SEQUENCE m_pub.task_id_seq TO m_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.person TO m_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.rating TO m_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.phone TO m_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.photo TO m_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.task TO m_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.task_detail TO m_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.person_photo TO m_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.task_photo TO m_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE m_pub.task_permission TO m_admin;

GRANT SELECT ON TABLE m_pub.person TO m_visitor, m_user;
GRANT SELECT ON TABLE m_pub.rating TO m_visitor, m_user;
GRANT SELECT ON TABLE m_pub.phone TO m_user;
GRANT SELECT ON TABLE m_pub.photo TO m_user;
GRANT SELECT ON TABLE m_pub.task TO m_user;
GRANT SELECT ON TABLE m_pub.task_detail TO m_user;
GRANT SELECT ON TABLE m_pub.person_photo TO m_user;
GRANT SELECT ON TABLE m_pub.task_photo TO m_user;
GRANT SELECT ON TABLE m_pub.task_permission TO m_user;

GRANT UPDATE, DELETE ON TABLE m_pub.person TO m_user;
GRANT INSERT, UPDATE, DELETE ON TABLE m_pub.rating TO m_user;
GRANT INSERT, UPDATE ON TABLE m_pub.phone TO m_user;
GRANT INSERT, UPDATE ON TABLE m_pub.photo TO m_user;
GRANT INSERT ON TABLE m_pub.task TO m_user;
GRANT UPDATE (status, fulfiller_id, longitude, latitude, scheduled_for, geog, updated_at) ON TABLE m_pub.task TO m_user;
GRANT INSERT, UPDATE ON TABLE m_pub.task_detail TO m_user;
GRANT INSERT, UPDATE ON TABLE m_pub.person_photo TO m_user;
GRANT INSERT, UPDATE ON TABLE m_pub.task_photo TO m_user;

-- person permission
ALTER TABLE m_pub.person ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_person ON m_pub.person FOR SELECT TO m_user, m_visitor
  USING (true);
CREATE POLICY update_person ON m_pub.person FOR UPDATE TO m_user
  USING (id = current_setting('jwt.claims.person_id', true)::BIGINT);
CREATE POLICY delete_person ON m_pub.person FOR DELETE TO m_user
  USING (id = current_setting('jwt.claims.person_id', true)::BIGINT);

-- task permissions
ALTER TABLE m_pub.task ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_task ON m_pub.task FOR SELECT TO m_user, m_visitor
  USING (true);
CREATE POLICY insert_task ON m_pub.task FOR INSERT TO m_user
  WITH CHECK ((SELECT is_client FROM m_pub.person WHERE id = current_setting('jwt.claims.person_id', true)::BIGINT) = TRUE);
CREATE POLICY update_task ON m_pub.task FOR UPDATE TO m_user
  USING (
    requestor_id = current_setting('jwt.claims.person_id', true)::BIGINT OR
    fulfiller_id = current_setting('jwt.claims.person_id', true)::BIGINT OR
    (SELECT
      (SELECT COUNT(*) FROM m_pub.task AS t
              WHERE t.fulfiller_id = current_setting('jwt.claims.person_id', true)::BIGINT
                AND t.status != 'finished'
      ) = 0
      AND (SELECT (SELECT current_person.is_client FROM m_pub.person AS current_person WHERE current_person.id = current_setting('jwt.claims.person_id', true)::BIGINT) = FALSE)
    )
  );

CREATE POLICY delete_task ON m_pub.task FOR DELETE TO m_user
  USING (false);


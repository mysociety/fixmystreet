-- schema.sql:
-- Schema for FixMyStreet database.
--
-- Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
-- Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
--

-- secret
-- A random secret.
create table secret (
    secret text not null
);

-- table for sessions - needed by Catalyst::Plugin::Session::Store::DBIC
create table sessions (
    id           char(72) primary key,
    session_data text,
    expires      integer
);

-- users table
create table users (
    id              serial  not null primary key,
    email           text,
    email_verified  boolean not null default 'f',
    name            text,
    phone           text,
    phone_verified  boolean not null default 'f',
    password        text    not null default '',
    from_body       integer,
    flagged         boolean not null default 'f',
    is_superuser    boolean not null default 'f',
    created         timestamp not null default current_timestamp,
    last_active     timestamp not null default current_timestamp,
    title           text,
    twitter_id      bigint  unique,
    facebook_id     bigint  unique,
    oidc_ids        text    ARRAY,
    area_ids        integer ARRAY,
    extra           text
);
CREATE UNIQUE INDEX users_email_verified_unique ON users (email) WHERE email_verified;
CREATE UNIQUE INDEX users_phone_verified_unique ON users (phone) WHERE phone_verified;

-- Record details of reporting bodies, including open311 configuration details
create table body (
    id           serial primary key,
    name         text not null,
    external_url text,
    parent       integer references body(id),
    endpoint     text,
    jurisdiction text,
    api_key      text,
    send_method  text,
    send_comments boolean not null default 'f',
    comment_user_id int references users(id),
    suppress_alerts boolean not null default 'f',
    can_be_devolved boolean not null default 'f',
    send_extended_statuses boolean not null default 'f',
    fetch_problems boolean not null default 'f',
    blank_updates_permitted boolean not null default 'f',
    convert_latlong boolean not null default 'f',
    deleted boolean not null default 'f',
    extra           text
);

create table body_areas (
    body_id integer not null references body(id),
    area_id integer not null
);
create unique index body_areas_body_id_area_id_idx on body_areas(body_id, area_id);

-- Now can create reference from users to body
ALTER TABLE users ADD CONSTRAINT users_from_body_fkey
    FOREIGN KEY (from_body) REFERENCES body(id);

-- roles table
create table roles (
    id              serial  not null primary key,
    body_id         integer not null references body(id) ON DELETE CASCADE,
    name            text,
    permissions     text ARRAY,
    unique(body_id, name)
);

-- Record which role(s) each user holds
create table user_roles (
    id              serial  not null primary key,
    role_id         integer not null references roles(id) ON DELETE CASCADE,
    user_id         integer not null references users(id) ON DELETE CASCADE
);

-- The contact for a category within a particular body
create table contacts (
    id serial primary key,
    body_id integer not null references body(id),
    category text not null default 'Other',
    email text not null,
    state text not null check (
        state = 'unconfirmed'
        or state = 'confirmed'
        or state = 'inactive'
        or state = 'deleted'
    ),

    -- last editor
    editor text not null,
    -- time of last change
    whenedited timestamp not null, 
    -- what the last change was for: author's notes
    note text not null,

    -- extra fields required for open311
    extra text,

    -- for things like missed bin collections
    non_public boolean default 'f',

    -- per contact endpoint configuration
    endpoint     text,
    jurisdiction text default '',
    api_key      text default '',
    send_method  text
);
create unique index contacts_body_id_category_idx on contacts(body_id, category);

-- History of changes to contacts - automatically updated
-- whenever contacts is changed, using trigger below.
create table contacts_history (
    contacts_history_id serial not null primary key,

    contact_id integer not null,
    body_id integer not null,
    category text not null default 'Other',
    email text not null,
    state text not null check (
        state = 'unconfirmed'
        or state = 'confirmed'
        or state = 'inactive'
        or state = 'deleted'
    ),

    -- editor
    editor text not null,
    -- time of entry
    whenedited timestamp not null, 
    -- what the change was for: author's notes
    note text not null
);

-- Create a trigger to update the contacts history on any update
-- to the contacts table. 
create function contacts_updated()
    returns trigger as '
    begin
        insert into contacts_history (contact_id, body_id, category, email, editor, whenedited, note, state) values (new.id, new.body_id, new.category, new.email, new.editor, new.whenedited, new.note, new.state);
        return new;
    end;
' language 'plpgsql';

create trigger contacts_update_trigger after update on contacts
    for each row execute procedure contacts_updated();
create trigger contacts_insert_trigger after insert on contacts
    for each row execute procedure contacts_updated();

-- Problems can have priorities. This table must be created before problem.
CREATE TABLE response_priorities (
    id serial not null primary key,
    body_id int references body(id) not null,
    deleted boolean not null default 'f',
    name text not null,
    description text,
    external_id text,
    is_default boolean not null default 'f',
    unique(body_id, name)
);

-- Problems reported by users of site
create table problem (
    id serial not null primary key,

    -- Problem details
    postcode text not null,
    latitude double precision not null,
    longitude double precision not null,
    bodies_str text, -- the body(s) we'll report this problem to
    bodies_missing text, -- the body(s) we had no contact details for
    areas text not null, -- the mapit areas this location is in
    category text not null default 'Other',
    title text not null,
    detail text not null,
    photo bytea,
    used_map boolean not null,

    -- User's details
    user_id int references users(id) not null,    
    name text not null,
    anonymous boolean not null,

    -- External information
    external_id text,
    external_body text,
    external_team text,

    -- Metadata
    created timestamp not null default current_timestamp,
    confirmed timestamp,
    state text not null,
    lang text not null default 'en-gb',
    service text not null default '',
    cobrand text not null default '' check (cobrand ~* '^[a-z0-9_]*$'),
    cobrand_data text not null default '' check (cobrand_data ~* '^[a-z0-9_]*$'), -- Extra data used in cobranded versions of the site
    lastupdate timestamp not null default current_timestamp,
    whensent timestamp,
    send_questionnaire boolean not null default 't',
    extra text, -- extra fields required for open311
    flagged boolean not null default 'f',
    geocode bytea,
    response_priority_id int REFERENCES response_priorities(id),

    -- logging sending failures (used by webservices)
    send_fail_count integer not null default 0, 
    send_fail_reason text, 
    send_fail_timestamp timestamp,
    
    -- record send_method used, which can be used to infer usefulness of external_id
    send_method_used text,

    -- for things like missed bin collections
    non_public BOOLEAN default 'f',

    -- record details about messages from external sources, eg. message manager
    external_source text,
    external_source_id text,

    -- number of me toos
    interest_count integer default 0,

    -- subcategory to enable filtering in reporting --
    subcategory text
);
create index problem_state_latitude_longitude_idx on problem(state, latitude, longitude);
create index problem_user_id_idx on problem ( user_id );
create index problem_external_body_idx on problem(lower(external_body));
create index problem_radians_latitude_longitude_idx on problem(radians(latitude), radians(longitude));
create index problem_bodies_str_array_idx on problem USING gin(regexp_split_to_array(bodies_str, ','));

create table questionnaire (
    id serial not null primary key,
    problem_id integer not null references problem(id),
    whensent timestamp not null,
    whenanswered timestamp,

    -- whether have ever previously reported a problem to a council or not
    ever_reported boolean,
    -- problem state before and after questionnaire
    old_state text,
    new_state text
);

create index questionnaire_problem_id_idx on questionnaire using btree (problem_id);

-- R_e
-- Radius of the earth, in km. This is something like 6372.8 km:
--  http://en.wikipedia.org/wiki/Earth_radius
create function R_e()
    returns double precision as '
select 6372.8::double precision;
' language sql immutable;

create type problem_nearby_match as (
    problem_id integer,
    distance double precision   -- km
);

-- problem_find_nearby LATITUDE LONGITUDE DISTANCE
-- Find locations within DISTANCE (km) of (LATITUDE, LONGITUDE).
create function problem_find_nearby(double precision, double precision, double precision)
    returns setof problem_nearby_match as
    -- Write as SQL function so that we don't have to construct a temporary
    -- table or results set in memory. That means we can't check the values of
    -- the parameters, sadly.
    -- Through sheer laziness, just use great-circle distance; that'll be off
    -- by ~0.1%.
    -- We index locations on lat/lon so that we can select the locations which lie
    -- within a wedge of side about 2 * DISTANCE. That cuts down substantially
    -- on the amount of work we have to do.
    -- http://janmatuschek.de/LatitudeLongitudeBoundingCoordinates
'
    -- trunc due to inaccuracies in floating point arithmetic
    select problem.id,
           R_e() * acos(trunc(
                (sin(radians($1)) * sin(radians(latitude))
                + cos(radians($1)) * cos(radians(latitude))
                    * cos(radians($2 - longitude)))::numeric, 14)
            ) as distance
        from problem
        where
            longitude is not null and latitude is not null
            and radians(latitude) > radians($1) - ($3 / R_e())
            and radians(latitude) < radians($1) + ($3 / R_e())
            and (
                abs(radians($1)) + ($3 / R_e()) > pi() / 2     -- case where search pt is near pole
                or (
                        radians(longitude) > radians($2) - asin(sin($3 / R_e())/cos(radians($1)))
                    and radians(longitude) < radians($2) + asin(sin($3 / R_e())/cos(radians($1)))
                )
            )
            -- ugly -- unable to use attribute name "distance" here, sadly
            and R_e() * acos(trunc(
                (sin(radians($1)) * sin(radians(latitude))
                + cos(radians($1)) * cos(radians(latitude))
                    * cos(radians($2 - longitude)))::numeric, 14)
                ) < $3
        order by distance desc
' language sql stable;


-- Comments/q&a on problems.
create table comment (
    id serial not null primary key,
    problem_id integer not null references problem(id),
    user_id int references users(id) not null,
    anonymous bool not null,
    name text, -- null means anonymous
    website text,
    created timestamp not null default current_timestamp,
    confirmed timestamp,
    text text not null,                     -- as entered by comment author
    photo bytea,
    state text not null check (
        state = 'unconfirmed'
        or state = 'confirmed'
        or state = 'hidden'
    ),
    cobrand text not null default '' check (cobrand ~* '^[a-z0-9_]*$'),
    lang text not null default 'en-gb',
    cobrand_data text not null default '' check (cobrand_data ~* '^[a-z0-9_]*$'), -- Extra data used in cobranded versions of the site
    mark_fixed boolean not null,
    mark_open boolean not null default 'f',
    problem_state text,
    -- other fields? one to indicate whether this was written by the council
    -- and should be highlighted in the display?
    external_id text,
    extra text,
    send_fail_count integer not null default 0,
    send_fail_reason text,
    send_fail_timestamp timestamp,
    whensent timestamp
);

create index comment_user_id_idx on comment(user_id);
create index comment_problem_id_idx on comment(problem_id);
create index comment_problem_id_created_idx on comment(problem_id, created);

-- Tokens for confirmations
create table token (
    scope text not null,
    token text not null,
    data bytea not null,
    created timestamp not null default current_timestamp,
    primary key (scope, token)
);

-- Alerts

create table alert_type (
    ref text not null primary key,
    head_sql_query text not null,
    head_table text not null,
    head_title text not null,
    head_link text not null,
    head_description text not null,
    item_table text not null,
    item_where text not null,
    item_order text not null,
    item_title text not null,
    item_link text not null,
    item_description text not null,
    template text not null
);

create table alert (
    id serial not null primary key,
    alert_type text not null references alert_type(ref),
    parameter text, -- e.g. Problem ID for new updates, Longitude for local problem alerts
    parameter2 text, -- e.g. Latitude for local problem alerts
    user_id int references users(id) not null,
    confirmed integer not null default 0,
    lang text not null default 'en-gb',
    cobrand text not null default '' check (cobrand ~* '^[a-z0-9_]*$'),
    cobrand_data text not null default '' check (cobrand_data ~* '^[a-z0-9_]*$'), -- Extra data used in cobranded versions of the site
    whensubscribed timestamp not null default current_timestamp,
    whendisabled timestamp default null
);
create index alert_user_id_idx on alert ( user_id );
create index alert_alert_type_confirmed_whendisabled_idx on alert(alert_type, confirmed, whendisabled);
create index alert_whendisabled_cobrand_idx on alert(whendisabled, cobrand);
create index alert_whensubscribed_confirmed_cobrand_idx on alert(whensubscribed, confirmed, cobrand);
-- Possible indexes - unique (alert_type,user_id,parameter)

create table alert_sent (
    alert_id integer not null references alert(id),
    parameter text, -- e.g. Update ID for new updates
    whenqueued timestamp not null default current_timestamp
);
create index alert_sent_alert_id_parameter_idx on alert_sent(alert_id, parameter);

-- To record details of people who submit via Flickr/ iPhone/ etc.
create table partial_user (
    id serial not null primary key,
    service text not null,
    nsid text not null,
    name text not null,
    email text not null,
    phone text not null
);
create index partial_user_service_email_idx on partial_user(service, email);

-- Record imported Flickr photos so we don't fetch them twice
create table flickr_imported (
    id text not null,
    problem_id integer not null references problem(id)
);
create unique index flickr_imported_id_idx on flickr_imported(id);

create table abuse (
    email text primary key check( lower(email) = email )
);

create table textmystreet (
    name text not null,
    email text not null,
    postcode text not null,
    mobile text not null
);

-- Record basic information about edits made through the admin interface

create table admin_log (
    id serial not null primary key, 
    admin_user text not null,
    object_type text not null check (
      object_type = 'problem'
      or object_type = 'update'
      or object_type = 'user'
      or object_type = 'moderation'
      or object_type = 'template'
      or object_type = 'body'
      or object_type = 'category'
      or object_type = 'role'
      or object_type = 'manifesttheme'
    ),
    object_id integer not null,
    action text not null,
    whenedited timestamp not null default current_timestamp,
    user_id int references users(id) null,
    reason text not null default '',
    time_spent int not null default 0
); 

create table moderation_original_data (
    id serial not null primary key,

    -- Problem details
    problem_id int references problem(id) ON DELETE CASCADE not null,
    comment_id int references comment(id) ON DELETE CASCADE,

    title text null,
    detail text null, -- or text for comment
    photo bytea,
    anonymous bool not null,

    -- Metadata
    created timestamp not null default current_timestamp,

    extra text,
    category text,
    latitude double precision,
    longitude double precision
);
create index moderation_original_data_problem_id_comment_id_idx on moderation_original_data(problem_id, comment_id);

create table user_body_permissions (
    id serial not null primary key,
    user_id int references users(id) not null,
    body_id int references body(id) not null,
    permission_type text not null,
    unique(user_id, body_id, permission_type)
);

create table user_planned_reports (
    id serial not null primary key,
    user_id int references users(id) not null,
    report_id int references problem(id) not null,
    added timestamp not null default current_timestamp,
    removed timestamp
);

create table response_templates (
    id serial not null primary key,
    body_id int references body(id) not null,
    title text not null,
    text text not null,
    created timestamp not null default current_timestamp,
    auto_response boolean NOT NULL DEFAULT 'f',
    state text,
    external_status_code text,
    unique(body_id, title)
);

CREATE TABLE contact_response_templates (
    id serial NOT NULL PRIMARY KEY,
    contact_id int REFERENCES contacts(id) NOT NULL,
    response_template_id int REFERENCES response_templates(id) NOT NULL
);

CREATE TABLE contact_response_priorities (
    id serial NOT NULL PRIMARY KEY,
    contact_id int REFERENCES contacts(id) NOT NULL,
    response_priority_id int REFERENCES response_priorities(id) NOT NULL
);

CREATE TABLE defect_types (
    id serial not null primary key,
    body_id int references body(id) not null,
    name text not null,
    description text not null,
    extra text,
    unique(body_id, name)
);

CREATE TABLE contact_defect_types (
    id serial NOT NULL PRIMARY KEY,
    contact_id int REFERENCES contacts(id) NOT NULL,
    defect_type_id int REFERENCES defect_types(id) NOT NULL
);

ALTER TABLE problem
    ADD COLUMN defect_type_id int REFERENCES defect_types(id);

CREATE TABLE translation (
    id serial not null primary key,
    tbl text not null,
    object_id integer not null,
    col text not null,
    lang text not null,
    msgstr text not null,
    unique(tbl, object_id, col, lang)
);

CREATE TABLE report_extra_fields (
    id serial not null primary key,
    name text not null,
    cobrand text,
    language text,
    extra text
);

CREATE TABLE state (
    id serial not null primary key,
    label text not null unique,
    type text not null check (type = 'open' OR type = 'closed' OR type = 'fixed'),
    name text not null unique
);

CREATE TABLE manifest_theme (
    id serial not null primary key,
    cobrand text not null unique,
    name text not null,
    short_name text not null,
    background_colour text,
    theme_colour text,
    images text ARRAY
);

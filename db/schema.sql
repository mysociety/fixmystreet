-- schema.sql:
-- Schema for FixMyStreet database.
--
-- Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
-- Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
--
-- $Id: schema.sql,v 1.49 2009-11-10 13:53:33 louise Exp $
--

-- secret
-- A random secret.
create table secret (
    secret text not null
);

-- If a row is present, that is date which is "today".  Used for debugging
-- to advance time without having to wait.
create table debugdate (
    override_today date
);

-- Returns the date of "today", which can be overriden for testing.
create function ms_current_date()
    returns date as '
    declare
        today date;
    begin
        today = (select override_today from debugdate);
        if today is not null then
           return today;
        else
           return current_date;
        end if;

    end;
' language 'plpgsql' stable;

-- Returns the timestamp of current time, but with possibly overriden "today".
create function ms_current_timestamp()
    returns timestamp as '
    declare
        today date;
    begin
        today = (select override_today from debugdate);
        if today is not null then
           return today + current_time;
        else
           return current_timestamp;
        end if;
    end;
' language 'plpgsql';


-- users, but call the table person rather than user so we don't have to quote
-- its name in every statement....
-- create table person (
--     id serial not null primary key,
--     name text,
--     email text not null,
--     password text,
--     website text,
--     numlogins integer not null default 0
-- );
-- 
-- create unique index person_email_idx on person(email);

-- Who to send problems for a specific MaPit area ID to
create table contacts (
    id serial primary key,
    area_id integer not null,
    category text not null default 'Other',
    email text not null,
    confirmed boolean not null,
    deleted boolean not null,

    -- last editor
    editor text not null,
    -- time of last change
    whenedited timestamp not null, 
    -- what the last change was for: author's notes
    note text not null
);
create unique index contacts_area_id_category_idx on contacts(area_id, category);

-- History of changes to contacts - automatically updated
-- whenever contacts is changed, using trigger below.
create table contacts_history (
    contacts_history_id serial not null primary key,

    contact_id integer not null,
    area_id integer not null,
    category text not null default 'Other',
    email text not null,
    confirmed boolean not null,
    deleted boolean not null,

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
        insert into contacts_history (contact_id, area_id, category, email, editor, whenedited, note, confirmed, deleted) values (new.id, new.area_id, new.category, new.email, new.editor, new.whenedited, new.note, new.confirmed, new.deleted);
        return new;
    end;
' language 'plpgsql';

create trigger contacts_update_trigger after update on contacts
    for each row execute procedure contacts_updated();
create trigger contacts_insert_trigger after insert on contacts
    for each row execute procedure contacts_updated();

-- table for sessions - needed by Catalyst::Plugin::Session::Store::DBIC
create table sessions (
    id           char(72) primary key,
    session_data text,
    expires      integer
);

-- users table
create table users (
    id              serial  not null primary key,
    email           text    not null unique,
    name            text,
    phone           text,
    password        text    not null default '',
    flagged         boolean not null default 'f'
);

-- Problems reported by users of site
create table problem (
    id serial not null primary key,

    -- Problem details
    postcode text not null,
    latitude double precision not null,
    longitude double precision not null,
    council text, -- the council(s) we'll report this problem to
    areas text not null, -- the voting areas this location is in
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
    created timestamp not null default ms_current_timestamp(),
    confirmed timestamp,
    state text not null check (
        state = 'unconfirmed'
        or state = 'confirmed'
        or state = 'fixed'
        or state = 'hidden'
        or state = 'partial'
    ),
    lang text not null default 'en-gb',
    service text not null default '',
    cobrand text not null default '' check (cobrand ~* '^[a-z0-9]*$'), 
    cobrand_data text not null default '' check (cobrand_data ~* '^[a-z0-9]*$'), -- Extra data used in cobranded versions of the site
    lastupdate timestamp not null default ms_current_timestamp(),
    whensent timestamp,
    send_questionnaire boolean not null default 't',
    flagged boolean not null default 'f'
);
create index problem_state_latitude_longitude_idx on problem(state, latitude, longitude);
create index problem_user_id_idx on problem ( user_id );

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

-- angle_between A1 A2
-- Given two angles A1 and A2 on a circle expressed in radians, return the
-- smallest angle between them.
create function angle_between(double precision, double precision)
    returns double precision as '
select case
    when abs($1 - $2) > pi() then 2 * pi() - abs($1 - $2)
    else abs($1 - $2)
    end;
' language sql immutable;

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
    -- by ~0.1%:
    --  http://www.ga.gov.au/nmd/geodesy/datums/distance.jsp
    -- We index locations on lat/lon so that we can select the locations which lie
    -- within a wedge of side about 2 * DISTANCE. That cuts down substantially
    -- on the amount of work we have to do.
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
            and (abs(radians($1)) + ($3 / R_e()) > pi() / 2     -- case where search pt is near pole
                    or angle_between(radians(longitude), radians($2))
                            < $3 / (R_e() * cos(radians($1 + $3 / R_e()))))
            -- ugly -- unable to use attribute name "distance" here, sadly
            and R_e() * acos(trunc(
                (sin(radians($1)) * sin(radians(latitude))
                + cos(radians($1)) * cos(radians(latitude))
                    * cos(radians($2 - longitude)))::numeric, 14)
                ) < $3
        order by distance desc
' language sql; -- should be "stable" rather than volatile per default?


-- Comments/q&a on problems.
create table comment (
    id serial not null primary key,
    problem_id integer not null references problem(id),
    user_id int references users(id) not null,
    anonymous bool not null,
    name text, -- null means anonymous
    website text,
    created timestamp not null default ms_current_timestamp(),
    confirmed timestamp,
    text text not null,                     -- as entered by comment author
    photo bytea,
    state text not null check (
        state = 'unconfirmed'
        or state = 'confirmed'
        or state = 'hidden'
    ),
    cobrand text not null default '' check (cobrand ~* '^[a-z0-9]*$'), 
    lang text not null default 'en-gb',
    cobrand_data text not null default '' check (cobrand_data ~* '^[a-z0-9]*$'), -- Extra data used in cobranded versions of the site
    mark_fixed boolean not null,
    mark_open boolean not null default 'f'
    -- other fields? one to indicate whether this was written by the council
    -- and should be highlighted in the display?
);

create index comment_user_id_idx on comment(user_id);
create index comment_problem_id_idx on comment(problem_id);
create index comment_problem_id_created_idx on comment(problem_id, created);

-- Tokens for confirmations
create table token (
    scope text not null,
    token text not null,
    data bytea not null,
    created timestamp not null default ms_current_timestamp(),
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
    cobrand text not null default '' check (cobrand ~* '^[a-z0-9]*$'), 
    cobrand_data text not null default '' check (cobrand_data ~* '^[a-z0-9]*$'), -- Extra data used in cobranded versions of the site
    whensubscribed timestamp not null default ms_current_timestamp(),
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
    whenqueued timestamp not null default ms_current_timestamp()
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
    ),
    object_id integer not null,
    action text not null check (
        action = 'edit'
        or action = 'state_change' 
        or action = 'resend'),
    whenedited timestamp not null default ms_current_timestamp()
); 


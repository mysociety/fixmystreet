-- schema.sql:
-- Schema for Neighbourhood Fix-It database.
--
-- Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
-- Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
--
-- $Id: schema.sql,v 1.23 2007-03-21 13:59:47 matthew Exp $
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
-- to the contacts table. This should cover manual edits only; anything else
-- (signers, comments, ...) should be covered by pledge_last_change_time or by
-- the individual implementing functions.
create function contacts_updated()
    returns trigger as '
    begin
        insert into contacts_history (area_id, category, email, editor, whenedited, note, confirmed, deleted) values (new.area_id, new.category, new.email, new.editor, new.whenedited, new.note, new.confirmed, new.deleted);
        return new;
    end;
' language 'plpgsql';

create trigger contacts_update_trigger after update on contacts
    for each row execute procedure contacts_updated();
create trigger contacts_insert_trigger after insert on contacts
    for each row execute procedure contacts_updated();

-- Problems reported by users of site
create table problem (
    id serial not null primary key,

    -- Problem details
    postcode text not null,
    easting double precision not null,
    northing double precision not null,
    council text, -- integer references contacts(area_id),
    category text not null default 'Other',
    title text not null,
    detail text not null,
    photo bytea,
    used_map boolean not null,

    -- User's details
    name text not null,
    email text not null,
    phone text not null,
    anonymous boolean not null,

    -- Metadata
    created timestamp not null default ms_current_timestamp(),
    state text not null check (
        state = 'unconfirmed'
        or state = 'confirmed'
        or state = 'fixed'
        or state = 'hidden'
    ),
    whensent timestamp
);
create index problem_state_easting_northing_idx on problem(state, easting, northing);

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

-- problem_find_nearby EASTING NORTHING DISTANCE
-- Find problems within DISTANCE (km) of (EASTING, NORTHING).
create function problem_find_nearby(double precision, double precision, double precision)
    returns setof problem_nearby_match as
    -- Write as SQL function so that we don't have to construct a temporary
    -- table or results set in memory. That means we can't check the values of
    -- the parameters, sadly.
'
    -- trunc due to inaccuracies in floating point arithmetic
    select problem.id,
           sqrt(($1 - easting) ^ 2
                + ($2 - northing) ^ 2)
            as distance
        from problem
        where
            -- ugly -- unable to use attribute name "distance" here, sadly
            sqrt(($1 - easting) ^ 2
                + ($2 - northing) ^ 2)
                < $3 * 1000
        order by distance desc
' language sql; -- should be "stable" rather than volatile per default?


-- Comments/q&a on problems.
create table comment (
    id serial not null primary key,
    problem_id integer not null references problem(id),
    name text not null,
    email text not null,
    website text,
    created timestamp not null default ms_current_timestamp(),
    text text not null,                     -- as entered by comment author
    state text not null check (
        state = 'unconfirmed'
        or state = 'confirmed'
        or state = 'hidden'
    ),
    mark_fixed boolean not null,
    mark_open boolean not null
    -- other fields? one to indicate whether this was written by the council
    -- and should be highlighted in the display?
);

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
    parameter text, -- e.g. Problem ID for new updates
    parameter2 text, -- e.g. Latitude for local problem alerts
    email text not null,
    confirmed integer not null default 0,
    whensubscribed timestamp not null default ms_current_timestamp(),
    whendisabled timestamp default null
);
-- Possible indexes - email, alert_type, whendisabled, unique (alert_type,email,parameter)

create table alert_sent (
    alert_id integer not null references alert(id),
    parameter text, -- e.g. Update ID for new updates
    whenqueued timestamp not null default ms_current_timestamp()
);


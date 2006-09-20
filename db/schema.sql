-- schema.sql:
-- Schema for Neighbourhood Fix-It database.
--
-- Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
-- Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
--
-- $Id: schema.sql,v 1.4 2006-09-20 16:56:54 francis Exp $
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
create table person (
    id serial not null primary key,
    name text,
    email text not null,
    password text,
    website text,
    numlogins integer not null default 0
);

create unique index person_email_idx on person(email);

-- categories in which problems can lie
-- create table category (
--     id serial not null primary key,
--     name text not null
-- );

-- Problems reported by users of site
create table problem (
    id serial not null primary key,
    postcode text not null,
    latitude double precision not null,
    longitude double precision not null,
    title text not null,
    detail text not null,
    -- category integer not null references category(id),
    person_id integer not null references person(id),
    created timestamp not null
);

-- Who to send problems for a specific MaPit area ID to
create table contacts (
    area_id integer not null,
    email text not null,

    -- last editor
    editor text not null,
    -- time of last change
    whenedited timestamp not null, 
    -- what the last change was for: author's notes
    note text not null
);

-- History of changes to contacts - automatically updated
-- whenever contacts is changed, using trigger below.
create table contacts_history (
    contacts_history_id serial not null primary key,

    area_id integer not null,
    email text not null,

    -- editor
    editor text not null,
    -- time of entry
    whenedited timestamp not null, 
    -- what the change was for: author's notes
    note text not null
);

-- Create a trigger to update the last-change-time for the pledge on any
-- update to the table. This should cover manual edits only; anything else
-- (signers, comments, ...) should be covered by pledge_last_change_time or by
-- the individual implementing functions.
create function contacts_updated()
    returns trigger as '
    begin
        insert into contacts_history (area_id, email, editor, whenedited, note) values (new.area_id, new.email, new.editor, new.whenedited, new.note);
        return new;
    end;
' language 'plpgsql';

create trigger contacts_update_trigger after update on contacts
    for each row execute procedure contacts_updated();
create trigger contacts_insert_trigger after insert on contacts
    for each row execute procedure contacts_updated();

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
-- Find problems within DISTANCE (km) of (LATITUDE, LONGITUDE).
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

    person_id integer references person(id),
    name text not null,

    website text,
    whenposted timestamp not null default ms_current_timestamp(),
    text text not null,                     -- as entered by comment author
    ishidden boolean not null default false -- hidden from view
    -- other fields? one to indicate whether this was written by the council
    -- and should be highlighted in the display?
);

create index comment_problem_id_idx on comment(problem_id);
create index comment_problem_id_whenposted_idx on comment(problem_id, whenposted);
create index comment_ishidden_idx on comment(ishidden);



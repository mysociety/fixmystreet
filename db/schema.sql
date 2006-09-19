-- schema.sql:
-- Schema for Neighbourhood Fix-It database.
--
-- Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
-- Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
--
-- $Id: schema.sql,v 1.1 2006-09-19 17:31:28 matthew Exp $
--

-- secret
-- A random secret.
create table secret (
    secret text not null
);

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
    email text not null
);

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


-- Messages sent to problem creators and councils, and commenters.  This is
-- used with message_creator_recipient and message_signer_recipient to make
-- sure that messages are sent exactly once.
create table message (
    id serial not null primary key,
    problem_id integer not null references problem(id),
    circumstance text not null,
    circumstance_count int not null default 0,
    whencreated timestamp not null default current_timestamp(),
    fromaddress text not null default 'bci'
        check (fromaddress in ('bci', 'creator')),

    -- content of message
    emailtemplatename text,
    emailsubject text,
    emailbody text,
);

create unique index message_problem_id_circumstance_idx on message(problem_id, circumstance, circumstance_count);

-- Comments/q&a on problems.
create table comment (
    id serial not null primary key,
    problem_id integer not null references problem(id),

    person_id integer references person(id),
    name text not null,

    website text,
    whenposted timestamp not null default current_timestamp(),
    text text not null,                     -- as entered by comment author
    ishidden boolean not null default false -- hidden from view
    -- other fields? one to indicate whether this was written by the council
    -- and should be highlighted in the display?
);

create index comment_problem_id_idx on comment(problem_id);
create index comment_problem_id_whenposted_idx on comment(problem_id, whenposted);
create index comment_ishidden_idx on comment(ishidden);

-- Alerts and notifications

-- get emailed when various events happen
create table alert (
    id serial not null primary key,
    person_id integer not null references person(id),
    event_code text not null,

    check (
            event_code = 'comments/problem' or    -- new comments on a particular problem
            event_code = 'problem/local'   -- new problem near a particular area
    ),

    -- extra parameters for different types of alert
    problem_id integer references problem(id), -- specific problem for ".../problem" event codes
    -- specific location for ".../local" event codes
    latitude double precision,
    longitude double precision,

    whensubscribed timestamp not null default current_timestamp(),
    whendisabled timestamp default null -- set if alert has been turned off
);

create index alert_person_id_idx on alert(person_id);
create index alert_event_code_idx on alert(event_code);
create index alert_problem_id_idx on alert(problem_id);
create index alert_whendisabled_idx on alert(whendisabled);
create unique index alert_unique_idx on alert(person_id, event_code, problem_id, latitude, longitude);

create table alert_sent (
    alert_id integer not null references alert(id),
    
    -- which pledge for event codes "pledges/"
    problem_id integer references problem(id),
    -- which comment for event code "/comments"
    comment_id integer references comment(id),

    whenqueued timestamp not null default current_timestamp()
);

create index alert_sent_alert_id_idx on alert_sent(alert_id);
create index alert_sent_problem_id_idx on alert_sent(problem_id);
create index alert_sent_comment_id_idx on alert_sent(comment_id);
create unique index alert_sent_problem_unique_idx on alert_sent(alert_id, problem_id);
create unique index alert_sent_comment_unique_idx on alert_sent(alert_id, comment_id);


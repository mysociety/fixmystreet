begin;

create index problem_radians_latitude_longitude_idx on problem(radians(latitude), radians(longitude));

drop function angle_between(double precision, double precision);

create or replace function problem_find_nearby(double precision, double precision, double precision)
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

commit;

-- New problems around a location
update alert_type set
    item_table='problem',
    item_where='ST_DWithin(ST_SetSRID(ST_Point(longitude, latitude), 4326)::geography, ST_SetSRID(ST_Point(?, ?), 4326)::geography, ?)
        and problem.non_public = ''f'' and problem.state NOT IN (''unconfirmed'', ''hidden'', ''partial'')',
    item_order='(extract(epoch from confirmed) <-> extract(epoch from ''3000-01-01''::date))'
where ref='local_problems';

-- New problems around a location
update alert_type set
    item_table='problem',
    item_where='ST_DWithin(ST_SetSRID(ST_Point(longitude, latitude), 4326)::geography, ST_SetSRID(ST_Point(?, ?), 4326)::geography, ?)
        and problem.non_public = ''f'' and problem.state IN (?)',
    item_order='(extract(epoch from confirmed) <-> extract(epoch from ''3000-01-01''::date))'
where ref='local_problems_state';

-- New problems around a postcode
update alert_type set
    item_table='problem',
    item_where='ST_DWithin(ST_SetSRID(ST_Point(longitude, latitude), 4326)::geography, ST_SetSRID(ST_Point(?, ?), 4326)::geography, ?)
        and problem.non_public = ''f'' and problem.state NOT IN (''unconfirmed'', ''hidden'', ''partial'')',
    item_order='(extract(epoch from confirmed) <-> extract(epoch from ''3000-01-01''::date))'
where ref='postcode_local_problems';

-- New problems around a postcode with a particular state
update alert_type set
    item_table='problem',
    item_where='ST_DWithin(ST_SetSRID(ST_Point(longitude, latitude), 4326)::geography, ST_SetSRID(ST_Point(?, ?), 4326)::geography, ?)
        and problem.non_public = ''f'' and problem.state IN (?)',
    item_order='(extract(epoch from confirmed) <-> extract(epoch from ''3000-01-01''::date))'
where ref='postcode_local_problems_state';

-- Index on problem to use these
CREATE INDEX problem_location_gist_idx ON problem USING gist ((st_setsrid(st_point(longitude, latitude), 4326)::geography), date_part('epoch'::text, confirmed));

begin;

alter table problem add bodies_missing text;

update problem
    set bodies_missing = split_part(bodies_str, '|', 2),
        bodies_str = split_part(bodies_str, '|', 1)
    where bodies_str like '%|%';

commit;

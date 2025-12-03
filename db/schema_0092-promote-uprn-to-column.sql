BEGIN;

ALTER TABLE problem ADD uprn text;

UPDATE problem
    SET uprn = jsonb_path_query_array(extra->'_fields', '$[*] ? (@.name == "uprn")')->0->>'value'
    WHERE jsonb_path_query_array(extra->'_fields', '$[*] ? (@.name == "uprn")')->0->>'value' != ''
        AND cobrand_data = 'waste';

CREATE INDEX problem_uprn_idx ON problem(uprn) WHERE uprn IS NOT NULL;

COMMIT;

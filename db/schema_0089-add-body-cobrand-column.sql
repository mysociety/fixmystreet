BEGIN;
ALTER TABLE body ADD cobrand TEXT;
CREATE INDEX body_cobrand_idx ON body(cobrand);
UPDATE body SET cobrand = extra->>'cobrand' WHERE extra->>'cobrand' != '';
UPDATE body SET extra = extra - 'cobrand';
COMMIT;

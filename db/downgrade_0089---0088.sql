UPDATE body SET extra = extra || jsonb_build_object('cobrand', cobrand) WHERE cobrand IS NOT NULL;
ALTER TABLE body DROP cobrand;

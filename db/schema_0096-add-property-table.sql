BEGIN;

CREATE TABLE property (
    uprn text not null primary key,
    discount_date date not null
);

COMMIT;


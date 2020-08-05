CREATE INDEX CONCURRENTLY users_fulltext_idx on users USING GIN(
    to_tsvector(
        'DB_FULL_TEXT_SEARCH_CONFIG',
        translate(id || ' ' || coalesce(name,'') || ' ' || coalesce(email,'') || ' ' || coalesce(phone,''), '@.', '  ')
    )
);

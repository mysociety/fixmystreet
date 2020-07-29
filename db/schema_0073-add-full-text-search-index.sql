CREATE INDEX CONCURRENTLY problem_fulltext_idx ON problem USING GIN(
    to_tsvector(
        'DB_FULL_TEXT_SEARCH_CONFIG',
        translate(id || ' ' || coalesce(external_id,'') || ' ' || coalesce(bodies_str,'') || ' ' || name || ' ' || title || ' ' || detail, '/.', '  ')
    )
);

CREATE INDEX CONCURRENTLY comment_fulltext_idx on comment USING GIN(
    to_tsvector(
        'DB_FULL_TEXT_SEARCH_CONFIG',
        translate(id || ' ' || problem_id || ' ' || coalesce(name,'') || ' ' || text, '/.', '  ')
    )
);

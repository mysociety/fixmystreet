CREATE INDEX concurrently problem_contributed_by_idx ON problem((extra->>'contributed_by')) WHERE extra->>'contributed_by' IS NOT NULL;

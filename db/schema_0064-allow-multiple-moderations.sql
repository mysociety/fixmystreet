BEGIN;

ALTER TABLE moderation_original_data
    DROP CONSTRAINT moderation_original_data_comment_id_key;
CREATE INDEX moderation_original_data_problem_id_comment_id_idx
    ON moderation_original_data(problem_id, comment_id);

COMMIT;

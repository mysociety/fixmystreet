BEGIN;

DROP INDEX moderation_original_data_problem_id_comment_id_idx;
ALTER TABLE moderation_original_data
    ADD CONSTRAINT moderation_original_data_comment_id_key UNIQUE (comment_id);

COMMIT;

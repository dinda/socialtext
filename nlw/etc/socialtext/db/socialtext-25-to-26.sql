BEGIN;

-- To accommodate workspace tags, we must permit page_id to be blank
ALTER TABLE page_tag DROP CONSTRAINT page_tag_workspace_id_page_id_fkey;
ALTER TABLE ONLY page_tag
    ADD CONSTRAINT page_tag_workspace_id_fkey
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace" (workspace_id) ON DELETE CASCADE;

-- Update schema version
UPDATE "System"
   SET value = '26'
 WHERE field = 'socialtext-schema-version';

COMMIT;

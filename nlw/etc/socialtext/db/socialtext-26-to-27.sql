BEGIN;

-- Create a WebHooks table
CREATE TABLE webhook (
    id bigint NOT NULL,
    workspace_id bigint,
    action text,
    page_id text
);

CREATE SEQUENCE "webhook___webhook_id"
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;

CREATE INDEX webhook__workspace_ix
        ON webhook (workspace_id);

CREATE INDEX webhook__workspace_action_ix
        ON webhook (workspace_id, action);

ALTER TABLE ONLY webhook
    ADD CONSTRAINT webhook_workspace_id_fk
            FOREIGN KEY (workspace_id)
            REFERENCES "Workspace"(workspace_id) ON DELETE CASCADE;

ALTER TABLE ONLY webhook
    ADD CONSTRAINT webhook_ukey
        UNIQUE (workspace_id, action, page_id);

-- No FK contstraint on page_id - it's not necessary that the page exists

-- Update schema version
UPDATE "System"
   SET value = '27'
 WHERE field = 'socialtext-schema-version';

COMMIT;

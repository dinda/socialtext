BEGIN;

CREATE INDEX storage_class_key_ix 
    ON storage (class, key);

CREATE INDEX storage_key_ix 
    ON storage (key);

CREATE INDEX storage_key_value_type_ix 
    ON storage (key, value)
    WHERE key = 'type';

CREATE INDEX storage_key_value_viewer_ix 
    ON storage (key, value)
    WHERE key = 'viewer';

UPDATE "System"
   SET value = 15
 WHERE field = 'socialtext-schema-version';

COMMIT;

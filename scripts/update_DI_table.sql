-- It is a requirement that the table pyramid_oereb_main.data_integration:
-- 1. EXISTS
-- 2. Has a UNIQUE constraint on the column theme_code:
-- ALTER TABLE pyramid_oereb_main.data_integration ADD UNIQUE (theme_code);

-- This only works with Postgresql 13 and later because of the function "gen_random_uuid"
-- INSERT INTO pyramid_oereb_main.data_integration (id, date, theme_code, office_id)
-- VALUES
--     (gen_random_uuid (), NOW(), :INPUT_LAYER, :OFFICE_ID)
-- ON CONFLICT (theme_code) DO UPDATE
-- SET date = NOW();


-- For Postgresql 12 and earlier add the following extension the following:
-- CREATE extension IF NOT EXISTS "uuid-ossp";
INSERT INTO pyramid_oereb_main.data_integration (id, date, theme_code, office_id)
VALUES
    (uuid_generate_v4(), NOW(), :INPUT_LAYER_ID, :OFFICE_ID)
ON CONFLICT (theme_code) DO UPDATE
SET date = NOW();

-- 1. craet schema pyramid_oereb main
DROP SCHEMA IF EXISTS pyramid_oereb_main ;

CREATE SCHEMA IF NOT EXISTS pyramid_oereb_main
    AUTHORIZATION "www-data";

-- 2. add table data_integration with unique constraint on theme
DROP TABLE IF EXISTS pyramid_oereb_main.data_integration;

CREATE TABLE IF NOT EXISTS pyramid_oereb_main.data_integration
(
    id character varying COLLATE pg_catalog."default" NOT NULL,
    date timestamp without time zone NOT NULL,
    theme_code character varying COLLATE pg_catalog."default" NOT NULL,
    office_id character varying COLLATE pg_catalog."default" NOT NULL,
    checksum character varying COLLATE pg_catalog."default",
    CONSTRAINT data_integration_pkey PRIMARY KEY (id),
    CONSTRAINT data_integration_theme_code_key UNIQUE (theme_code)
);

ALTER TABLE IF EXISTS pyramid_oereb_main.data_integration
    OWNER to "www-data";

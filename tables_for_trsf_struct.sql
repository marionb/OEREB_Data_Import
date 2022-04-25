--- datenintegration ---
--- NOTE: there is work in progress to move this table in to the main schema.
---       once this is done this script and the part of the code that calls it can be removed.

CREATE TABLE IF NOT EXISTS :schema.datenintegration
(
    t_id bigint NOT NULL,
    datum timestamp without time zone NOT NULL,
    amt bigint NOT NULL,
    checksum character varying COLLATE pg_catalog."default",
    CONSTRAINT datenintegration_pkey PRIMARY KEY (t_id),
    CONSTRAINT datenintegration_amt_fkey FOREIGN KEY (amt)
        REFERENCES :schema.amt (t_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE :schema.datenintegration
    OWNER to :user;

-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

CREATE TABLE IF NOT EXISTS "event_metadatas" (
    id bigint PRIMARY KEY,
    tenant_id bigint NOT NULL,
    system_id text,
    event_id text,
    host_email text,
    resource_calendar text,
    event_start bigint,
    event_end bigint,
    ext_data jsonb,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    ical_uid text,
    recurring_master_id text
);

CREATE SEQUENCE IF NOT EXISTS public.event_metadatas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.event_metadatas_id_seq OWNED BY "event_metadatas".id;
ALTER TABLE ONLY "event_metadatas" ALTER COLUMN id SET DEFAULT nextval('public.event_metadatas_id_seq'::regclass);
ALTER TABLE ONLY "event_metadatas"
    DROP CONSTRAINT IF EXISTS event_metadatas_tenant_id_fkey;

ALTER TABLE ONLY "event_metadatas"
    ADD CONSTRAINT event_metadatas_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES "tenants"(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS index_event_metadatas_created_at ON "event_metadatas" USING btree (created_at);
CREATE INDEX IF NOT EXISTS index_event_metadatas_event_id_idx ON "event_metadatas" USING btree (event_id);
CREATE INDEX IF NOT EXISTS index_event_metadatas_ical_uid_idx ON "event_metadatas" USING btree (ical_uid);
CREATE INDEX IF NOT EXISTS index_event_metadatas_system_id ON "event_metadatas" USING btree (system_id);
CREATE INDEX IF NOT EXISTS index_event_metadatas_tenant_id ON "event_metadatas" USING btree (tenant_id);
CREATE INDEX IF NOT EXISTS index_event_metadatas_updated_at ON "event_metadatas" USING btree (updated_at);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TABLE IF EXISTS "event_metadatas"
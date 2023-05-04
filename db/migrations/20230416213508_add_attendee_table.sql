-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
CREATE TABLE IF NOT EXISTS "attendees" (
    id bigint PRIMARY KEY,
    event_id bigint,
    guest_id bigint NOT NULL,
    tenant_id bigint NOT NULL,
    checked_in boolean DEFAULT false,
    visit_expected boolean DEFAULT true,
    booking_id bigint,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE SEQUENCE IF NOT EXISTS public.attendees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.attendees_id_seq OWNED BY "attendees".id;
ALTER TABLE ONLY "attendees" ALTER COLUMN id SET DEFAULT nextval('public.attendees_id_seq'::regclass);
CREATE INDEX IF NOT EXISTS index_attendees_created_at ON "attendees" USING btree (created_at);
CREATE INDEX IF NOT EXISTS index_attendees_event_id ON "attendees" USING btree (event_id);
CREATE INDEX IF NOT EXISTS index_attendees_guest_id ON "attendees" USING btree (guest_id);
CREATE INDEX IF NOT EXISTS index_attendees_tenant_id ON "attendees" USING btree (tenant_id);
CREATE INDEX IF NOT EXISTS index_attendees_updated_at ON "attendees" USING btree (updated_at);

 
ALTER TABLE ONLY "attendees"
    DROP CONSTRAINT IF EXISTS attendees_guest_id_fkey;
ALTER TABLE ONLY "attendees"
    ADD CONSTRAINT attendees_guest_id_fkey FOREIGN KEY (guest_id) REFERENCES "guests"(id) ON DELETE CASCADE;

ALTER TABLE ONLY "attendees"
    DROP CONSTRAINT IF EXISTS attendees_tenant_id_fkey;
ALTER TABLE ONLY "attendees"
    ADD CONSTRAINT attendees_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES "tenants"(id) ON DELETE CASCADE;

ALTER TABLE ONLY "attendees"
    DROP CONSTRAINT IF EXISTS attendees_event_id_fkey;    
ALTER TABLE ONLY "attendees"
    ADD CONSTRAINT attendees_event_id_fkey FOREIGN KEY (event_id) REFERENCES "event_metadatas"(id) ON DELETE CASCADE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TABLE IF EXISTS "attendees"
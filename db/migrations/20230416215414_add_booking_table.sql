-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
CREATE TABLE IF NOT EXISTS "bookings" (
    id bigint PRIMARY KEY,
    tenant_id bigint NOT NULL,
    user_id text,
    user_email text,
    user_name text,
    asset_id text,
    zones text[],
    booking_type text,
    booking_start bigint,
    booking_end bigint,
    timezone text,
    title text,
    description text,
    checked_in boolean DEFAULT false,
    rejected boolean DEFAULT false,
    approved boolean DEFAULT false,
    approver_id text,
    approver_email text,
    approver_name text,
    extension_data jsonb DEFAULT '{}'::jsonb,
    booked_by_id text,
    booked_by_email text,
    booked_by_name text,
    process_state text,
    last_changed bigint,
    created bigint,
    checked_in_at bigint,
    checked_out_at bigint,
    rejected_at bigint,
    approved_at bigint,
    booked_from text,
    email_digest text,
    booked_by_email_digest text,
    deleted_at bigint,
    deleted boolean DEFAULT false,
    history jsonb DEFAULT '[]'::jsonb,
    department text,
    event_id text,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL    
);

CREATE SEQUENCE IF NOT EXISTS public.bookings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.bookings_id_seq OWNED BY "bookings".id;
ALTER TABLE ONLY "bookings" ALTER COLUMN id SET DEFAULT nextval('public.bookings_id_seq'::regclass);
CREATE INDEX IF NOT EXISTS index_bookings_booking_email_digest_idx ON public.bookings USING btree (email_digest);
CREATE INDEX IF NOT EXISTS index_bookings_booking_start_end_idx ON public.bookings USING btree (booking_start, booking_end);
CREATE INDEX IF NOT EXISTS index_bookings_booking_user_id_idx ON public.bookings USING btree (user_id);
CREATE INDEX IF NOT EXISTS index_bookings_created_at ON public.bookings USING btree (created_at);
CREATE INDEX IF NOT EXISTS index_bookings_process_state_idx ON public.bookings USING btree (process_state);
CREATE INDEX IF NOT EXISTS index_bookings_tenant_id ON public.bookings USING btree (tenant_id);
CREATE INDEX IF NOT EXISTS index_bookings_updated_at ON public.bookings USING btree (updated_at);

ALTER TABLE ONLY "attendees"
    DROP CONSTRAINT IF EXISTS attendees_booking_id_fkey; 
ALTER TABLE ONLY "attendees"
    ADD CONSTRAINT attendees_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES "bookings"(id);

ALTER TABLE ONLY "bookings"
    DROP CONSTRAINT IF EXISTS bookings_tenant_id_fkey; 
ALTER TABLE ONLY "bookings"
    ADD CONSTRAINT bookings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES "tenants"(id) ON DELETE CASCADE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TABLE IF EXISTS "bookings"
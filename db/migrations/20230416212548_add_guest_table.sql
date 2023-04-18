-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
CREATE TABLE IF NOT EXISTS "guests" (
    id bigint PRIMARY KEY,
    tenant_id bigint NOT NULL,
    name text,
    email text ,
    preferred_name text,
    phone text,
    organisation text,
    notes text,
    photo text,
    banned boolean DEFAULT false,
    dangerous boolean DEFAULT false,
    searchable text,
    extension_data jsonb DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE SEQUENCE IF NOT EXISTS public.guests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.guests_id_seq OWNED BY "guests".id;
ALTER TABLE ONLY "guests" ALTER COLUMN id SET DEFAULT nextval('public.guests_id_seq'::regclass);
ALTER TABLE ONLY "guests"
    DROP CONSTRAINT IF EXISTS unique_email;
ALTER TABLE ONLY "guests" ADD CONSTRAINT unique_email UNIQUE (email, tenant_id);

ALTER TABLE ONLY "guests"
    DROP CONSTRAINT IF EXISTS guests_tenant_id_fkey;
ALTER TABLE ONLY "guests"
    ADD CONSTRAINT guests_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES "tenants"(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS guests_created_at ON public.guests USING btree (created_at);
CREATE INDEX IF NOT EXISTS guests_tenant_id ON public.guests USING btree (tenant_id);
CREATE INDEX IF NOT EXISTS guests_updated_at ON public.guests USING btree (updated_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_lower_unique_guests_email ON public.guests USING btree (lower(email), tenant_id);


-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TABLE IF EXISTS "guests"
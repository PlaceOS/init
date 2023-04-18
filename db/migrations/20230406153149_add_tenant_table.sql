-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
CREATE TABLE IF NOT EXISTS "tenants" (
    id bigint PRIMARY KEY,
    name text,
    domain text NOT NULL UNIQUE,
    platform text NOT NULL,
    credentials text NOT NULL,
    booking_limits jsonb DEFAULT '{}'::jsonb,
    delegated boolean DEFAULT false,
    service_account text,
    outlook_config jsonb DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL    
);

CREATE SEQUENCE IF NOT EXISTS public.tenants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.tenants_id_seq OWNED BY "tenants".id;
ALTER TABLE ONLY "tenants" ALTER COLUMN id SET DEFAULT nextval('public.tenants_id_seq'::regclass);
CREATE INDEX IF NOT EXISTS index_tenants_created_at ON "tenants" USING btree (created_at);
CREATE UNIQUE INDEX IF NOT EXISTS index_tenants_domain ON "tenants" USING btree (domain);
CREATE INDEX IF NOT EXISTS index_tenants_updated_at ON "tenants" USING btree (updated_at);

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TABLE IF EXISTS "tenants"

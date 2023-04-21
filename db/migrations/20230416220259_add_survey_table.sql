-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
-- +micrate StatementBegin
DO
$$
BEGIN
  IF NOT EXISTS (SELECT *
                        FROM pg_type typ
                             INNER JOIN pg_namespace nsp
                                        ON nsp.oid = typ.typnamespace
                        WHERE nsp.nspname = current_schema()
                              AND typ.typname = 'survey_trigger_type') THEN
    CREATE TYPE survey_trigger_type AS ENUM (
            'NONE',
            'RESERVED',
            'CHECKEDIN',
            'CHECKEDOUT',
            'NOSHOW',
            'REJECTED',
            'CANCELLED',
            'ENDED',
            'VISITOR_CHECKEDIN',
            'VISITOR_CHECKEDOUT'
        );
  END IF;
END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

CREATE TABLE IF NOT EXISTS "surveys" (
    id bigint PRIMARY KEY,
    title text,
    description text,
    trigger public.survey_trigger_type DEFAULT 'NONE'::public.survey_trigger_type,
    zone_id text,
    pages jsonb DEFAULT '[]'::jsonb,
    building_id text,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL     
);

CREATE SEQUENCE IF NOT EXISTS public.surveys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.surveys_id_seq OWNED BY "surveys".id;
ALTER TABLE ONLY "surveys" ALTER COLUMN id SET DEFAULT nextval('public.surveys_id_seq'::regclass);
CREATE INDEX IF NOT EXISTS index_surveys_created_at ON "surveys" USING btree (created_at);
CREATE INDEX IF NOT EXISTS index_surveys_updated_at ON "surveys" USING btree (updated_at);

CREATE TABLE IF NOT EXISTS "questions" (
    id bigint PRIMARY KEY,
    title text,
    description text,
    type text,
    options jsonb DEFAULT '{}'::jsonb,
    required boolean DEFAULT false,
    choices jsonb DEFAULT '{}'::jsonb,
    max_rating integer,
    tags text[] DEFAULT '{}'::text[],
    deleted_at bigint,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL       
);

CREATE SEQUENCE IF NOT EXISTS public.questions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.questions_id_seq OWNED BY "questions".id;
ALTER TABLE ONLY "questions" ALTER COLUMN id SET DEFAULT nextval('public.questions_id_seq'::regclass);
CREATE INDEX IF NOT EXISTS index_questions_created_at ON "questions" USING btree (created_at);
CREATE INDEX IF NOT EXISTS index_questions_updated_at ON "questions" USING btree (updated_at);


CREATE TABLE IF NOT EXISTS "answers" (
    id bigint PRIMARY KEY,
    question_id bigint NOT NULL,
    survey_id bigint NOT NULL,
    answer_json jsonb DEFAULT '{}'::jsonb,
    type text,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL     
);

CREATE SEQUENCE IF NOT EXISTS public.answers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.answers_id_seq OWNED BY "answers".id;
ALTER TABLE ONLY "answers" ALTER COLUMN id SET DEFAULT nextval('public.answers_id_seq'::regclass);
CREATE INDEX IF NOT EXISTS index_answers_created_at ON "answers" USING btree (created_at);
CREATE INDEX IF NOT EXISTS index_answers_question_id ON "answers" USING btree (question_id);
CREATE INDEX IF NOT EXISTS index_answers_survey_id ON "answers" USING btree (survey_id);
CREATE INDEX IF NOT EXISTS index_answers_updated_at ON "answers" USING btree (updated_at);
ALTER TABLE ONLY "answers"
    DROP CONSTRAINT IF EXISTS answers_question_id_fkey;
ALTER TABLE ONLY "answers"
    ADD CONSTRAINT answers_question_id_fkey FOREIGN KEY (question_id) REFERENCES "questions"(id) ON DELETE CASCADE;    

ALTER TABLE ONLY "answers"
    DROP CONSTRAINT IF EXISTS answers_survey_id_fkey;
ALTER TABLE ONLY "answers"
    ADD CONSTRAINT answers_survey_id_fkey FOREIGN KEY (survey_id) REFERENCES "surveys"(id) ON DELETE CASCADE;


CREATE TABLE IF NOT EXISTS "survey_invitations" (
    id bigint PRIMARY KEY,
    survey_id bigint NOT NULL,
    token text,
    email text,
    sent boolean DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL  
);

CREATE SEQUENCE IF NOT EXISTS public.survey_invitations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.survey_invitations_id_seq OWNED BY "survey_invitations".id;
ALTER TABLE ONLY "survey_invitations" ALTER COLUMN id SET DEFAULT nextval('public.survey_invitations_id_seq'::regclass);
CREATE INDEX IF NOT EXISTS index_survey_invitations_created_at ON "survey_invitations" USING btree (created_at);
CREATE INDEX IF NOT EXISTS index_survey_invitations_sent ON "survey_invitations" USING btree (sent);
CREATE INDEX IF NOT EXISTS index_survey_invitations_survey_id ON "survey_invitations" USING btree (survey_id);
CREATE UNIQUE INDEX IF NOT EXISTS index_survey_invitations_token ON "survey_invitations" USING btree (token);
CREATE INDEX IF NOT EXISTS index_survey_invitations_updated_at ON "survey_invitations" USING btree (updated_at);

ALTER TABLE ONLY "survey_invitations"
    DROP CONSTRAINT IF EXISTS survey_invitations_survey_id_fkey;
ALTER TABLE ONLY "survey_invitations"
    ADD CONSTRAINT survey_invitations_survey_id_fkey FOREIGN KEY (survey_id) REFERENCES "surveys"(id) ON DELETE CASCADE;

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back
DROP TABLE IF EXISTS "surveys"
DROP TABLE IF EXISTS "questions"
DROP TABLE IF EXISTS "answers"
DROP TABLE IF EXISTS "survey_invitations"
DROP TYPE IF EXISTS public.survey_trigger_type
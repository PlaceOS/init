-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied
-- +micrate StatementBegin
DO $$
    BEGIN
        BEGIN
            ALTER TABLE "sys" ADD COLUMN public BOOLEAN NOT NULL DEFAULT false;
        EXCEPTION
            WHEN duplicate_column THEN RAISE NOTICE 'column public already exists in sys.';
        END;
    END;
$$
LANGUAGE plpgsql;
-- +micrate StatementEnd

-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

ALTER TABLE "sys" DROP COLUMN public;

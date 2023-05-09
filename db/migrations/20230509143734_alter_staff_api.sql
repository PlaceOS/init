-- +micrate Up
-- SQL in section 'Up' is executed when this migration is applied

 ALTER TYPE survey_trigger_type ADD VALUE 'VISITOR_CHECKEDIN';
 ALTER TYPE survey_trigger_type ADD VALUE 'VISITOR_CHECKEDOUT';
 DROP INDEX IF EXISTS index_event_metadatas_event_id;
 DROP INDEX IF EXISTS event_metadatas_event_id;
 
-- +micrate Down
-- SQL section 'Down' is executed when this migration is rolled back

SET @daylink_weekly_column_exists = (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'ai_plan_limits'
    AND column_name = 'weekly_units'
);

SET @daylink_drop_weekly_column = IF(
  @daylink_weekly_column_exists > 0,
  'ALTER TABLE ai_plan_limits DROP COLUMN weekly_units',
  'SELECT 1'
);

PREPARE daylink_monthly_quota_migration FROM @daylink_drop_weekly_column;
EXECUTE daylink_monthly_quota_migration;
DEALLOCATE PREPARE daylink_monthly_quota_migration;

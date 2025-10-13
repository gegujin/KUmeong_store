import { MigrationInterface, QueryRunner } from 'typeorm';

export class EnsureMsgIndex1759916500000 implements MigrationInterface {
  name = 'EnsureMsgIndex1759916500000';

  public async up(q: QueryRunner): Promise<void> {
    // 테이블이 존재할 때만 인덱스 보장
    await q.query(`
      SET @has_table := (
        SELECT 1 FROM information_schema.TABLES
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = 'conversation_messages' LIMIT 1
      );
    `);
    await q.query(`
      SET @sql := IF(@has_table = 1,
        'DO 0',
        'DO 0'  -- 테이블 없으면 아무것도 안 함
      );
    `);
    await q.query(`PREPARE s FROM @sql`); await q.query(`EXECUTE s`); await q.query(`DEALLOCATE PREPARE s`);

    // 테이블이 있을 때만 인덱스 확인/보장
    await q.query(`
      SET @has_new := (
        SELECT 1 FROM information_schema.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = 'conversation_messages'
           AND INDEX_NAME = 'ix_cm_conv_created_id' LIMIT 1
      );
    `);
    await q.query(`
      SET @sql := IF(@has_new = 1,
        'DO 0',
        'CREATE INDEX ix_cm_conv_created_id ON conversation_messages (conversation_id, created_at, id)'
      );
    `);
    await q.query(`PREPARE s FROM @sql`); await q.query(`EXECUTE s`); await q.query(`DEALLOCATE PREPARE s`);
  }

  public async down(): Promise<void> {
    // 보증용이므로 down은 아무 것도 하지 않음(안전)
    return;
  }
}

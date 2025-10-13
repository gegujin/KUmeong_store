// src/migrations/1710000000002-msg-index-and-fk-cleanup.ts
import { MigrationInterface, QueryRunner } from 'typeorm';

export class MsgIndexAndFkCleanup1710000000002 implements MigrationInterface {
  name = 'MsgIndexAndFkCleanup1710000000002';

  public async up(q: QueryRunner): Promise<void> {
    // 1) 옛 인덱스 드롭(있을 때만)
    await q.query(`
      SET @has_old := (
        SELECT 1 FROM information_schema.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = 'conversation_messages'
           AND INDEX_NAME = 'ix_cm_conv_created' LIMIT 1
      );
    `);
    await q.query(`
      SET @sql := IF(@has_old = 1,
        'DROP INDEX ix_cm_conv_created ON conversation_messages',
        'DO /* no ix_cm_conv_created */ 0'
      );
    `);
    await q.query(`PREPARE s FROM @sql`); await q.query(`EXECUTE s`); await q.query(`DEALLOCATE PREPARE s`);

    // 2) 새 인덱스 보장(없으면 생성)
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
        'DO /* ix_cm_conv_created_id exists */ 0',
        'CREATE INDEX ix_cm_conv_created_id ON conversation_messages (conversation_id, created_at, id)'
      );
    `);
    await q.query(`PREPARE s FROM @sql`); await q.query(`EXECUTE s`); await q.query(`DEALLOCATE PREPARE s`);

    // 3) 중복 FK 있으면 제거 (실운영엔 보통 없음이 정상)
    await q.query(`
      SET @has_dup_fk := (
        SELECT 1
        FROM information_schema.REFERENTIAL_CONSTRAINTS
        WHERE CONSTRAINT_SCHEMA = DATABASE()
          AND CONSTRAINT_NAME = 'fk_cm_conversation_id'
          AND TABLE_NAME = 'conversation_messages'
        LIMIT 1
      );
    `);
    await q.query(`
      SET @sql := IF(@has_dup_fk = 1,
        'ALTER TABLE conversation_messages DROP FOREIGN KEY fk_cm_conversation_id',
        'DO /* no duplicate fk */ 0'
      );
    `);
    await q.query(`PREPARE s FROM @sql`); await q.query(`EXECUTE s`); await q.query(`DEALLOCATE PREPARE s`);
  }

  public async down(q: QueryRunner): Promise<void> {
    // 되돌릴 때는 순서가 중요:
    // (1) FK가 잡을 수 있도록 옛 인덱스 복구 → (2) 새 인덱스 드롭
    await q.query(`
      SET @has_old := (
        SELECT 1 FROM information_schema.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = 'conversation_messages'
           AND INDEX_NAME = 'ix_cm_conv_created' LIMIT 1
      );
    `);
    await q.query(`
      SET @sql := IF(@has_old = 1,
        'DO /* ix_cm_conv_created exists */ 0',
        'CREATE INDEX ix_cm_conv_created ON conversation_messages (conversation_id, created_at)'
      );
    `);
    await q.query(`PREPARE s FROM @sql`); await q.query(`EXECUTE s`); await q.query(`DEALLOCATE PREPARE s`);

    await q.query(`DROP INDEX ix_cm_conv_created_id ON conversation_messages`);

    // (선택) up에서 중복 FK를 드롭했던 환경을 되돌리고 싶다면 여기에 FK 복구 로직 추가 가능
    // 보통은 필요 없음.
  }
}

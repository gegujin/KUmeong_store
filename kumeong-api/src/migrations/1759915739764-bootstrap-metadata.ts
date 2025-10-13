// src/migrations/1759916600000-drop-dup-fk-conv.ts
import { MigrationInterface, QueryRunner } from 'typeorm';

export class DropDupFkConv1759916600000 implements MigrationInterface {
  name = 'DropDupFkConv1759916600000';

  public async up(q: QueryRunner): Promise<void> {
    // 0) 대상 테이블 존재 확인(없으면 아무 것도 안 함)
    await q.query(`
      SET @has_table := (
        SELECT 1 FROM information_schema.TABLES
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = 'conversation_messages' LIMIT 1
      );
    `);
    await q.query(`
      SET @sql := IF(@has_table = 1, 'DO 0', 'DO 0');
    `);
    await q.query(`PREPARE s FROM @sql`); await q.query(`EXECUTE s`); await q.query(`DEALLOCATE PREPARE s`);

    // 1) 기본 FK(fk_cm_conv)가 없으면 복구 (안전망)
    await q.query(`
      SET @has_main_fk := (
        SELECT 1
        FROM information_schema.REFERENTIAL_CONSTRAINTS
        WHERE CONSTRAINT_SCHEMA = DATABASE()
          AND TABLE_NAME = 'conversation_messages'
          AND CONSTRAINT_NAME = 'fk_cm_conv'
        LIMIT 1
      );
    `);
    await q.query(`
      SET @sql := IF(@has_main_fk = 1,
        'DO 0',
        'ALTER TABLE conversation_messages
           ADD CONSTRAINT fk_cm_conv
           FOREIGN KEY (conversation_id)
           REFERENCES conversations(id)
           ON DELETE CASCADE ON UPDATE CASCADE'
      );
    `);
    await q.query(`PREPARE s FROM @sql`); await q.query(`EXECUTE s`); await q.query(`DEALLOCATE PREPARE s`);

    // 2) 중복 FK(fk_cm_conversation_id)가 있으면 제거
    await q.query(`
      SET @has_dup_fk := (
        SELECT 1
        FROM information_schema.REFERENTIAL_CONSTRAINTS
        WHERE CONSTRAINT_SCHEMA = DATABASE()
          AND TABLE_NAME = 'conversation_messages'
          AND CONSTRAINT_NAME = 'fk_cm_conversation_id'
        LIMIT 1
      );
    `);
    await q.query(`
      SET @sql := IF(@has_dup_fk = 1,
        'ALTER TABLE conversation_messages DROP FOREIGN KEY fk_cm_conversation_id',
        'DO 0'
      );
    `);
    await q.query(`PREPARE s FROM @sql`); await q.query(`EXECUTE s`); await q.query(`DEALLOCATE PREPARE s`);
  }

  public async down(q: QueryRunner): Promise<void> {
    // 되돌리기: (원복 시나리오 보장을 위해) 중복 FK를 다시 추가하되, 이미 있으면 패스
    await q.query(`
      SET @has_dup_fk := (
        SELECT 1
        FROM information_schema.REFERENTIAL_CONSTRAINTS
        WHERE CONSTRAINT_SCHEMA = DATABASE()
          AND TABLE_NAME = 'conversation_messages'
          AND CONSTRAINT_NAME = 'fk_cm_conversation_id'
        LIMIT 1
      );
    `);
    await q.query(`
      SET @sql := IF(@has_dup_fk = 1,
        'DO 0',
        'ALTER TABLE conversation_messages
           ADD CONSTRAINT fk_cm_conversation_id
           FOREIGN KEY (conversation_id)
           REFERENCES conversations(id)
           ON DELETE CASCADE ON UPDATE CASCADE'
      );
    `);
    await q.query(`PREPARE s FROM @sql`); await q.query(`EXECUTE s`); await q.query(`DEALLOCATE PREPARE s`);
  }
}

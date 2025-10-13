// C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\entities\user-block.entity.ts
import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryColumn,
  Unique,
} from 'typeorm';

/**
 * ✅ userBlocks 테이블 (UUID PK + blockerId/blockedId 유니크)
 * DB 구조:
 *   id CHAR(36) PK
 *   blockerId / blockedId CHAR(36)
 *   UNIQUE(blockerId, blockedId)
 *   createdAt DATETIME
 */
@Entity('userBlocks')
@Unique('uqUserBlock', ['blockerId', 'blockedId'])
export class UserBlockEntity {
  // ✅ UUID 기반 CHAR(36)
  @PrimaryColumn({ type: 'char', length: 36 })
  id!: string;

  @Column({ type: 'char', length: 36 })
  blockerId!: string;

  @Column({ type: 'char', length: 36 })
  blockedId!: string;

  @CreateDateColumn({ name: 'createdAt', type: 'datetime' })
  createdAt!: Date;
}

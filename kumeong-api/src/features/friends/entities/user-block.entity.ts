// C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\entities\user-block.entity.ts
import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, Unique } from 'typeorm';

/**
 * ✅ userBlocks 테이블 (UUID PK + blockerId/blockedId 유니크)
 * DB 구조:
 *   id CHAR(36) PK
 *   blockerId / blockedId CHAR(36)
 *   UNIQUE(blockerId, blockedId)
 *   createdAt DATETIME
 */
// ✅ 실제 테이블명: userblocks
@Entity({ name: 'userblocks' })
@Unique('uqUserBlock', ['blockerId', 'blockedId'])
export class UserBlockEntity {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id!: string; // bigint는 string으로 받는 게 안전

  @Column({ type: 'char', length: 36 })
  blockerId!: string;

  @Column({ type: 'char', length: 36 })
  blockedId!: string;

  @CreateDateColumn({ type: 'datetime' })
  createdAt!: Date;
}

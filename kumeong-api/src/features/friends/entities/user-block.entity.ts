// kumeong-api/src/features/friends/entities/user-block.entity.ts
import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, Unique } from 'typeorm';

/**
 * userBlocks 테이블
 * - PK: BIGINT (자동 증가)
 * - UNIQUE(blockerId, blockedId)
 */
@Entity({ name: 'userBlocks' })
@Unique('uq_user_block', ['blockerId', 'blockedId'])
export class UserBlockEntity {
  // BIGINT는 JS number 범위를 넘어갈 수 있으므로 string으로 받는 것이 안전
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id!: string;

  @Column({ type: 'char', length: 36 })
  blockerId!: string;

  @Column({ type: 'char', length: 36 })
  blockedId!: string;

  @CreateDateColumn({ type: 'datetime', precision: 3 })
  createdAt!: Date;
}

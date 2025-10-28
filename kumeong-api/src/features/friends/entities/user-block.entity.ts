// kumeong-api/src/features/friends/entities/user-block.entity.ts
import { Column, CreateDateColumn, Entity, PrimaryColumn, Unique } from 'typeorm';

/**
 * userBlocks 테이블 (UUID PK)
 * - blockerId / blockedId : 차단 관계
 * - UNIQUE(blockerId, blockedId)
 */
@Entity({ name: 'userBlocks', synchronize: false })
@Unique('uq_user_block', ['blockerId', 'blockedId'])
export class UserBlockEntity {
  @PrimaryColumn({ type: 'char', length: 36 })
  id!: string;

  @Column({ type: 'char', length: 36 })
  blockerId!: string;

  @Column({ type: 'char', length: 36 })
  blockedId!: string;

  @CreateDateColumn({ type: 'datetime', precision: 3 })
  createdAt!: Date;
}

// kumeong-api/src/features/friends/entities/friend-request.entity.ts
import { Entity, PrimaryColumn, Column, CreateDateColumn, Index } from 'typeorm';

export type FriendReqStatus = 'PENDING' | 'ACCEPTED' | 'REJECTED' | 'CANCELED';

// ✅ 실제 테이블명과 동기화 정책 고정
@Entity({ name: 'friendRequests', synchronize: false })
@Index('uq_friend_req', ['fromUserId', 'toUserId'], { unique: true })
@Index('ix_friend_req_to_status', ['toUserId', 'status', 'createdAt'])
@Index('ix_friend_req_from_status', ['fromUserId', 'status', 'createdAt'])
export class FriendRequestEntity {
  @PrimaryColumn('char', { length: 36 })
  id!: string;

  @Column('char', { length: 36 })
  fromUserId!: string;

  @Column('char', { length: 36 })
  toUserId!: string;

  @Column({
    type: 'enum',
    enum: ['PENDING', 'ACCEPTED', 'REJECTED', 'CANCELED'],
    default: 'PENDING',
  })
  status!: FriendReqStatus;

  @CreateDateColumn({ type: 'datetime', precision: 3 })
  createdAt!: Date;

  @Column({ type: 'datetime', precision: 3, nullable: true })
  decidedAt!: Date | null;
}

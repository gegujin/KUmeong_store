// C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\entities\friend-request.entity.ts
import { Entity, PrimaryColumn, Column, CreateDateColumn, Index } from 'typeorm';

export type FriendReqStatus = 'PENDING' | 'ACCEPTED' | 'REJECTED' | 'CANCELED';

@Entity('friendRequests') // 실제 테이블명 (friendrequests 로 표시되어도 OK)
@Index('uq_friend_req', ['fromUserId', 'toUserId'], { unique: true })
@Index('ix_friend_req_to_status', ['toUserId', 'status', 'createdAt'])
@Index('ix_friend_req_from_status', ['fromUserId', 'status', 'createdAt'])
export class FriendRequestEntity {
  @PrimaryColumn('char', { length: 36, name: 'id' })
  id!: string;

  // DB 컬럼: from_user_id
  @Column('char', { length: 36, name: 'from_user_id' })
  fromUserId!: string;

  // DB 컬럼: to_user_id
  @Column('char', { length: 36, name: 'to_user_id' })
  toUserId!: string;

  // DB 컬럼: status (ENUM)
  @Column({
    type: 'enum',
    enum: ['PENDING', 'ACCEPTED', 'REJECTED', 'CANCELED'],
    default: 'PENDING',
    name: 'status',
  })
  status!: FriendReqStatus;

  // DB 컬럼: created_at
  @CreateDateColumn({ name: 'created_at', type: 'datetime' })
  createdAt!: Date;

  // DB 컬럼: decided_at (NULL 허용)
  @Column({ name: 'decided_at', type: 'datetime', nullable: true })
  decidedAt!: Date | null;
}

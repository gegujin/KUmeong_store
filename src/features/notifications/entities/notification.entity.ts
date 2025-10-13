// C:\Users\82105\KU-meong Store\kumeong-api\src\features\notifications\entities\notification.entity.ts
import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn } from 'typeorm';

export type NotificationType =
  | 'FRIEND_REQUEST_RECEIVED'
  | 'FRIEND_REQUEST_ACCEPTED'
  | 'FRIEND_REQUEST_REJECTED'
  | 'FRIEND_REQUEST_CANCELLED'
  | 'UNFRIENDED';

@Entity('notifications')
@Index('ix_notif_user_created', ['userId', 'createdAt'])
export class NotificationEntity {
  @PrimaryGeneratedColumn('increment') id!: number;

  @Column('bigint') userId!: number;

  // SQLite 호환: simple-enum (문자열 저장)
  @Column({ type: 'simple-enum', enum: ['FRIEND_REQUEST_RECEIVED','FRIEND_REQUEST_ACCEPTED','FRIEND_REQUEST_REJECTED','FRIEND_REQUEST_CANCELLED','UNFRIENDED'] })
  type!: NotificationType;

  // payload는 식별자/이벤트 관련 정보(JSON). simple-json → TEXT에 직렬화
  @Column({ type: 'simple-json', nullable: true }) payload?: Record<string, any> | null;

  @CreateDateColumn() createdAt!: Date;
  @Column({ type: 'datetime', nullable: true }) readAt?: Date | null;
}

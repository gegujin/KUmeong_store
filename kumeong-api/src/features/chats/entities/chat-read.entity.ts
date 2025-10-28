// C:\Users\82105\KU-meong Store\kumeong-api\src\features\chats\entities\chat-read.entity.ts
import {
  Entity,
  PrimaryColumn,
  Column,
  ManyToOne,
  JoinColumn,
  UpdateDateColumn,
} from 'typeorm';
import { ChatRoom } from './chat-room.entity';

// ✅ 실제 테이블명: chatreads
@Entity({ name: 'chatreads' })
export class ChatRead {
  // 복합 PK
  @PrimaryColumn('char', { length: 36 })
  roomId!: string;

  @PrimaryColumn('char', { length: 36 })
  userId!: string;

  @Column('char', { length: 36 })
  lastReadMessageId!: string;

  @ManyToOne(() => ChatRoom, (r) => r.reads, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'roomId' })
  room!: ChatRoom;

  @UpdateDateColumn({ type: 'datetime', precision: 6 })
  updatedAt!: Date;
}

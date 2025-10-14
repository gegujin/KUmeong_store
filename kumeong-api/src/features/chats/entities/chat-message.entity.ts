// C:\Users\82105\KU-meong Store\kumeong-api\src\features\chats\entities\chat-message.entity.ts
import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
  BeforeInsert,
} from 'typeorm';
import { randomUUID } from 'crypto';
import { ChatRoom } from './chat-room.entity';

export type ChatMessageType = 'TEXT' | 'IMAGE' | 'FILE' | string;

@Entity({ name: 'chatMessages' })
@Index('ix_chatMessages_room_created', ['roomId', 'createdAt', 'id'])
export class ChatMessage {
  @PrimaryColumn('char', { length: 36 })
  id!: string;

  @Column('char', { length: 36 })
  roomId!: string;

  @ManyToOne(() => ChatRoom, (r) => r.messages, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'roomId' })
  room!: ChatRoom;

  @Column('char', { length: 36 })
  senderId!: string;

  @Column({ type: 'varchar', length: 16, default: 'TEXT' })
  type!: ChatMessageType;

  @Column({ type: 'text', nullable: true })
  content?: string | null;

  @Column({ type: 'varchar', length: 512, nullable: true })
  fileUrl?: string | null;

  @CreateDateColumn({ type: 'datetime', precision: 6 })
  createdAt!: Date;

  @BeforeInsert()
  assignId() {
    if (!this.id) this.id = randomUUID();
  }
}

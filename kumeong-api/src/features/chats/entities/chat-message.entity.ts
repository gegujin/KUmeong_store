// src/features/chats/entities/chat-message.entity.ts
import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  BeforeInsert,
} from 'typeorm';
import { randomUUID } from 'crypto';
import { ChatRoom } from './chat-room.entity';

export type ChatMessageType = 'TEXT' | 'FILE' | 'SYSTEM' | string;

// ✅ 실제 테이블명: chatMessages (camelCase) + DDL 차단
@Entity({ name: 'chatMessages', synchronize: false })
export class ChatMessage {
  // PK
  @PrimaryColumn('char', { length: 36, name: 'id' })
  id!: string;

  @Column('char', { length: 36, name: 'roomId' })
  roomId!: string;

  @ManyToOne(() => ChatRoom, (r) => r.messages, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'roomId' })
  room!: ChatRoom;

  @Column('char', { length: 36, name: 'senderId' })
  senderId!: string;

  @Column({ type: 'enum', enum: ['TEXT', 'FILE', 'SYSTEM'], name: 'type', default: 'TEXT' })
  type!: ChatMessageType;

  @Column({ type: 'text', name: 'content', nullable: true })
  content?: string | null;

  @Column({ type: 'varchar', length: 500, name: 'fileUrl', nullable: true })
  fileUrl?: string | null;

  @CreateDateColumn({ type: 'datetime', name: 'createdAt' })
  createdAt!: Date;

  // ⚠️ DB에 있는 AUTO_INCREMENT UNIQUE 컬럼 — 인덱스/제약은 DB가 관리
  @Column('bigint', { unsigned: true, name: 'seq' })
  seq!: string | number; // bigint라면 string으로 받아도 OK

  @BeforeInsert()
  assignId() {
    if (!this.id) this.id = randomUUID();
  }
}

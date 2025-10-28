// C:\Users\82105\KU-meong Store\kumeong-api\src\features\chats\entities\chat-receipts.entity.ts
import {
  Entity,
  PrimaryColumn,
  Column,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { ChatMessage } from './chat-message.entity';

// ✅ 실제 테이블명: chatreceipts
@Entity({ name: 'chatreceipts' })
export class ChatReceipt {
  // 복합 PK
  @PrimaryColumn('char', { length: 36 })
  messageId!: string;

  @PrimaryColumn('char', { length: 36 })
  userId!: string;

  @Column({ type: 'datetime', precision: 6, nullable: true })
  deliveredAt?: Date | null;

  @Column({ type: 'datetime', precision: 6, nullable: true })
  readAt?: Date | null;

  // (선택) 메시지와의 관계 — FK가 있는 경우에만 유효
  @ManyToOne(() => ChatMessage, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'messageId' })
  message?: ChatMessage;
}

// C:\Users\82105\KU-meong Store\kumeong-api\src\features\chats\entities\conversation-message.entity.ts
import {
  BeforeInsert,
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryColumn,
} from 'typeorm';
import { randomUUID } from 'crypto';
import { Conversation } from './conversation.entity';

@Entity('conversation_messages')
@Index('ix_cm_conv_created', ['conversationId', 'createdAt'])          // 시간순 조회
@Index('ix_cm_conv_created_id', ['conversationId', 'createdAt', 'id']) // 안정 페이징
@Index('ix_cm_sender', ['senderId'])                                   // 발신자별 조회(옵션)
export class ConversationMessage {
  @PrimaryColumn({ type: 'char', length: 36 })
  id!: string;

  @Column({ name: 'conversation_id', type: 'char', length: 36 })
  conversationId!: string;

  @Column({ name: 'sender_id', type: 'char', length: 36 })
  senderId!: string;

  @Column({ type: 'text', nullable: false })
  content!: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @ManyToOne(() => Conversation, {
    onDelete: 'CASCADE',
    onUpdate: 'CASCADE',
  })
  @JoinColumn({ name: 'conversation_id', referencedColumnName: 'id' })
  conversation!: Conversation;

  /** 서비스에서 id를 주입하지 않아도 안전하게 UUID 부여 */
  @BeforeInsert()
  ensureId() {
    if (!this.id) this.id = randomUUID();
  }
}

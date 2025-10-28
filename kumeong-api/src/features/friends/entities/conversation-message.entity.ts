import { Entity, Column, PrimaryColumn, CreateDateColumn, Index } from 'typeorm';

// ✅ 실제 테이블명: conversationmessages
@Entity({ name: 'conversationmessages' })
@Index('ix_cm_conv_created_id', ['conversationId', 'createdAt', 'id'])
export class ConversationMessage {
  @PrimaryColumn({ type: 'char', length: 36, name: 'id' })
  id!: string;

  @Column({ type: 'char', length: 36, name: 'conversationId' })
  conversationId!: string;

  @Column({ type: 'char', length: 36, name: 'senderId' })
  senderId!: string;

  @Column({ type: 'text', name: 'content' })
  content!: string;

  @CreateDateColumn({
    type: 'datetime',
    name: 'createdAt',
    default: () => 'CURRENT_TIMESTAMP',
  })
  createdAt!: Date;
}

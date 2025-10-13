// C:\Users\82105\KU-meong Store\kumeong-api\src\features\chats\entities\chat-message.entity.ts
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

@Entity('chat_messages')
@Index('ix_pair_id', ['userAId', 'userBId', 'id'])
export class ChatMessageEntity {
  // ✅ PK를 UUID(string)으로 통일
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  // ✅ 친구쌍 정규화: 항상 (사전식 기준, UUID)
  @Column({ name: 'user_a_id', type: 'char', length: 36 })
  userAId!: string;

  @Column({ name: 'user_b_id', type: 'char', length: 36 })
  userBId!: string;

  // ✅ 보낸 사람 UUID
  @Column({ name: 'sender_id', type: 'char', length: 36 })
  senderId!: string;

  // 본문
  @Column({ type: 'text' })
  text!: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}

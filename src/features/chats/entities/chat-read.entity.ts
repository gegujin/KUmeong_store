// C:\Users\82105\KU-meong Store\kumeong-api\src\features\chats\entities\chat-read.entity.ts
import { Entity, PrimaryGeneratedColumn, Column, Unique, UpdateDateColumn } from 'typeorm';

@Entity('chat_reads')
@Unique('uq_read_pair', ['userId', 'peerId'])
export class ChatReadEntity {
  // ✅ PK를 UUID(string)으로 통일
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  // ✅ UUID 기반 사용자 ID
  @Column({ name: 'user_id', type: 'char', length: 36 })
  userId!: string;

  @Column({ name: 'peer_id', type: 'char', length: 36 })
  peerId!: string;

  // ✅ 마지막으로 읽은 메시지 UUID
  @Column({ name: 'last_message_id', type: 'char', length: 36, nullable: true })
  lastMessageId!: string | null;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;
}

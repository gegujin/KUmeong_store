// C:\Users\82105\KU-meong Store\kumeong-api\src\features\friend\entities\conversation.entity.ts
import { Entity, Column, PrimaryColumn, CreateDateColumn, Index } from 'typeorm';

@Entity({ name: 'conversations' })
@Index('uq_conv_pair', ['participantA', 'participantB'], { unique: true })
export class Conversation {
  @PrimaryColumn({ type: 'char', length: 36, name: 'id' })
  id!: string;

  // 전역 SnakeNamingStrategy를 무력화: 실제 컬럼명을 명시
  @Column({ type: 'char', length: 36, name: 'participant_a' })
  participantA!: string;

  @Column({ type: 'char', length: 36, name: 'participant_b' })
  participantB!: string;

  @CreateDateColumn({
    type: 'datetime',
    name: 'created_at',
    default: () => 'CURRENT_TIMESTAMP',
  })
  createdAt!: Date;
}

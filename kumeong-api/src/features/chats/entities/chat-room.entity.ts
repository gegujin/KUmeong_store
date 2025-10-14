import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  OneToMany,
  BeforeInsert,
} from 'typeorm';
import { randomUUID } from 'crypto';
import { ChatMessage } from './chat-message.entity';
import { ChatRead } from './chat-read.entity';

@Entity({ name: 'chatRooms' })
export class ChatRoom {
  // UUID/CHAR(36)
  @PrimaryColumn('char', { length: 36 })
  id!: string;

  // 생성 시각 (DATETIME(6))
  @CreateDateColumn({ type: 'datetime', precision: 6 })
  createdAt!: Date;

  // 관계 매핑 (양방향 선택)
  @OneToMany(() => ChatMessage, (msg) => msg.room, { cascade: false })
  messages?: ChatMessage[];

  @OneToMany(() => ChatRead, (read) => read.room, { cascade: false })
  reads?: ChatRead[];

  @BeforeInsert()
  assignId() {
    if (!this.id) this.id = randomUUID();
  }
}

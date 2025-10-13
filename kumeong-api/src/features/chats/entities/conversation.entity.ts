import {
  BeforeInsert,
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryColumn,
  Unique,
} from 'typeorm';
import { randomUUID } from 'crypto';

/**
 * 1:1 대화방 엔티티
 * - 실제 DB 컬럼명: id, participant_a, participant_b, created_at
 * - UNIQUE (participant_a, participant_b)
 * - INSERT 시 (A <= B) 정규화 자동 수행
 */
@Entity({ name: 'conversations' })
@Unique('uq_conv_pair', ['participantA', 'participantB'])
@Index('ix_conv_a', ['participantA'])
@Index('ix_conv_b', ['participantB'])
@Index('ix_conv_created', ['createdAt'])
export class Conversation {
  /** PK: UUID */
  @PrimaryColumn({ type: 'char', length: 36, name: 'id' })
  id!: string;

  /** 참여자 A — 항상 사전식으로 더 작은 UUID */
  @Column({ type: 'char', length: 36, name: 'participant_a' })
  participantA!: string;

  /** 참여자 B — 항상 사전식으로 더 큰 UUID */
  @Column({ type: 'char', length: 36, name: 'participant_b' })
  participantB!: string;

  /** 생성 시각 */
  @CreateDateColumn({
    type: 'datetime',
    name: 'created_at',
    default: () => 'CURRENT_TIMESTAMP',
  })
  createdAt!: Date;

  /** INSERT 전 정규화 + 자기자신 금지 */
  @BeforeInsert()
  private normalizeBeforeInsert() {
    if (!this.id) this.id = randomUUID();

    if (!this.participantA || !this.participantB) {
      throw new Error('participantA and participantB are required');
    }

    if (this.participantA === this.participantB) {
      throw new Error('participantA and participantB cannot be the same');
    }

    // UUID 문자열 비교 기준 정렬
    if (this.participantA.localeCompare(this.participantB) > 0) {
      const tmp = this.participantA;
      this.participantA = this.participantB;
      this.participantB = tmp;
    }
  }

  /** 정규화된 Conversation 인스턴스 생성 */
  static fromPair(a: string, b: string): Conversation {
    if (!a || !b) throw new Error('participant ids required');
    if (a === b) throw new Error('cannot create conversation with self');

    const [pa, pb] = a.localeCompare(b) <= 0 ? [a, b] : [b, a];
    const conv = new Conversation();
    conv.id = randomUUID();
    conv.participantA = pa;
    conv.participantB = pb;
    return conv;
  }
}

import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryColumn,
  UpdateDateColumn,
} from 'typeorm';
import { randomUUID } from 'crypto';

// ✅ 실제 테이블명: email_verifications
@Entity({ name: 'email_verifications' })
export class EmailVerification {
  /** UUID 기본키 (CHAR(36)) */
  @PrimaryColumn({ type: 'char', length: 36 })
  id: string = randomUUID();

  /** 인증 대상 이메일 */
  @Index()
  @Column({ type: 'varchar', length: 255 })
  email!: string;

  /** 코드 해시 (SHA256 등 — 평문 저장 금지) */
  @Column({ type: 'char', length: 64 })
  codeHash!: string;

  /** 만료 시각 */
  @Index()
  @Column({ type: 'datetime' })
  expireAt!: Date;

  /** 남은 시도 가능 횟수 */
  @Column({ type: 'int', default: 5 })
  remainingAttempts!: number;

  /** 사용 완료 시각(성공 후 표기) */
  @Column({ type: 'datetime', nullable: true })
  usedAt!: Date | null;

  /** 마지막 발송 시각(쿨다운 체크용) */
  @Column({ type: 'datetime', nullable: true })
  lastSentAt!: Date | null;

  /** 생성일시 */
  @CreateDateColumn({ type: 'datetime' })
  createdAt!: Date;

  /** 수정일시 */
  @UpdateDateColumn({ type: 'datetime' })
  updatedAt!: Date;
}

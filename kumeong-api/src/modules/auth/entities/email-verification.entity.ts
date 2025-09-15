import { Column, CreateDateColumn, Entity, Index, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';

@Entity('email_verifications')
export class EmailVerification {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  // 인증 대상 이메일
  @Index()
  @Column({ length: 255 })
  email!: string;

  // 코드 해시(평문 저장 금지)
  @Column({ length: 64 })
  codeHash!: string; // sha256

  // 만료시각
  @Index()
  @Column({ type: 'datetime' })
  expireAt!: Date;

  // 남은 시도 가능 횟수
  @Column({ type: 'int', default: 5 })
  remainingAttempts!: number;

  // 사용 완료 시각(성공 후 표기)
  @Column({ type: 'datetime', nullable: true })
  usedAt!: Date | null;

  // 마지막 발송 시각(쿨다운 체크용)
  @Column({ type: 'datetime', nullable: true })
  lastSentAt!: Date | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}

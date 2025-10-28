import {
  Entity,
  Column,
  PrimaryColumn,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
  BeforeInsert,
  Index,
} from 'typeorm';
import { randomUUID } from 'crypto';
import { User } from '../../users/entities/user.entity';

// ✅ 실제 테이블명: delivery_memberships
@Entity({ name: 'delivery_memberships' })
@Unique(['userId'])
export class DeliveryMembership {
  @PrimaryColumn('char', { length: 36 })
  id!: string;

  @Index()
  @Column('char', { length: 36 })
  userId!: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId', referencedColumnName: 'id' })
  user?: User;

  // ✅ DB 스키마와 동일하게 추가
  @Column({ type: 'varchar', length: 255 })
  email!: string;

  // ✅ DB 스키마와 동일하게 length 20로 맞춤 (DB가 20임)
  @Column({ type: 'varchar', length: 20 })
  transport!: string; // '도보' | '자전거' | '오토바이' | '기타'

  // ✅ DB 스키마와 동일 (nullable)
  @Column({ type: 'varchar', length: 255, nullable: true })
  universityToken?: string | null;

  @CreateDateColumn({ type: 'datetime', precision: 6 })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'datetime', precision: 6 })
  updatedAt!: Date;

  @BeforeInsert()
  assignId() {
    if (!this.id) this.id = randomUUID();
  }
}

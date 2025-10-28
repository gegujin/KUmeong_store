// kumeong-api/src/features/users/entities/user.entity.ts
import {
  Entity, Column, PrimaryColumn,
  CreateDateColumn, UpdateDateColumn, DeleteDateColumn,
} from 'typeorm';

export enum UserRole {
  USER = 'USER',
  ADMIN = 'ADMIN',
}

// ✅ 실제 테이블명: users (스키마 고정)
@Entity({ name: 'users', synchronize: false })
export class UserEntity {
  @PrimaryColumn('char', { length: 36 })
  id!: string;

  @Column({ type: 'varchar', length: 120, unique: true })
  email!: string;

  @Column({ type: 'varchar', length: 100 })
  name!: string;

  @Column({ type: 'varchar', length: 255 })
  passwordHash!: string;

  @Column({ type: 'int', default: 0 })
  reputation!: number;

  @Column({ type: 'enum', enum: UserRole, default: UserRole.USER })
  role!: UserRole;

  @Column({ type: 'varchar', length: 100, nullable: true })
  universityName?: string | null;

  @Column({ type: 'tinyint', width: 1, default: 0 })
  universityVerified!: boolean;

  @Column({ type: 'tinyint', width: 1, default: 0 })
  isDeliveryMember!: boolean;

  @Column({ type: 'varchar', length: 30, nullable: true })
  deliveryTransport?: string | null;

  @DeleteDateColumn({ type: 'datetime', nullable: true })
  deletedAt?: Date | null;

  @CreateDateColumn({ type: 'datetime' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'datetime' })
  updatedAt!: Date;
}

// 기존 import 호환
export { UserEntity as User };

export type UserSafe = Pick<
  UserEntity,
  'id' | 'email' | 'name' | 'reputation' |
  'universityVerified' | 'universityName' |
  'createdAt' | 'updatedAt'
>;

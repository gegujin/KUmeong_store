import {
  Entity,
  Column,
  PrimaryColumn,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
} from 'typeorm';

export enum UserRole {
  USER = 'USER',
  ADMIN = 'ADMIN',
}

// ✅ 실제 테이블명: users
@Entity({ name: 'users' })
export class UserEntity {
  @PrimaryColumn({ type: 'char', length: 36 })
  id!: string;

  @Column({ length: 120, unique: true })
  email!: string;

  @Column({ length: 100 })
  name!: string;

  // 테이블 컬럼명: passwordHash (snake 아님)
  @Column({ length: 255 })
  passwordHash!: string;

  @Column({ type: 'int', default: 0 })
  reputation!: number;

  // 테이블에 role enum('USER','ADMIN') 이미 존재
  @Column({ type: 'enum', enum: UserRole, default: UserRole.USER })
  role!: UserRole;

  // DESC 결과 기준: varchar(100)
  @Column({ type: 'varchar', length: 100, nullable: true })
  universityName?: string | null;

  @Column({ type: 'tinyint', width: 1, default: false })
  universityVerified!: boolean;

  // camelCase soft delete
  @DeleteDateColumn()
  deletedAt?: Date | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
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

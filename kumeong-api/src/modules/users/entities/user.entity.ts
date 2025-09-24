// // src/modules/users/entities/user.entity.ts
// import {
//   Entity,
//   PrimaryGeneratedColumn,
//   Column,
//   OneToMany,
//   CreateDateColumn,
//   UpdateDateColumn,
//   Unique,
//   BeforeInsert,
//   BeforeUpdate,
//   Index,
// } from 'typeorm';
// import { Product } from '../../products/entities/product.entity';

// export enum UserRole {
//   USER = 'USER',
//   ADMIN = 'ADMIN',
// }

// @Entity('users')
// @Unique(['email'])
// export class User {
//   @PrimaryGeneratedColumn('uuid')
//   id: string;

//   // 이메일: 유니크 + 소문자 정규화 훅 적용
//   @Column({ length: 120 })
//   email: string;

//   @Column({ length: 100 })
//   name: string;

//   // bcrypt 해시는 일반적으로 60자
//   @Column({ type: 'varchar', length: 60, select: false })
//   passwordHash: string;

//   // ✅ SQLite 호환: enum → simple-enum
//   @Column({
//     type: 'simple-enum',
//     enum: UserRole,
//     default: UserRole.USER,
//   })
//   role: UserRole;

//   // Product 역방향 관계
//   @OneToMany(() => Product, (p) => p.owner)
//   products: Product[];

//   @Index('idx_users_created_at')
//   @CreateDateColumn()
//   createdAt: Date;

//   @UpdateDateColumn()
//   updatedAt: Date;

//   // ===== Normalize hooks =====
//   @BeforeInsert()
//   @BeforeUpdate()
//   normalizeFields() {
//     if (this.email) this.email = this.email.trim().toLowerCase();
//     if (!this.role) this.role = UserRole.USER;
//   }
// }

// src/modules/users/entities/user.entity.ts
import {
  Entity,
  PrimaryColumn,
  Column,
  OneToMany,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
} from 'typeorm';
import { Product } from '../../products/entities/product.entity';

/** 사용자 역할 enum */
export enum UserRole {
  USER = 'USER',
  ADMIN = 'ADMIN',
}

@Entity('users')
export class User {
  @PrimaryColumn({ type: 'char', length: 36 })
  id: string; // UUID

  @Column({ type: 'varchar', length: 120, unique: true })
  email: string;

  @Column({ type: 'varchar', length: 100 })
  name: string;

  // 🔹 select: false 제거 (로그인 시 passwordHash 조회 가능)
  @Column({ name: 'password_hash', type: 'varchar', length: 255 })
  passwordHash: string;

  @Column({ type: 'int', default: 0 })
  reputation: number;

  @Column({ type: 'enum', enum: UserRole, default: UserRole.USER })
  role: UserRole;

  @OneToMany(() => Product, (p) => p.owner, { cascade: false })
  products: Product[];

  @CreateDateColumn({ name: 'created_at', type: 'datetime' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'datetime' })
  updatedAt: Date;

  @DeleteDateColumn({ name: 'deleted_at', type: 'datetime', nullable: true })
  deletedAt?: Date | null;
}

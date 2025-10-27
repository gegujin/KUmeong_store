// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\users\entities\user.entity.ts
import {
  Entity,
  Column,
  PrimaryColumn,
  OneToMany,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  BeforeInsert,
} from 'typeorm';
import { randomUUID } from 'crypto';
import { Product } from '../../products/entities/product.entity';

export enum UserRole {
  USER = 'USER',
  ADMIN = 'ADMIN',
}

@Entity({ name: 'users' })
export class User {
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

  @Column({ type: 'varchar', length: 64, nullable: true })
  universityName?: string | null;

  @Column({ type: 'tinyint', width: 1, default: 0 })
  universityVerified!: boolean;

  @CreateDateColumn({ type: 'datetime', precision: 6 })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'datetime', precision: 6 })
  updatedAt!: Date;

  // 소프트 삭제 컬럼 (DB: DATETIME NULL)
  @DeleteDateColumn({ type: 'datetime', precision: 6, nullable: true })
  deletedAt?: Date | null;

  // ✅ Product.seller 와의 역방향 매핑 (owner → seller로 정합화)
  @OneToMany(() => Product, (p) => p.seller, { cascade: false })
  products!: Product[];

  @BeforeInsert()
  assignId() {
    if (!this.id) this.id = randomUUID();
  }
}

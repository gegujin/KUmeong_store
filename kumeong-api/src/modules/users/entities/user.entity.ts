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
import { v4 as uuidv4 } from 'uuid';

export enum UserRole {
  USER = 'USER',
  ADMIN = 'ADMIN',
}

@Entity('users')
export class User {
  @PrimaryColumn({ type: 'char', length: 36 })
  id: string = uuidv4(); // ✅ UUID 기본값

  @Column({ type: 'varchar', length: 64, nullable: true })
  universityName?: string | null;

  @Column({ type: 'boolean', default: false })
  universityVerified: boolean;

  @Column({ type: 'varchar', length: 120, unique: true })
  email: string;

  @Column({ type: 'varchar', length: 100 })
  name: string;

  @Column({ name: 'password_hash', select: false })
  passwordHash: string;

  @Column({ type: 'int', default: 0 })
  reputation: number;

  @Column({
    type: 'simple-enum',
    enum: UserRole,
    default: UserRole.USER,
  })
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

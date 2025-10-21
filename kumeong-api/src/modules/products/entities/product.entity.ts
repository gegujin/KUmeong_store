// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\products\entities\product.entity.ts
import {
  Entity,
  Column,
  PrimaryColumn,
  ManyToOne,
  CreateDateColumn,
  UpdateDateColumn,
  JoinColumn,
  BeforeInsert,
  Index,
} from 'typeorm';
import { randomUUID } from 'crypto';
import { User } from '../../users/entities/user.entity';

export enum ProductStatus {
  DRAFT = 'DRAFT',
  ON_SALE = 'ON_SALE',
  RESERVED = 'RESERVED',
  SOLD = 'SOLD',
}

@Entity({ name: 'products' })
@Index('IDX_product_owner', ['ownerId'])
@Index('IDX_product_createdAt', ['createdAt'])
@Index('IDX_product_price', ['price'])
export class Product {
  // PK: UUID/CHAR(36) — 전역 정책
  @PrimaryColumn('char', { length: 36 })
  id!: string;

  @Column('varchar', { length: 200 })
  title!: string;

  @Column('int', { unsigned: true })
  price!: number;

  @Column('enum', { enum: ProductStatus, default: ProductStatus.ON_SALE })
  status!: ProductStatus;

  // 선택 필드들(기존 스키마 호환)
  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ length: 50, nullable: true })
  category?: string;

  // 이미지 URL 배열(JSON)
  @Column({ type: 'simple-json', nullable: true })
  images?: string[];

  // 소유자 FK — UUID/CHAR(36)
  @Column('char', { length: 36 })
  ownerId!: string;

  @ManyToOne(() => User, (u) => u.products, {
    onDelete: 'CASCADE',
    nullable: false,
    eager: false,
  })
  @JoinColumn({ name: 'ownerId', referencedColumnName: 'id' })
  owner!: User;

  @CreateDateColumn({ type: 'timestamp' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamp' })
  updatedAt!: Date;

  @BeforeInsert()
  assignId() {
    if (!this.id) this.id = randomUUID();
  }
}

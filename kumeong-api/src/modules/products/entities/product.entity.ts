// src/modules/products/entities/product.entity.ts
import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
  DeleteDateColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

export enum ProductStatus {
  LISTED = 'LISTED',
  RESERVED = 'RESERVED',
  SOLD = 'SOLD',
}

@Entity('products')
@Index('IDX_product_owner', ['ownerId'])
@Index('IDX_product_createdAt', ['createdAt'])
@Index('IDX_product_price', ['price'])
export class Product {
  // 상품 PK UUID
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 100 })
  title: string;

  @Column('int')
  price: number;

  @Column({ type: 'simple-enum', enum: ProductStatus, default: ProductStatus.LISTED })
  status: ProductStatus;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ length: 50, nullable: true })
  category?: string;

  // 이미지 URL 배열 (JSON)
  @Column({ type: 'simple-json', nullable: true })
  images?: string[];

  // 소유자 FK(User.id: number)
  @Column({ name: 'owner_id', type: 'int' })
  ownerId: number;

  @ManyToOne(() => User, (u) => u.products, { onDelete: 'CASCADE', nullable: false })
  @JoinColumn({ name: 'owner_id' })
  owner: User;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  // 삭제일 컬럼 추가 (soft delete 지원)
  @DeleteDateColumn({ nullable: true })
  deletedAt?: Date;
}

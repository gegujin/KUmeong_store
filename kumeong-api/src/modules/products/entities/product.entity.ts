// kumeong-api/src/modules/products/entities/product.entity.ts
import {
  Entity,
  Column,
  PrimaryColumn,
  ManyToOne,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  JoinColumn,
  BeforeInsert,
  Index,
  DeleteDateColumn,
} from 'typeorm';
import { randomUUID } from 'crypto';
import { User } from '../../users/entities/user.entity';
import { ProductImage } from './product-image.entity';

export enum ProductStatus {
  LISTED = 'LISTED',
  RESERVED = 'RESERVED',
  SOLD = 'SOLD',
}

@Index('idx_products_category', ['category'])
// ✅ 실제 테이블명: products
@Entity({ name: 'products' })
@Index('ix_products_seller', ['sellerId'])
@Index('ix_products_createdAt', ['createdAt'])
@Index('ix_products_priceWon', ['priceWon'])
@Index('ix_products_status', ['status'])
@Index('ix_products_category', ['category'])
export class Product {
  // PK: UUID/CHAR(36)
  @PrimaryColumn('char', { length: 36 })
  id!: string;

  @Column('varchar', { length: 200 })
  title!: string;

  // 가격 필드: price -> priceWon (원화 정수)
  @Column('int', { unsigned: true, name: 'priceWon' })
  priceWon!: number;

  // 상태 ENUM
  @Column('enum', { enum: ProductStatus, default: ProductStatus.LISTED })
  status!: ProductStatus;

  // 선택 필드들
  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ length: 50, nullable: true })
  category?: string;

  // 위치 텍스트(거래 장소/등록 위치 표시용)
  @Column({ type: 'varchar', length: 255, nullable: true })
  locationText?: string | null;

  // 판매자 FK — UUID/CHAR(36)
  @Column('char', { length: 36, name: 'sellerId' })
  sellerId!: string;

  @ManyToOne(() => User, (u) => u.products, {
    onDelete: 'RESTRICT',
    onUpdate: 'CASCADE',
    nullable: false,
    eager: false,
  })
  @JoinColumn({ name: 'sellerId', referencedColumnName: 'id' })
  seller!: User;

  @CreateDateColumn({ type: 'datetime', precision: 3 })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'datetime', precision: 3 })
  updatedAt!: Date;

  @DeleteDateColumn({ type: 'datetime', precision: 3, nullable: true })
  deletedAt?: Date | null;

  // 이미지 관계 (별도 테이블)
  @OneToMany(() => ProductImage, (img) => img.product)
  images?: ProductImage[];

  @BeforeInsert()
  assignId() {
    if (!this.id) this.id = randomUUID();
  }
}

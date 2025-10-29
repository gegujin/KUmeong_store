// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\products\entities\product.entity.ts
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

@Entity({ name: 'products' })
@Index('ix_products_seller', ['sellerId'])
@Index('ix_products_createdAt', ['createdAt'])
@Index('ix_products_priceWon', ['priceWon'])
@Index('ix_products_status', ['status'])
export class Product {
  // PK: UUID/CHAR(36) — 전역 정책
  @PrimaryColumn('char', { length: 36 })
  id!: string;

  @Column('varchar', { length: 200 })
  title!: string;

  // price -> priceWon
  @Column('int', { unsigned: true, name: 'priceWon' })
  priceWon!: number;

  // ENUM 통일
  @Column('enum', { enum: ProductStatus, default: ProductStatus.LISTED })
  status!: ProductStatus;

  // 선택 필드들
  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ length: 50, nullable: true })
  category?: string;

  // ✅ 거래 위치(텍스트) — DTO(Create/Update)와 길이 맞춤
  @Column({ type: 'varchar', length: 100, nullable: true })
  locationText?: string;

  // 판매자 FK — UUID/CHAR(36) (ownerId -> sellerId)
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

  @CreateDateColumn({ type: 'datetime' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'datetime' })
  updatedAt!: Date;

  @OneToMany(() => ProductImage, (img) => img.product)
  images?: ProductImage[];

  // 소프트 삭제 (DATETIME NULL)
  @DeleteDateColumn({ type: 'datetime', nullable: true })
  deletedAt?: Date | null;

  @BeforeInsert()
  assignId() {
    if (!this.id) this.id = randomUUID();
  }
}

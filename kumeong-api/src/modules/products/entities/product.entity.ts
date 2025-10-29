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

// ✅ 실제 테이블명: products (DB 스키마와 컬럼 길이 정확히 일치)
@Entity({ name: 'products' })
@Index('ix_products_seller', ['sellerId'])
@Index('ix_products_createdAt', ['createdAt'])
@Index('ix_products_priceWon', ['priceWon'])
@Index('ix_products_status', ['status'])
@Index('ix_products_category', ['categoryPath']) // 실제 컬럼명은 아래 name:'category'로 매핑됨
export class Product {
  @PrimaryColumn('char', { length: 36 })
  id!: string;

  // DB: title VARCHAR(100)
  @Column('varchar', { length: 100 })
  title!: string;

  // DB: priceWon INT
  @Column('int', { unsigned: true, name: 'priceWon' })
  priceWon!: number;

  @Column('enum', { enum: ProductStatus, default: ProductStatus.LISTED })
  status!: ProductStatus;

  @Column({ type: 'text', nullable: true })
  description?: string | null;

  // ✅ 코드에서는 categoryPath로 사용하지만, DB 컬럼명은 'category' (VARCHAR(50))
  @Column('varchar', { length: 50, name: 'category', nullable: true })
  categoryPath?: string | null;

  // DB: locationText VARCHAR(120) NULL
  @Column('varchar', { length: 120, name: 'locationText', nullable: true })
  locationText?: string | null;

  // 참고: DB에 images TEXT가 있지만, 지금은 별도 엔티티(ProductImage) 사용
  @OneToMany(() => ProductImage, (img) => img.product)
  images?: ProductImage[];

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

  @BeforeInsert()
  assignId() {
    if (!this.id) this.id = randomUUID();
  }
}

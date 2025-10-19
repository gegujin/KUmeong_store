import {
  Index,
  Entity,
  Column,
  PrimaryColumn,
  ManyToOne,
  CreateDateColumn,
  UpdateDateColumn,
  JoinColumn,
  BeforeInsert,
} from 'typeorm';
import { randomUUID } from 'crypto';
import { User } from '../../users/entities/user.entity';

export enum ProductStatus {
  DRAFT = 'DRAFT',
  ON_SALE = 'LISTED',  // DB enum 값과 일치
  RESERVED = 'RESERVED',
  SOLD = 'SOLD',
}

@Index('idx_products_category', ['category'])
@Entity({ name: 'products' })
export class Product {
  @PrimaryColumn('char', { length: 36 })
  id!: string;

  @Column('varchar', { length: 100 })
  title!: string;

  @Column('int', { unsigned: true })
  priceWon!: number; // DB 컬럼명과 일치

  @Column('enum', { enum: ProductStatus, default: ProductStatus.ON_SALE })
  status!: ProductStatus;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ type: 'varchar', length: 50, nullable: true })
  category!: string | null;

  // 이미지 URL 배열
  @Column('simple-array', { nullable: true })
  images?: string[];

  @Column('char', { length: 36 })
  sellerId!: string; // ownerId -> sellerId (DB 컬럼명과 일치)

  @ManyToOne(() => User, (u) => u.products, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'sellerId' })
  seller!: User; // owner -> seller

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;

  @Column({ type: 'datetime', nullable: true })
  deletedAt?: Date;

  @Column({ type: 'varchar', length: 120, nullable: true })
  locationText?: string;


  @BeforeInsert()
  assignId() {
    if (!this.id) this.id = randomUUID();
  }
}

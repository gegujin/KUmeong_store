import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { Product } from './product.entity';

/**
 * 상품 이미지 테이블 (productImages)
 * - 각 상품(Product)에 여러 장의 이미지를 연결
 * - 순서(ord)로 정렬, 삭제 시 상품과 함께 CASCADE
 */
@Entity({ name: 'productImages' })
@Index('ix_pimg_product', ['productId'])
export class ProductImage {
  /** BIGINT AUTO_INCREMENT 기본키 */
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id!: string;

  /** 연결된 상품의 UUID(FK) */
  @Column('char', { length: 36 })
  productId!: string;

  /** 상품 엔티티 연결 */
  @ManyToOne(() => Product, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'productId' })
  product!: Product;

  /** 이미지 URL (최대 500자) */
  @Column('varchar', { length: 500 })
  url!: string;

  /** 정렬 순서 (기본 0) */
  @Column('int', { default: 0 })
  ord!: number;

  /** 생성 일시 */
  @CreateDateColumn({ type: 'datetime' })
  createdAt!: Date;
}

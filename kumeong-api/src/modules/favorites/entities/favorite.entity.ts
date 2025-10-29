import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,            // ✅ 추가
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Product } from '../../products/entities/product.entity';

// ✅ 실제 테이블명: favorites
@Entity({ name: 'favorites' })
@Index('uq_fav_owner_product', ['ownerUserId', 'productId'], { unique: true }) // ✅ 추가
export class Favorite {
  @PrimaryColumn({ type: 'char', length: 36 })
  id!: string; // UUID

  @Column({ type: 'char', length: 36 })
  ownerUserId!: string;

  @Column({ type: 'char', length: 36 })
  productId!: string;

  @CreateDateColumn({ type: 'datetime', precision: 3 })
  createdAt!: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'ownerUserId' })
  owner?: User;

  @ManyToOne(() => Product, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'productId' })
  product?: Product;
}

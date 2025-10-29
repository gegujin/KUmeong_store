// src/modules/favorites/entities/favorite.entity.ts
import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Product } from '../../products/entities/product.entity';

@Entity({ name: 'favorites' })
@Index('ux_fav_owner_product', ['ownerUserId', 'productId'], { unique: true })
@Index('ix_fav_owner_created', ['ownerUserId', 'createdAt'])
@Index('ix_fav_product_created', ['productId', 'createdAt'])
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

import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Product } from '../../products/entities/product.entity';

@Entity({ name: 'favorites' })
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

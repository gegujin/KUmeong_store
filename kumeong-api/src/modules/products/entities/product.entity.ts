import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
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
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 100 })
  title: string;

  @Column('int')
  price: number;

  // cross-DB(enum)
  @Column({ type: 'simple-enum', enum: ProductStatus, default: ProductStatus.LISTED })
  status: ProductStatus;

  @Column({ type: 'text', nullable: true })
  description?: string;

  @Column({ length: 50, nullable: true })
  category?: string;

  // cross-DB(JSON)
  @Column({ type: 'simple-json', nullable: true })
  images?: string[];

  // snake_case FK
  @Column({ type: 'varchar', length: 36, name: 'owner_id' })
  ownerId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE', eager: false })
  @JoinColumn({ name: 'owner_id' })
  owner: User;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

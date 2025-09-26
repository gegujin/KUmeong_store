// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\products\entities\product.entity.ts
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
  // 상품 PK는 기존대로 UUID 유지 (변경 불필요)
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

  // 🔧 FK: User.id(number) 에 맞게 number로 변경, length 제거
  @Column({ name: 'owner_id', type: 'int' })
  ownerId: number;

  @ManyToOne(() => User, (u) => u.products, { onDelete: 'CASCADE', nullable: false })
  @JoinColumn({ name: 'owner_id' })
  owner: User;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

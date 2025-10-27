// src/features/user-blocks/entities/user-block.entity.ts
import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

@Entity({ name: 'userBlocks', synchronize: false })
@Index('uq_user_block', ['blockerId', 'blockedId'], { unique: true })
export class UserBlock {
  // SQL: id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY
  @PrimaryGeneratedColumn('increment')
  id!: number;

  @Column('char', { length: 36 })
  blockerId!: string;

  @Column('char', { length: 36 })
  blockedId!: string;

  @CreateDateColumn({ type: 'datetime' })
  createdAt!: Date;
}

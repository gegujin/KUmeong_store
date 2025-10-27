// C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\entities\user-block.entity.ts
import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, Unique } from 'typeorm';

@Entity('userBlocks')
@Unique('uq_user_block', ['blockerId', 'blockedId'])
export class UserBlockEntity {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id!: string; // bigint는 string으로 받는 게 안전

  @Column({ type: 'char', length: 36 })
  blockerId!: string;

  @Column({ type: 'char', length: 36 })
  blockedId!: string;

  @CreateDateColumn({ type: 'datetime' })
  createdAt!: Date;
}

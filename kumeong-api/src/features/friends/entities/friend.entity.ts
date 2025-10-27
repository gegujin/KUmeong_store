// C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\entities\friend.entity.ts
import { Column, CreateDateColumn, Entity, Index, PrimaryColumn } from 'typeorm';

@Entity('friends')
export class FriendEntity {
  @PrimaryColumn({ type: 'char', length: 36 })
  id!: string;

  @Index('ix_friends_userA')
  @Column({ type: 'char', length: 36 })
  userAId!: string;

  @Index('ix_friends_userB')
  @Column({ type: 'char', length: 36 })
  userBId!: string;

  @Column({
    type: 'char',
    length: 36,
    asExpression: 'LEAST(`userAId`, `userBId`)',
    generatedType: 'VIRTUAL',
    select: false,
  })
  pairMinId!: string;

  @Column({
    type: 'char',
    length: 36,
    asExpression: 'GREATEST(`userAId`, `userBId`)',
    generatedType: 'VIRTUAL',
    select: false,
  })
  pairMaxId!: string;

  @CreateDateColumn({ type: 'datetime' })
  createdAt!: Date;
}

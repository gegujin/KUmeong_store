// C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\entities\friend.entity.ts
import { Column, CreateDateColumn, Entity, Index, PrimaryColumn } from 'typeorm';

/**
 * ✅ friends 테이블 (UUID PK)
 *  - userAId, userBId : 두 사용자 쌍
 *  - pairMinId, pairMaxId : DB 가상 컬럼 (LEAST/GREATEST)
 *  - UNIQUE (pairMinId, pairMaxId)는 DB 스키마 수준에서 보장
 *  - TypeORM에서는 select=false로 읽기 제외
 */
// ✅ 실제 테이블명: friends
@Entity({ name: 'friends' })
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

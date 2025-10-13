// src/features/friends/entities/friend.entity.ts
import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryColumn,
} from 'typeorm';

/**
 * ✅ friends 테이블 (UUID PK)
 *  - userAId, userBId : 두 사용자 쌍
 *  - pairMinId, pairMaxId : DB 가상 컬럼 (LEAST/GREATEST)
 *  - UNIQUE (pairMinId, pairMaxId)는 DB 스키마 수준에서 보장
 *  - TypeORM에서는 select=false로 읽기 제외
 */
@Entity('friends')
export class FriendEntity {
  /** UUID 기본키 */
  @PrimaryColumn({ type: 'char', length: 36 })
  id!: string;

  /** 사용자 A (정렬 순서 무관) */
  @Index('ixFriendsUserA')
  @Column({ type: 'char', length: 36 })
  userAId!: string;

  /** 사용자 B (정렬 순서 무관) */
  @Index('ixFriendsUserB')
  @Column({ type: 'char', length: 36 })
  userBId!: string;

  /** DB 가상 컬럼 — 쿼리용, select 제외 */
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

  /** 생성 시각 */
  @CreateDateColumn({ type: 'datetime', name: 'createdAt' })
  createdAt!: Date;
}

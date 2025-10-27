// src/features/friends/friends.service.ts
import {
  HttpException,
  HttpStatus,
  Injectable,
  BadRequestException,
  ForbiddenException,
  NotFoundException,     // ✅ 유지
  ConflictException,     // ✅ 유지
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { FriendRequestEntity } from './entities/friend-request.entity';
import { FriendEntity } from './entities/friend.entity';
import { UserBlockEntity } from './entities/user-block.entity';
import { ERR } from './types/errors';
import { makeId, normalizeId, isUuid } from '../../common/utils/ids';
import { User } from '../../modules/users/entities/user.entity';

// ❌ Removed: Conversation / ConversationMessage (participant_a/b column mismatch)
// If you later migrate to a proper Conversation model, re-introduce them with a schema that exists in DB.

// ─────────────────────────────────────────────────────────────
// Utils
// ─────────────────────────────────────────────────────────────
function pair(a: string, b: string) {
  const A = a.toLowerCase();
  const B = b.toLowerCase();
  return A.localeCompare(B) <= 0 ? ([A, B] as const) : ([B, A] as const);
}

function assertUuidLike(v: string, field: string) {
  if (!v || !isUuid(v)) {
    throw new BadRequestException(`${field} must be a UUID (8-4-4-4-12)`);
  }
}

// /friends raw row (legacy type kept in case you need it later)
type RawRow = {
  friendId: string;
  userAId: string;
  userBId: string;
  friendedAt: Date;
  uAId: string;
  uAName: string | null;
  uAEmail: string;
  uBId: string;
  uBName: string | null;
  uBEmail: string;
};

@Injectable()
export class FriendsService {
  constructor(
    private readonly ds: DataSource,
    @InjectRepository(FriendRequestEntity)
    private readonly reqRepo: Repository<FriendRequestEntity>,
    @InjectRepository(FriendEntity)
    private readonly frRepo: Repository<FriendEntity>,
    @InjectRepository(UserBlockEntity)
    private readonly blkRepo: Repository<UserBlockEntity>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {}

  // Unified error payload: { code, message? }
  private e(
    code: keyof typeof ERR,
    status = HttpStatus.BAD_REQUEST,
    msg?: string,
  ) {
    return new HttpException(
      { code: ERR[code], message: msg ?? undefined },
      status,
    );
  }

  private async isBlockedEither(a: string, b: string) {
    const cnt = await this.blkRepo.count({
      where: [
        { blockerId: a, blockedId: b },
        { blockerId: b, blockedId: a },
      ],
    });
    return cnt > 0;
  }
  
  // command
  async sendRequest(me: string, to: string) {
    const from = normalizeId(me);
    const target = normalizeId(to);
    assertUuidLike(from, 'fromUserId');
    assertUuidLike(target, 'toUserId');

    if (from === target) throw this.e('SELF_NOT_ALLOWED');
    if (await this.isBlockedEither(from, target)) throw this.e('BLOCKED', HttpStatus.FORBIDDEN);

    const [A, B] = pair(from, target);
    if (await this.frRepo.exist({ where: { userAId: A, userBId: B } })) {
      throw this.e('ALREADY_FRIEND', HttpStatus.CONFLICT);
    }

    // 역방향 pending 있다면 그대로 반환
    const reversePending = await this.reqRepo.findOne({
      where: { fromUserId: target, toUserId: from, status: 'PENDING' as any },
      order: { createdAt: 'DESC' },
    });
    if (reversePending) return { id: reversePending.id, status: reversePending.status, dedup: true };

    // 신규 삽입 시도 — 항상 id를 **앱에서** 생성
    const newId = makeId();
    const ins = await this.reqRepo
      .createQueryBuilder()
      .insert()
      .into(FriendRequestEntity)
      .values({
        id: newId,             // ★ 여기!
        fromUserId: from,
        toUserId: target,
        status: 'PENDING' as any,
      })
      .orIgnore()
      .execute();

    const affected = (ins as any)?.raw?.affectedRows ?? (ins as any)?.affected ?? 0;

    if (affected > 0) {
      return { id: newId, status: 'PENDING', dedup: false };
    }

    // 같은 방향 PENDING 이미 존재 → dedup
    const pendingSame = await this.reqRepo
      .createQueryBuilder('r')
      .where(
        'LEAST(r.fromUserId, r.toUserId) = LEAST(:a, :b) AND GREATEST(r.fromUserId, r.toUserId) = GREATEST(:a, :b)',
        { a: from, b: target },
      )
      .andWhere('r.status = :s', { s: 'PENDING' })
      .orderBy('r.createdAt', 'DESC')
      .getOne();

    if (pendingSame) return { id: pendingSame.id, status: 'PENDING', dedup: true };

    // 되돌리기 허용 정책: 기존 비-PENDING을 PENDING으로 재활성화
    await this.reqRepo
      .createQueryBuilder()
      .update(FriendRequestEntity)
      .set({ status: 'PENDING' as any, decidedAt: () => 'NULL' })
      .where('fromUserId = :from AND toUserId = :to AND status <> :s', { from, to: target, s: 'PENDING' })
      .execute();

    const nowPending = await this.reqRepo.findOne({
      where: { fromUserId: from, toUserId: target, status: 'PENDING' as any },
      order: { createdAt: 'DESC' },
    });

    return { id: nowPending?.id, status: 'PENDING', dedup: true };
  }


  // Mixed endpoint: email or UUID
  async sendRequestMixed(
    me: string,
    body: { toUserId?: string; targetEmail?: string },
  ) {
    const { toUserId, targetEmail } = body ?? {};
    if (toUserId) return this.sendRequest(me, toUserId);
    const email = (targetEmail ?? '').trim().toLowerCase();
    if (!email || !email.includes('@')) {
      throw new BadRequestException('유효한 이메일이 아닙니다.');
    }
    return this.sendRequestByEmail(me, email);
  }

  async sendRequestByEmail(meId: string, email: string) {
    const me = normalizeId(meId);
    const to = await this.userRepo.findOne({ where: { email: email.toLowerCase() } });
    if (!to) throw new NotFoundException('USER_NOT_FOUND');
    if (to.id === me) throw new BadRequestException('SELF_NOT_ALLOWED');

    const [A, B] = pair(me, to.id);
    const existFriend = await this.frRepo.findOne({ where: { userAId: A, userBId: B } });
    if (existFriend) throw new ConflictException('ALREADY_FRIEND');

    const newId = makeId(); // ★ 여기!

    const insertRes = await this.reqRepo
      .createQueryBuilder()
      .insert()
      .into(FriendRequestEntity)
      .values({
        id: newId,          // ★ 여기!
        fromUserId: me,
        toUserId: to.id,
        status: 'PENDING' as any,
      })
      .orIgnore()
      .execute();

    const affected = (insertRes as any)?.raw?.affectedRows ?? (insertRes as any)?.affected ?? 0;

    if (affected === 0) {
      const pending = await this.reqRepo
        .createQueryBuilder('r')
        .where(
          'LEAST(r.fromUserId, r.toUserId) = LEAST(:a, :b) AND GREATEST(r.fromUserId, r.toUserId) = GREATEST(:a, :b)',
          { a: me, b: to.id },
        )
        .andWhere('r.status = :s', { s: 'PENDING' })
        .orderBy('r.createdAt', 'DESC')
        .getOne();
      return { id: pending?.id, status: 'PENDING', dedup: true };
    }

    return { id: newId, status: 'PENDING', dedup: false };
  }


  /**
   * Accept friend request by requestId (UUID v1/v4 agnostic)
   * - Validates ownership/status
   * - Upserts friends (userAId/userBId sorted)
   * - Upserts 1:1 chat room via (pairMinId, pairMaxId) idempotent key
   * - Upserts members into
   *   chatRoomMembers
   */
  async accept(requestId: string, meUserId: string) {
    const me = normalizeId(meUserId);
    assertUuidLike(requestId, 'requestId');
    assertUuidLike(me, 'meUserId');

    return this.ds.transaction(async (trx) => {
      // 1) 요청 행 잠금 조회
      const fr = await trx.query(
        `
        SELECT id, fromUserId, toUserId, status
        FROM friendRequests
        WHERE id = ? FOR UPDATE
        `,
        [requestId],
      );
      if (!fr.length) throw new BadRequestException('REQUEST_NOT_FOUND');

      const req = fr[0] as {
        id: string;
        fromUserId: string;
        toUserId: string;
        status: 'PENDING' | 'ACCEPTED' | 'REJECTED' | 'CANCELED';
      };

      if (req.toUserId !== me) throw new ForbiddenException('NOT_YOUR_REQUEST');
      if (req.status !== 'PENDING') throw new BadRequestException('ALREADY_RESOLVED');

      // 2) 블락 체크
      const blocked = await trx
        .getRepository(UserBlockEntity)
        .count({
          where: [
            { blockerId: req.fromUserId, blockedId: req.toUserId },
            { blockerId: req.toUserId, blockedId: req.fromUserId },
          ],
        });
      if (blocked) throw this.e('BLOCKED', HttpStatus.FORBIDDEN);

      // 3) 친구 upsert (정렬쌍) — ✅ 신규 id는 앱단 v1로 생성
      const [A, B] = pair(req.fromUserId, req.toUserId);
      const newFriendId = makeId();
      await trx.query(
        `
        INSERT INTO friends (id, userAId, userBId, createdAt)
        VALUES (?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE createdAt = createdAt
        `,
        [newFriendId, A, B],
      );

      // 4) 친구방 보장 — ensureFriendRoom 내부도 v1(makeId) 사용하도록 이미 수정돼 있어야 함
      const roomId = await this.ensureFriendRoom(req.fromUserId, req.toUserId);

      // 5) 요청 상태 갱신(해당 요청 + 동일 방향 PENDING 일괄 정리)
      await trx.query(
        `UPDATE friendRequests SET status='ACCEPTED', decidedAt=NOW() WHERE id=?`,
        [requestId],
      );
      await trx.query(
        `
        UPDATE friendRequests
        SET status='ACCEPTED', decidedAt=IFNULL(decidedAt, NOW())
        WHERE fromUserId = ? AND toUserId = ? AND status = 'PENDING'
        `,
        [req.fromUserId, req.toUserId],
      );

      return { ok: true, roomId };
    });
  }

  async rejectRequest(me: string, reqId: string) {
    const meNorm = normalizeId(me);
    assertUuidLike(meNorm, 'meUserId');

    const req = await this.reqRepo.findOne({ where: { id: reqId } as any });
    if (!req) throw new HttpException('Not Found', HttpStatus.NOT_FOUND);
    if (req.status !== 'PENDING')
      throw this.e('NOT_PENDING', HttpStatus.CONFLICT);
    if (req.toUserId !== meNorm) throw this.e('NOT_TARGET', HttpStatus.FORBIDDEN);

    req.status = 'REJECTED';
    (req as any).decidedAt = new Date();
    await this.reqRepo.save(req);
  }

  async cancelRequest(me: string, reqId: string) {
    const meNorm = normalizeId(me);
    assertUuidLike(meNorm, 'meUserId');

    const req = await this.reqRepo.findOne({ where: { id: reqId } as any });
    if (!req) throw new HttpException('Not Found', HttpStatus.NOT_FOUND);
    if (req.status !== 'PENDING')
      throw this.e('NOT_PENDING', HttpStatus.CONFLICT);
    if (req.fromUserId !== meNorm) throw this.e('NOT_OWNER', HttpStatus.FORBIDDEN);

    req.status = 'CANCELED';
    (req as any).decidedAt = new Date();
    await this.reqRepo.save(req);
  }

  async unfriend(me: string, peer: string) {
    const meNorm   = normalizeId(me);
    const peerNorm = normalizeId(peer);
    assertUuidLike(meNorm, 'meUserId');
    assertUuidLike(peerNorm, 'peerUserId');

    const [A, B] = pair(meNorm, peerNorm);
    const res = await this.frRepo.delete({ userAId: A, userBId: B } as any);
    if (!res.affected) throw this.e('NOT_FRIEND');
  }

  async block(me: string, target: string) {
    const meNorm     = normalizeId(me);
    const targetNorm = normalizeId(target);
    assertUuidLike(meNorm, 'meUserId');
    assertUuidLike(targetNorm, 'targetUserId');
    if (meNorm === targetNorm) throw this.e('SELF_NOT_ALLOWED');

    await this.ds.transaction(async (tx) => {
      const frRepo = tx.getRepository(FriendEntity);
      const reqRepo = tx.getRepository(FriendRequestEntity);
      const blkRepo = tx.getRepository(UserBlockEntity);

      const [A, B] = pair(meNorm, targetNorm);
      await frRepo.softDelete({ userAId: A, userBId: B } as any);

      // 양방향 pending 정리
      const pendings = await reqRepo.find({
        where: [
          { fromUserId: meNorm,     toUserId: targetNorm, status: 'PENDING' } as any,
          { fromUserId: targetNorm, toUserId: meNorm,     status: 'PENDING' } as any,
        ],
      } as any);

      for (const r of pendings) {
        r.status = r.fromUserId === meNorm ? 'CANCELED' : 'REJECTED';
        (r as any).decidedAt = new Date();
        await reqRepo.save(r);
      }

      const existing = await blkRepo.findOne({
        where: { blockerId: meNorm, blockedId: targetNorm } as any,
      });
      if (!existing) {
        await blkRepo.save(
          blkRepo.create({
            id: makeId(), // v1
            blockerId: meNorm,
            blockedId: targetNorm,
          } as any),
        );
      }
    });
  }

  async unblock(me: string, target: string) {
    const meNorm     = normalizeId(me);
    const targetNorm = normalizeId(target);
    assertUuidLike(meNorm, 'meUserId');
    assertUuidLike(targetNorm, 'targetUserId');

    await this.blkRepo.delete({ blockerId: meNorm, blockedId: targetNorm } as any);
  }

  // ===== Queries =====

  // Requests (incoming/outgoing), pending only, newest first
  async listRequestsBox(me: string, box: 'incoming' | 'outgoing') {
    const meNorm = normalizeId(me);
    assertUuidLike(meNorm, 'meUserId');

    const qb = this.reqRepo
      .createQueryBuilder('r')
      .leftJoin(User, 'fu', 'fu.id = r.fromUserId')
      .leftJoin(User, 'tu', 'tu.id = r.toUserId')
      .select([
        'r.id AS id',
        'r.fromUserId AS fromUserId',
        'r.toUserId AS toUserId',
        'r.status AS status',
        'r.createdAt AS createdAt',
        'r.decidedAt AS decidedAt',
        'fu.email AS fromEmail',
        'tu.email AS toEmail',
      ])
      .where(box === 'incoming' ? 'r.toUserId = :me' : 'r.fromUserId = :me', {
        me: meNorm,
      })
      // status 대소문자 무시
      .andWhere('LOWER(r.status) = :pending', { pending: 'pending' })
      .orderBy('r.createdAt', 'DESC');

    const rows = await qb.getRawMany();
    return rows.map((r: any) => ({
      ...r,
      status: String(r.status ?? '').toLowerCase(),
    }));
  }

  /**
   * 친구 채팅방을 멱등하게 생성하고 roomId 반환
   * - 이미 존재하면 그대로 반환
   * - 없으면 UUID로 새 room 생성
   */
  async ensureFriendRoom(meId: string, peerId: string): Promise<string> {
    const me = normalizeId(meId);
    const peer = normalizeId(peerId);
    assertUuidLike(me, 'meUserId');
    assertUuidLike(peer, 'peerUserId');

    const [A, B] = pair(me, peer);

    return this.ds.transaction(async (trx) => {
      const newRoomId = makeId(); // v1 생성

      await trx.query(
        `
        INSERT INTO chatRooms (id, type, productId, buyerId, sellerId, createdAt)
        VALUES (?, 'FRIEND', NULL, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE id = id
        `,
        [newRoomId, A, B],
      );

      const rows = await trx.query(
        `
        SELECT id FROM chatRooms
        WHERE type='FRIEND' AND productId IS NULL
          AND buyerId=? AND sellerId=?
        LIMIT 1
        `,
        [A, B],
      );

      const roomId = rows?.[0]?.id as string | undefined;
      if (!roomId) throw new BadRequestException('ROOM_RESOLVE_FAILED');
      return roomId;
    });
  }

  /**
   * Friends list (soft-deleted excluded).
   * Returns the peer profile (id, name/email, email) and friendedAt.
   */
  async listFriends(meId: string) {
    const meNorm = normalizeId(meId);
    assertUuidLike(meNorm, 'meUserId');

    const sql = `
      SELECT
        f.id AS friendId,
        CASE WHEN f.userAId = ? THEN f.userBId ELSE f.userAId END AS peerId,
        COALESCE(
          CASE WHEN f.userAId = ? THEN uB.name ELSE uA.name END,
          CASE WHEN f.userAId = ? THEN uB.email ELSE uA.email END
        ) AS peerNameOrEmail,
        CASE WHEN f.userAId = ? THEN uB.email ELSE uA.email END AS peerEmail,
        f.createdAt AS friendedAt
      FROM friends f
      LEFT JOIN users uA ON uA.id = f.userAId
      LEFT JOIN users uB ON uB.id = f.userBId
      WHERE (f.userAId = ? OR f.userBId = ?)
      ORDER BY f.createdAt DESC
    `;

    type Row = {
      friendId: string;
      peerId: string;
      peerNameOrEmail: string;
      peerEmail: string;
      friendedAt: string | Date;
    };

    const rows = (await this.ds.query(sql, [
      meNorm, // CASE
      meNorm, // COALESCE name
      meNorm, // COALESCE fallback email
      meNorm, // peerEmail
      meNorm, // WHERE
      meNorm, // WHERE
    ])) as Row[];

    return rows.map((r) => ({
      friendId: r.friendId,
      peerId: r.peerId,
      peerNameOrEmail: r.peerNameOrEmail,
      peerEmail: r.peerEmail,
      friendedAt: r.friendedAt,
    }));
  }
}

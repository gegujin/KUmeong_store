// // C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\friends.service.ts
// import { HttpException, HttpStatus, Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
// import { InjectRepository } from '@nestjs/typeorm';
// import { DataSource, Repository } from 'typeorm';
// import { FriendRequestEntity } from './entities/friend-request.entity';
// import { FriendEntity } from './entities/friend.entity';
// import { UserBlockEntity } from './entities/user-block.entity';
// import { ERR } from './types/errors';
// import { FriendSummaryDto } from './types/friend-summary.dto';
// import { randomUUID } from 'crypto';
// import { UserEntity } from '../users/entities/user.entity';

// function pair(a: string, b: string) {
//   return a.localeCompare(b) <= 0 ? ([a, b] as const) : ([b, a] as const);
// }

// @Injectable()
// export class FriendsService {
//   constructor(
//     private readonly ds: DataSource,
//     @InjectRepository(FriendRequestEntity)
//     private readonly reqRepo: Repository<FriendRequestEntity>,
//     @InjectRepository(FriendEntity)
//     private readonly frRepo: Repository<FriendEntity>,
//     @InjectRepository(UserBlockEntity)
//     private readonly blkRepo: Repository<UserBlockEntity>,
//     @InjectRepository(UserEntity)
//     private readonly userRepo: Repository<UserEntity>,
//   ) {}

//   private e(code: keyof typeof ERR, status = HttpStatus.BAD_REQUEST) {
//     return new HttpException({ error: ERR[code], code }, status);
//   }

//   private async isBlockedEither(a: string, b: string) {
//     const cnt = await this.blkRepo.count({
//       where: [{ blockerId: a, blockedId: b }, { blockerId: b, blockedId: a }],
//     });
//     return cnt > 0;
//   }

//   // ===== Commands =====
//   async sendRequest(me: string, to: string) {
//     if (me === to) throw this.e('SELF_NOT_ALLOWED');
//     if (await this.isBlockedEither(me, to)) throw this.e('BLOCKED');

//     const [A, B] = pair(me, to);
//     if (await this.frRepo.exist({ where: { userAId: A, userBId: B } })) {
//       throw this.e('ALREADY_FRIEND');
//     }

//     // 상대가 먼저 보낸 PENDING 있으면 중복 방지
//     const reversePending = await this.reqRepo.exist({
//       where: { fromUserId: to, toUserId: me, status: 'PENDING' },
//     });
//     if (reversePending) throw this.e('ALREADY_REQUESTED');

//     // 같은 방향 행이 있으면 재활성화
//     const existing = await this.reqRepo.findOne({ where: { fromUserId: me, toUserId: to } });
//     if (existing) {
//       if (existing.status === 'PENDING') throw this.e('ALREADY_REQUESTED');
//       existing.status = 'PENDING';
//       (existing as any).decidedAt = null;
//       await this.reqRepo.save(existing);
//       return;
//     }

//     // 새로 생성 — 요청 PK가 BIGINT AI라고 가정(직접 주입 X)
//     await this.reqRepo.save(
//       this.reqRepo.create({
//         fromUserId: me,
//         toUserId: to,
//         status: 'PENDING',
//       } as any),
//     );
//   }

//   // 이메일로 대상 찾은 뒤 기존 sendRequest 재사용
//   async sendRequestByEmail(me: string, toEmail: string) {
//     const email = (toEmail ?? '').trim();
//     if (!email.includes('@')) {
//       throw new BadRequestException('유효한 이메일이 아닙니다.');
//     }
//     const to = await this.userRepo.findOne({ where: { email } });
//     if (!to) {
//       throw new NotFoundException('사용자를 찾을 수 없습니다.');
//     }
//     return this.sendRequest(me, (to as any).id);
//   }

//   /**
//    * 친구요청 수락 (UUID 사용자, 요청 ID는 BIGINT number)
//    * - 요청 존재/권한/상태 검증
//    * - friends (A,B) 1행 생성 (DB 유니크로 멱등 보장) — UUID PK 스키마이므로 id: randomUUID()
//    * - 요청 상태 'ACCEPTED'로 갱신
//    * - 반대방향 PENDING도 정리
//    */
//   async acceptRequest(me: string, reqId: number) {
//     await this.ds.transaction(async (tx) => {
//       const reqRepo = tx.getRepository(FriendRequestEntity);
//       const frRepo = tx.getRepository(FriendEntity);
//       const blkRepo = tx.getRepository(UserBlockEntity);

//       const req = await reqRepo.findOne({ where: { id: reqId as any } });
//       if (!req) throw new HttpException('Not Found', HttpStatus.NOT_FOUND);
//       if ((req as any).status !== 'PENDING') throw this.e('NOT_PENDING');
//       if ((req as any).toUserId !== me) throw this.e('NOT_TARGET', HttpStatus.FORBIDDEN);

//       // 차단 여부 최종 확인
//       const blocked = await blkRepo.count({
//         where: [
//           { blockerId: (req as any).fromUserId, blockedId: (req as any).toUserId },
//           { blockerId: (req as any).toUserId, blockedId: (req as any).fromUserId },
//         ],
//       });
//       if (blocked) throw this.e('BLOCKED');

//       const [A, B] = pair((req as any).fromUserId, (req as any).toUserId);

//       // friends (A,B) upsert — UUID PK 스키마라 id 필요. 유니크(pairMinId,pairMaxId)로 orIgnore 멱등화.
//       await tx
//         .createQueryBuilder()
//         .insert()
//         .into(FriendEntity)
//         .values({ id: randomUUID(), userAId: A, userBId: B } as any)
//         .orIgnore()
//         .execute();

//       // 요청 상태 갱신
//       (req as any).status = 'ACCEPTED';
//       (req as any).decidedAt = new Date();
//       await reqRepo.save(req);

//       // 반대방향 PENDING 정리
//       await reqRepo
//         .createQueryBuilder()
//         .update(FriendRequestEntity)
//         .set({ status: 'ACCEPTED' } as any)
//         .where('fromUserId = :peer AND toUserId = :me AND status = :pending', {
//           peer: (req as any).fromUserId,
//           me,
//           pending: 'PENDING',
//         })
//         .execute();
//     });
//   }

//   async rejectRequest(me: string, reqId: number) {
//     const req = await this.reqRepo.findOne({ where: { id: reqId as any } });
//     if (!req) throw new HttpException('Not Found', HttpStatus.NOT_FOUND);
//     if ((req as any).status !== 'PENDING') throw this.e('NOT_PENDING');
//     if ((req as any).toUserId !== me) throw this.e('NOT_TARGET', HttpStatus.FORBIDDEN);

//     (req as any).status = 'REJECTED';
//     (req as any).decidedAt = new Date();
//     await this.reqRepo.save(req);
//   }

//   async cancelRequest(me: string, reqId: number) {
//     const req = await this.reqRepo.findOne({ where: { id: reqId as any } });
//     if (!req) throw new HttpException('Not Found', HttpStatus.NOT_FOUND);
//     if ((req as any).status !== 'PENDING') throw this.e('NOT_PENDING');
//     if ((req as any).fromUserId !== me) throw this.e('NOT_OWNER', HttpStatus.FORBIDDEN);

//     (req as any).status = 'CANCELLED';
//     (req as any).decidedAt = new Date();
//     await this.reqRepo.save(req);
//   }

//   async unfriend(me: string, peer: string) {
//     const [A, B] = pair(me, peer);
//     const res = await this.frRepo.delete({ userAId: A, userBId: B } as any);
//     if (!res.affected) throw this.e('NOT_FRIEND');
//   }

//   async block(me: string, target: string) {
//     if (me === target) throw this.e('SELF_NOT_ALLOWED');

//     await this.ds.transaction(async (tx) => {
//       const frRepo = tx.getRepository(FriendEntity);
//       const reqRepo = tx.getRepository(FriendRequestEntity);
//       const blkRepo = tx.getRepository(UserBlockEntity);

//       // 친구면 끊기
//       const [A, B] = pair(me, target);
//       await frRepo.delete({ userAId: A, userBId: B } as any);

//       // 대기중 요청 정리
//       const pendings = await reqRepo.find({
//         where: [
//           { fromUserId: me, toUserId: target, status: 'PENDING' } as any,
//           { fromUserId: target, toUserId: me, status: 'PENDING' } as any,
//         ],
//       });

//       for (const r of pendings) {
//         (r as any).status = (r as any).fromUserId === me ? 'CANCELLED' : 'REJECTED';
//         (r as any).decidedAt = new Date();
//         await reqRepo.save(r);
//       }

//       // 차단 추가 — 블록 PK가 AI면 id 주입 불필요
//       const existing = await blkRepo.findOne({ where: { blockerId: me, blockedId: target } as any });
//       if (!existing) {
//         await blkRepo.save(blkRepo.create({ blockerId: me, blockedId: target } as any));
//       }
//     });
//   }

//   async unblock(me: string, target: string) {
//     await this.blkRepo.delete({ blockerId: me, blockedId: target } as any);
//   }

//   // ===== Queries =====

//   async listRequests(meId: string) {
//     const rows = await this.reqRepo
//       .createQueryBuilder('r')
//       .leftJoin(UserEntity, 'fu', 'fu.id = r.fromUserId')
//       .leftJoin(UserEntity, 'tu', 'tu.id = r.toUserId')
//       .select([
//         'r.id AS id',
//         'r.fromUserId AS fromUserId',
//         'r.toUserId AS toUserId',
//         'r.status AS status',
//         'r.createdAt AS createdAt',
//         'r.decidedAt AS decidedAt',
//         'fu.email AS fromEmail',
//         'tu.email AS toEmail',
//       ])
//       .where('r.fromUserId = :me OR r.toUserId = :me', { me: meId })
//       .orderBy('r.createdAt', 'DESC')
//       .getRawMany();

//     const received = rows.filter((r) => r.toUserId === meId);
//     const sent = rows.filter((r) => r.fromUserId === meId);

//     return { received, sent };
//   }

//   /**
//    * DB 뷰를 사용해 친구 리스트 반환
//    *  - vwFriendsForUser: (meId, peerUserId, friendedAt)
//    *  - vwUserTrustTrade: (userId, displayName, avgRating, reviewCount, tradeCount)
//    */
//   async listFriends(me: string): Promise<FriendSummaryDto[]> {
//     const rows = await this.ds.query(
//       `
//       SELECT
//         f.peerUserId   AS userId,
//         u.displayName  AS displayName,
//         u.avgRating    AS trustScore,
//         u.reviewCount  AS reviewCount,
//         u.tradeCount   AS tradeCount,
//         f.friendedAt   AS friendedAt
//       FROM vwFriendsForUser f
//       LEFT JOIN vwUserTrustTrade u
//         ON u.userId = f.peerUserId
//       WHERE f.meId = ?
//       ORDER BY f.friendedAt DESC
//       `,
//       [me],
//     );

//     return rows.map((r: any) => ({
//       userId: r.userId,
//       displayName: r.displayName ?? '',
//       trustScore: Number(r.trustScore ?? 0),
//       tradeCount: Number(r.tradeCount ?? 0),
//       topItems: [],
//       lastActiveAt: null,
//     }));
//   }
// }

























// C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\friends.service.ts
import { HttpException, HttpStatus, Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { FriendRequestEntity } from './entities/friend-request.entity';
import { FriendEntity } from './entities/friend.entity';
import { UserBlockEntity } from './entities/user-block.entity';
import { ERR } from './types/errors';
import { FriendSummaryDto } from './types/friend-summary.dto';
import { randomUUID } from 'crypto';
import { User } from '../../modules/users/entities/user.entity';
import { normalizeId, isUuid } from '../../common/utils/ids'; // ✅ 추가: 정규화/검증 유틸

function pair(a: string, b: string) {
  return a.localeCompare(b) <= 0 ? ([a, b] as const) : ([b, a] as const);
}

// ✅ 추가: UUID 포맷 검증 헬퍼
function assertUuidLike(v: string, field: string) {
  if (!v || !isUuid(v)) {
    throw new BadRequestException(`${field} must be a UUID (8-4-4-4-12)`);
  }
}

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

  // 에러 페이로드 통일: { code, message? }
  private e(code: keyof typeof ERR, status = HttpStatus.BAD_REQUEST, msg?: string) {
    return new HttpException({ code: ERR[code], message: msg ?? undefined }, status);
  }

  private async isBlockedEither(a: string, b: string) {
    const cnt = await this.blkRepo.count({
      where: [{ blockerId: a, blockedId: b }, { blockerId: b, blockedId: a }],
    });
    return cnt > 0;
  }

  // ===== Commands =====
  async sendRequest(me: string, to: string) {
    // ✅ 1) 숫자/UUID 혼용 대비: 즉시 정규화 + 검증
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

    // 상대가 먼저 보낸 PENDING 있으면 중복 방지
    const reversePending = await this.reqRepo.exist({
      where: { fromUserId: target, toUserId: from, status: 'PENDING' },
    });
    if (reversePending) throw this.e('ALREADY_REQUESTED', HttpStatus.CONFLICT);

    // 같은 방향 행이 있으면 재활성화
    const existing = await this.reqRepo.findOne({ where: { fromUserId: from, toUserId: target } });
    if (existing) {
      if (existing.status === 'PENDING') throw this.e('ALREADY_REQUESTED', HttpStatus.CONFLICT);
      existing.status = 'PENDING';
      (existing as any).decidedAt = null;
      await this.reqRepo.save(existing);
      return;
    }

    // ✅ 2) 새로 생성 — PK/외래 모두 UUID(CHAR(36))로 저장
    await this.reqRepo.save(
      this.reqRepo.create({
        id: randomUUID(),
        fromUserId: from,
        toUserId: target,
        status: 'PENDING',
      }),
    );
  }

  // 이메일/UUID 혼합 엔드포인트용
  async sendRequestMixed(me: string, body: { toUserId?: string; targetEmail?: string }) {
    const { toUserId, targetEmail } = body ?? {};
    if (toUserId) return this.sendRequest(me, toUserId);
    const email = (targetEmail ?? '').trim().toLowerCase();
    if (!email || !email.includes('@')) throw new BadRequestException('유효한 이메일이 아닙니다.');
    return this.sendRequestByEmail(me, email);
  }

  // 이메일로 대상 찾은 뒤 기존 sendRequest 재사용
  async sendRequestByEmail(me: string, toEmail: string) {
    const email = (toEmail ?? '').trim().toLowerCase();
    const to = await this.userRepo.findOne({ where: { email } });
    if (!to) throw this.e('NOT_TARGET', HttpStatus.NOT_FOUND, '사용자를 찾을 수 없습니다.');
    return this.sendRequest(me, to.id); // ✅ sendRequest 내부에서 다시 정규화/검증
  }

  /**
   * 친구요청 수락 (요청 ID = UUID)
   */
  async acceptRequest(me: string, reqId: string) {
    await this.ds.transaction(async (tx) => {
      const reqRepo = tx.getRepository(FriendRequestEntity);
      const frRepo = tx.getRepository(FriendEntity);
      const blkRepo = tx.getRepository(UserBlockEntity);

      const req = await reqRepo.findOne({ where: { id: reqId } as any });
      if (!req) throw new HttpException('Not Found', HttpStatus.NOT_FOUND);
      if (req.status !== 'PENDING') throw this.e('NOT_PENDING', HttpStatus.CONFLICT);
      if (req.toUserId !== me) throw this.e('NOT_TARGET', HttpStatus.FORBIDDEN);

      // 차단 여부 최종 확인
      const blocked = await blkRepo.count({
        where: [
          { blockerId: req.fromUserId, blockedId: req.toUserId },
          { blockerId: req.toUserId, blockedId: req.fromUserId },
        ],
      });
      if (blocked) throw this.e('BLOCKED', HttpStatus.FORBIDDEN);

      const [A, B] = pair(req.fromUserId, req.toUserId);

      // friends upsert (orIgnore)
      await tx
        .createQueryBuilder()
        .insert()
        .into(FriendEntity)
        .values({ id: randomUUID(), userAId: A, userBId: B } as any)
        .orIgnore()
        .execute();

      // 요청 상태 갱신
      req.status = 'ACCEPTED';
      (req as any).decidedAt = new Date();
      await reqRepo.save(req);

      // 반대방향 PENDING 정리
      await reqRepo
        .createQueryBuilder()
        .update(FriendRequestEntity)
        .set({ status: 'ACCEPTED' } as any)
        .where('fromUserId = :peer AND toUserId = :me AND status = :pending', {
          peer: req.fromUserId,
          me,
          pending: 'PENDING',
        })
        .execute();
    });
  }

  async rejectRequest(me: string, reqId: string) {
    const req = await this.reqRepo.findOne({ where: { id: reqId } as any });
    if (!req) throw new HttpException('Not Found', HttpStatus.NOT_FOUND);
    if (req.status !== 'PENDING') throw this.e('NOT_PENDING', HttpStatus.CONFLICT);
    if (req.toUserId !== me) throw this.e('NOT_TARGET', HttpStatus.FORBIDDEN);

    req.status = 'REJECTED';
    (req as any).decidedAt = new Date();
    await this.reqRepo.save(req);
  }

  async cancelRequest(me: string, reqId: string) {
    const req = await this.reqRepo.findOne({ where: { id: reqId } as any });
    if (!req) throw new HttpException('Not Found', HttpStatus.NOT_FOUND);
    if (req.status !== 'PENDING') throw this.e('NOT_PENDING', HttpStatus.CONFLICT);
    if (req.fromUserId !== me) throw this.e('NOT_OWNER', HttpStatus.FORBIDDEN);

    req.status = 'CANCELED';
    (req as any).decidedAt = new Date();
    await this.reqRepo.save(req);
  }

  async unfriend(me: string, peer: string) {
    const [A, B] = pair(me, peer);
    const res = await this.frRepo.delete({ userAId: A, userBId: B } as any);
    if (!res.affected) throw this.e('NOT_FRIEND');
  }

  async block(me: string, target: string) {
    if (me === target) throw this.e('SELF_NOT_ALLOWED');

    await this.ds.transaction(async (tx) => {
      const frRepo = tx.getRepository(FriendEntity);
      const reqRepo = tx.getRepository(FriendRequestEntity);
      const blkRepo = tx.getRepository(UserBlockEntity);

      const [A, B] = pair(me, target);
      await frRepo.delete({ userAId: A, userBId: B } as any);

      const pendings = await reqRepo.find({
        where: [
          { fromUserId: me, toUserId: target, status: 'PENDING' } as any,
          { fromUserId: target, toUserId: me, status: 'PENDING' } as any,
        ],
      });

      for (const r of pendings) {
        r.status = r.fromUserId === me ? 'CANCELED' : 'REJECTED';
        (r as any).decidedAt = new Date();
        await reqRepo.save(r);
      }

      const existing = await blkRepo.findOne({ where: { blockerId: me, blockedId: target } as any });
      if (!existing) {
        await blkRepo.save(blkRepo.create({ id: randomUUID(), blockerId: me, blockedId: target } as any));
      }
    });
  }

  async unblock(me: string, target: string) {
    await this.blkRepo.delete({ blockerId: me, blockedId: target } as any);
  }

  // ===== Queries =====

  // 박스별 목록 (status는 소문자로 변환해 반환)
  async listRequestsBox(me: string, box: 'incoming' | 'outgoing') {
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
      .where(box === 'incoming' ? 'r.toUserId = :me' : 'r.fromUserId = :me', { me })
      .andWhere('r.status = :pending', { pending: 'PENDING' })
      .orderBy('r.createdAt', 'DESC');

    const rows = await qb.getRawMany();
    return rows.map((r) => ({
      ...r,
      status: String(r.status ?? '').toLowerCase(),
    }));
  }

  /**
   * DB 뷰를 사용해 친구 리스트 반환
   *  - vwFriendsForUser: (meId, peerUserId, friendedAt)
   *  - vwUserTrustTrade: (userId, displayName, avgRating, reviewCount, tradeCount)
   */
  async listFriends(me: string): Promise<FriendSummaryDto[]> {
    const rows = await this.ds.query(
      `
      SELECT
        f.peerUserId   AS userId,
        u.displayName  AS displayName,
        u.avgRating    AS trustScore,
        u.reviewCount  AS reviewCount,
        u.tradeCount   AS tradeCount,
        f.friendedAt   AS friendedAt
      FROM vwFriendsForUser f
      LEFT JOIN vwUserTrustTrade u
        ON u.userId = f.peerUserId
      WHERE f.meId = ?
      ORDER BY f.friendedAt DESC
      `,
      [me],
    );

    return rows.map((r: any) => ({
      userId: r.userId,
      displayName: r.displayName ?? '',
      trustScore: Number(r.trustScore ?? 0),
      tradeCount: Number(r.tradeCount ?? 0),
      topItems: [],
      lastActiveAt: null,
    }));
  }
}

// src/features/friends/friend-requests.service.ts
import {
  Injectable,
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { DataSource } from 'typeorm';

type Box = 'incoming' | 'outgoing';

@Injectable()
export class FriendRequestsService {
  constructor(private readonly ds: DataSource) {}

  // ─────────────────────────────────────────────────────────
  // 공개 API: 이메일 기반
  // ─────────────────────────────────────────────────────────

  /** 친구요청 생성 (이메일) */
  async createByEmail(meId: string, targetEmail: string) {
    const toId = await this.idByEmail(targetEmail);
    if (!toId || toId === meId) {
      throw new BadRequestException('invalid target (self or empty)');
    }

    // 이미 보낸 PENDING 있으면 그대로 반환(dedup=true)
    const existing = await this.ds.query(
      `SELECT id FROM friendRequests
        WHERE fromUserId=? AND toUserId=? AND status='PENDING'
        LIMIT 1`,
      [meId, toId],
    );
    if (existing?.length) {
      return { id: existing[0].id as string, status: 'PENDING', dedup: true };
    }

    // 반대 방향으로 받은 PENDING이 있더라도 일단 생성 허용(정책에 따라 차단 가능)
    // 필요한 경우 여기서 차단 로직 추가 가능.

    // DB에서 v1 UUID 생성
    const [{ id }] = await this.ds.query(`SELECT UUID() AS id`);

    try {
      await this.ds.query(
        `INSERT INTO friendRequests (id, fromUserId, toUserId, status, createdAt)
         VALUES (?, ?, ?, 'PENDING', NOW())`,
        [id, meId, toId],
      );
      return { id, status: 'PENDING', dedup: false };
    } catch (e: any) {
      const msg = (e?.sqlMessage || e?.message || '').toLowerCase();
      if (msg.includes('duplicate') || msg.includes('pending')) {
        // 유니크 제약 등으로 막혔으면 멱등 응답
        return { status: 'PENDING', dedup: true };
      }
      throw new BadRequestException('failed to create friend request');
    }
  }

  /** 친구요청 취소 (보낸 사람, 이메일) */
  async cancelByEmail(meId: string, targetEmail: string) {
    const toId = await this.idByEmail(targetEmail);

    const res = await this.ds.query(
      `UPDATE friendRequests
          SET status='CANCELED', decidedAt=NOW()
        WHERE fromUserId=? AND toUserId=? AND status='PENDING'`,
      [meId, toId],
    );

    if (!affected(res)) {
      // 존재여부
      const exists = await this.ds.query(
        `SELECT 1 FROM friendRequests WHERE fromUserId=? AND toUserId=? LIMIT 1`,
        [meId, toId],
      );
      if (!exists.length) throw new NotFoundException('요청을 찾을 수 없습니다.');
      // 상태
      const pending = await this.ds.query(
        `SELECT 1 FROM friendRequests WHERE fromUserId=? AND toUserId=? AND status='PENDING' LIMIT 1`,
        [meId, toId],
      );
      if (!pending.length) throw new BadRequestException('이미 종결된 요청입니다.');
    }
    return { ok: true };
  }

  /** 친구요청 수락/거절 (받은 사람, 이메일) */
  async decideByEmail(meId: string, fromEmail: string, action: 'accept' | 'reject') {
    const fromId = await this.idByEmail(fromEmail);
    const next = action === 'accept' ? 'ACCEPTED' : 'REJECTED';

    const res = await this.ds.query(
      `UPDATE friendRequests
          SET status=?, decidedAt=NOW()
        WHERE fromUserId=? AND toUserId=? AND status='PENDING'`,
      [next, fromId, meId],
    );

    if (!affected(res)) {
      const exists = await this.ds.query(
        `SELECT 1 FROM friendRequests WHERE fromUserId=? AND toUserId=? LIMIT 1`,
        [fromId, meId],
      );
      if (!exists.length) throw new NotFoundException('요청을 찾을 수 없습니다.');
      const pending = await this.ds.query(
        `SELECT 1 FROM friendRequests WHERE fromUserId=? AND toUserId=? AND status='PENDING' LIMIT 1`,
        [fromId, meId],
      );
      if (!pending.length) throw new BadRequestException('이미 종결된 요청입니다.');
    }
    return { ok: true };
  }

  /** 목록 (이메일 UI용: PENDING만) */
  async list(meId: string, box: Box) {
    const isIncoming = box === 'incoming';
    const where =
      isIncoming
        ? `r.toUserId = ? AND r.status='PENDING'`
        : `r.fromUserId = ? AND r.status='PENDING'`;
    const otherJoin =
      isIncoming
        ? `LEFT JOIN users ou ON ou.id = r.fromUserId`
        : `LEFT JOIN users ou ON ou.id = r.toUserId`;

    return this.ds.query(
      `
      SELECT
        r.id AS id,
        ${isIncoming ? 'r.fromUserId' : 'r.toUserId'} AS otherUserId,
        COALESCE(ou.name, ou.email) AS otherName,
        ou.email AS otherEmail,
        r.createdAt AS requestedAt,
        r.status
      FROM friendRequests r
      ${otherJoin}
      WHERE ${where}
      ORDER BY r.createdAt DESC
      `,
      [meId],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 내부 헬퍼 및 기존(by id) 경로 (컨트롤러/다른 서비스에서 재사용 가능)
  // ─────────────────────────────────────────────────────────

  /** (내부) 이메일 → UUIDv1 조회 */
  private async idByEmail(email: string): Promise<string> {
    if (!email?.includes('@')) throw new BadRequestException('invalid email');
    const rows = await this.ds.query(
      `SELECT id FROM users WHERE LOWER(email)=LOWER(?) AND deletedAt IS NULL LIMIT 1`,
      [email],
    );
    if (!rows?.length) throw new NotFoundException('USER_NOT_FOUND');
    return rows[0].id as string; // v1
  }

  /** (내부) toUserId로 생성 — 이메일 API에서 재사용 */
  private async create(me: string, toUserId: string) {
    if (!toUserId || toUserId === me) {
      throw new BadRequestException('invalid toUserId');
    }

    // 멱등: 기존 PENDING 있으면 그거 반환
    const existing = await this.ds.query(
      `SELECT id FROM friendRequests
        WHERE fromUserId=? AND toUserId=? AND status='PENDING'
        LIMIT 1`,
      [me, toUserId],
    );
    if (existing?.length) {
      return { id: existing[0].id as string, status: 'PENDING', dedup: true };
    }

    const [{ id }] = await this.ds.query(`SELECT UUID() AS id`);
    try {
      await this.ds.query(
        `INSERT INTO friendRequests (id, fromUserId, toUserId, status, createdAt)
         VALUES (?, ?, ?, 'PENDING', NOW())`,
        [id, me, toUserId],
      );
      return { id, status: 'PENDING', dedup: false };
    } catch (e: any) {
      const msg = (e?.sqlMessage || e?.message || '').toLowerCase();
      if (msg.includes('duplicate') || msg.includes('pending') || msg.includes('already')) {
        return { status: 'PENDING', dedup: true };
      }
      throw new BadRequestException('failed to create friend request');
    }
  }

  /**
   * (유지) 상태 전이 — id 경로
   * - cancel: 보낸 사람만 가능
   * - accept/reject: 받은 사람만 가능
   */
  async update(me: string, id: string, action: 'accept' | 'reject' | 'cancel') {
    let res: any;

    if (action === 'cancel') {
      res = await this.ds.query(
        `UPDATE friendRequests
            SET status='CANCELED', decidedAt = NOW()
          WHERE id = ? AND fromUserId = ? AND status='PENDING'`,
        [id, me],
      );
      if (!affected(res)) {
        const exists = await this.exists(id);
        if (!exists) throw new NotFoundException('요청을 찾을 수 없습니다.');
        const owned = await this.isFrom(me, id);
        if (!owned) throw new ForbiddenException('내가 보낸 요청만 취소할 수 있습니다.');
        throw new BadRequestException('이미 종결된 요청입니다.');
      }
      return { ok: true };
    }

    const next = action === 'accept' ? 'ACCEPTED' : 'REJECTED';
    res = await this.ds.query(
      `UPDATE friendRequests
          SET status=?, decidedAt = NOW()
        WHERE id = ? AND toUserId = ? AND status='PENDING'`,
      [next, id, me],
    );
    if (!affected(res)) {
      const exists = await this.exists(id);
      if (!exists) throw new NotFoundException('요청을 찾을 수 없습니다.');
      const mine = await this.isTo(me, id);
      if (!mine) throw new ForbiddenException('내가 받은 요청만 처리할 수 있습니다.');
      throw new BadRequestException('이미 종결된 요청입니다.');
    }
    return { ok: true };
  }

  // ── helpers (by id) ─────────────────────────────────────
  private async exists(id: string) {
    const rows = await this.ds.query(
      `SELECT 1 FROM friendRequests WHERE id=? LIMIT 1`,
      [id],
    );
    return rows.length > 0;
  }

  private async isFrom(userId: string, id: string) {
    const rows = await this.ds.query(
      `SELECT 1 FROM friendRequests WHERE id=? AND fromUserId=? LIMIT 1`,
      [id, userId],
    );
    return rows.length > 0;
  }

  private async isTo(userId: string, id: string) {
    const rows = await this.ds.query(
      `SELECT 1 FROM friendRequests WHERE id=? AND toUserId=? LIMIT 1`,
      [id, userId],
    );
    return rows.length > 0;
  }
}

/** mysql/mariadb 드라이버의 affectedRows 호환 */
function affected(result: any): boolean {
  const ok = Array.isArray(result) ? result[0] : result;
  return !!(ok && typeof ok.affectedRows === 'number' ? ok.affectedRows > 0 : ok?.changes > 0);
}

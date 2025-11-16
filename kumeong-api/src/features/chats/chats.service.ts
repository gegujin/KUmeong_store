// src/features/chats/chats.service.ts  (MySQL 전용 간소화)
import { BadRequestException, Injectable, Optional } from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { v1 as uuidv1 } from 'uuid';
import { ChatMessage } from '../../features/chats/entities/chat-message.entity';

// ── UUID 유틸 ──────────────────────────────────────────────
// 엄격 UUID(v1~v5) 검증: meUserId, sellerId 등에 사용
const UUID_RE =
 /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// 느슨한 36자 UUID 형태(버전 미검증): seeding productId 호환용
const UUID36_LOOSE = /^[0-9a-f-]{36}$/i;

function assertUuidLike(val: string | null | undefined, name = 'id') {
  if (!val || typeof val !== 'string' || !UUID_RE.test(val)) {
    throw new BadRequestException(`${name} invalid`);
  }
}

// createdAt(ms) → 의사 seq
function seqFromDate(d: Date) {
  return Math.floor(d.getTime());
}

type ChatMessageWire = {
  id: string;
  roomId: string;
  senderId: string;
  text: string;
  timestamp: string; // ISO 8601
  seq: number;       // int
  readByMe?: boolean;
};

@Injectable()
export class ChatsService {
  constructor(
    private readonly ds: DataSource,
    @Optional() @InjectRepository(ChatMessage) private readonly msgRepo?: Repository<ChatMessage>,
  ) {}

  // ── 존재/멤버십 확인 ─────────────────────────────────────
  async ensureRoomExists(roomId: string): Promise<boolean> {
    const row = await this.ds.query(
      `SELECT id FROM chatRooms WHERE id = ? LIMIT 1`,
      [roomId],
    );
    return row.length > 0;
  }

  async ensureRoomMember(roomId: string, userId: string): Promise<boolean> {
    const rows = await this.ds.query(
      `SELECT id FROM chatRooms WHERE id = ? AND (buyerId = ? OR sellerId = ?) LIMIT 1`,
      [roomId, userId, userId],
    );
    return rows.length > 0;
  }

  // ── 친구 DM 방 보장 ─────────────────────────────────────
  async ensureFriendRoom(args: { meUserId: string; peerUserId: string }): Promise<string> {
    let { meUserId, peerUserId } = args;

    if (!meUserId || !peerUserId) throw new BadRequestException('MISSING_USER_ID');
    if (meUserId === peerUserId) throw new BadRequestException('SELF_DM_NOT_ALLOWED');
    assertUuidLike(meUserId, 'meUserId');
    assertUuidLike(peerUserId, 'peerUserId');

    const [meRow] = await this.ds.query(
      `SELECT id FROM users WHERE id = ? AND deletedAt IS NULL LIMIT 1`,
      [meUserId],
    );
    if (!meRow) throw new BadRequestException('ME_USER_NOT_FOUND');

    const [peerRow] = await this.ds.query(
      `SELECT id FROM users WHERE id = ? AND deletedAt IS NULL LIMIT 1`,
      [peerUserId],
    );
    if (!peerRow) throw new BadRequestException('PEER_USER_NOT_FOUND');

    // 페어 정규화 (a<b) → a=buyerId, b=sellerId
    const [a, b] = [meUserId, peerUserId].sort();

    // chatRooms UNIQUE(type, pairMinId, pairMaxId, productIdNorm) 가정
    await this.ds.query(
      `
      INSERT INTO chatRooms (id, \`type\`, productId, buyerId, sellerId, createdAt)
      VALUES (UUID(), 'FRIEND', NULL, ?, ?, NOW())
      ON DUPLICATE KEY UPDATE id = id
      `,
      [a, b],
    );

    const rows = await this.ds.query(
      `
      SELECT id
      FROM chatRooms
      WHERE \`type\` = 'FRIEND'
        AND productId IS NULL
        AND buyerId = ?
        AND sellerId = ?
      LIMIT 1
      `,
      [a, b],
    );
    if (!rows?.length) throw new Error('ROOM_RESOLVE_FAILED');
    return rows[0].id as string;
  }

  // ── ✅ 거래방 멱등 생성 (productId 느슨 검증 + 필요한 컬럼만 SELECT) ───────────
  async ensureTradeRoom(args: { productId: string; meUserId: string }): Promise<{ id: string }> {
    const { productId, meUserId } = args;

    // seeding productId의 v1/v4 미준수 대비: 느슨 검증
    if (!productId || !UUID36_LOOSE.test(productId)) {
      throw new BadRequestException('productId invalid');
    }
    // meUserId는 엄격 검증 유지
    assertUuidLike(meUserId, 'meUserId');

    // 1) 상품 조회: 스키마 상 존재하는 컬럼만 사용
    const prows = await this.ds.query(
      `SELECT sellerId, deletedAt FROM products WHERE id = ? LIMIT 1`,
      [productId],
    );
    if (!prows?.length) throw new BadRequestException('PRODUCT_NOT_FOUND');

    const p = prows[0] as { sellerId: string | null; deletedAt: Date | null };
    if (p.deletedAt) throw new BadRequestException('PRODUCT_DELETED');

    const sellerId = String(p.sellerId ?? '');
    assertUuidLike(sellerId, 'sellerId');

    // 2) 멱등 생성
    await this.ds.query(
      `
      INSERT INTO chatRooms (id, \`type\`, productId, buyerId, sellerId, createdAt)
      VALUES (UUID(), 'TRADE', ?, ?, ?, NOW())
      ON DUPLICATE KEY UPDATE id = id
      `,
      [productId, meUserId, sellerId],
    );

    // 3) 방 id 조회
    const out = await this.ds.query(
      `
      SELECT id
      FROM chatRooms
      WHERE \`type\`='TRADE' AND productId=? AND buyerId=? AND sellerId=?
      LIMIT 1
      `,
      [productId, meUserId, sellerId],
    );
    if (!out?.length) throw new Error('TRADE_ROOM_RESOLVE_FAILED');

    return { id: String(out[0].id) };
  }

  // ── 메시지 조회/추가 ─────────────────────────────────────
  async fetchMessagesSinceSeq(args: {
    roomId: string;
    sinceSeq: number; // 0 이하면 최신 N개
    limit: number;
    meUserId: string;
  }): Promise<ChatMessageWire[]> {
    const { roomId, sinceSeq, limit } = args;

    let rows: any[] = [];
    if (sinceSeq <= 0) {
      rows = await this.ds.query(
        `
        SELECT id, roomId, senderId, type, content, fileUrl, createdAt,
               IFNULL(seq, UNIX_TIMESTAMP(createdAt) * 1000) AS seq
        FROM chatMessages
        WHERE roomId = ?
        ORDER BY createdAt DESC, id DESC
        LIMIT ?
        `,
        [roomId, limit],
      );
      rows.reverse(); // 과거→현재
    } else {
      rows = await this.ds.query(
        `
        SELECT id, roomId, senderId, type, content, fileUrl, createdAt,
               IFNULL(seq, UNIX_TIMESTAMP(createdAt) * 1000) AS seq
        FROM chatMessages
        WHERE roomId = ?
          AND IFNULL(seq, UNIX_TIMESTAMP(createdAt) * 1000) > ?
        ORDER BY createdAt ASC, id ASC
        LIMIT ?
        `,
        [roomId, sinceSeq, limit],
      );
    }

    return rows.map((r: any) => {
      const created =
        r.createdAt instanceof Date ? r.createdAt : new Date(r.createdAt);
      return {
        id: String(r.id),
        roomId: String(r.roomId),
        senderId: String(r.senderId),
        text: r.content ?? '',
        timestamp: created.toISOString(),
        seq: Number(r.seq ?? seqFromDate(created)),
        readByMe: undefined,
      };
    });
  }

  async appendText(args: { roomId: string; senderId: string; text: string }): Promise<ChatMessageWire> {
    const { roomId, senderId, text } = args;
    assertUuidLike(roomId, 'roomId');
    assertUuidLike(senderId, 'senderId');

    const id = uuidv1();
    const createdAt = new Date();

    await this.ds.query(
      `
      INSERT INTO chatMessages (id, roomId, senderId, type, content, createdAt)
      VALUES (?, ?, ?, 'TEXT', ?, ?)
      `,
      [id, roomId, senderId, text, createdAt],
    );

    return {
      id,
      roomId,
      senderId,
      text,
      timestamp: createdAt.toISOString(),
      seq: seqFromDate(createdAt),
      readByMe: true,
    };
  }

  // ── 읽음 커서 ───────────────────────────────────────────
  async updateReadCursor(args: { roomId: string; userId: string; lastMessageId: string }): Promise<void> {
    const { roomId, userId, lastMessageId } = args;
    assertUuidLike(roomId, 'roomId');
    assertUuidLike(userId, 'userId');
    assertUuidLike(lastMessageId, 'lastMessageId');

    await this.ds.query(
      `
      INSERT INTO chatReads (roomId, userId, lastReadMessageId, updatedAt)
      VALUES (?, ?, ?, NOW())
      ON DUPLICATE KEY UPDATE
        lastReadMessageId = VALUES(lastReadMessageId),
        updatedAt = NOW()
      `,
      [roomId, userId, lastMessageId],
    );
  }

  async markReadTo(opts: { roomId: string; userId: string; lastMessageId: string | null }) {
    const { roomId, userId } = opts;
    assertUuidLike(roomId, 'roomId');
    assertUuidLike(userId, 'userId');

    let targetId = opts.lastMessageId;

    if (targetId) {
      assertUuidLike(targetId, 'lastMessageId');

      let inRoom = false;
      if (this.msgRepo) {
        inRoom = await this.msgRepo.exist({ where: { id: targetId, roomId } as any });
      } else {
        const chk = await this.ds.query(
          `SELECT id FROM chatMessages WHERE id = ? AND roomId = ? LIMIT 1`,
          [targetId, roomId],
        );
        inRoom = chk.length > 0;
      }
      if (!inRoom) throw new BadRequestException('lastMessageId not in this room');
    } else {
      const latest = await this.getLatestMessageId(roomId);
      if (!latest) return;
      targetId = latest;
    }

    await this.ds.query(
      `
      INSERT INTO chatReads (roomId, userId, lastReadMessageId, updatedAt)
      VALUES (?, ?, ?, NOW())
      ON DUPLICATE KEY UPDATE
        lastReadMessageId = (
          SELECT m2.id
          FROM chatMessages m2
          WHERE m2.roomId = VALUES(roomId)
            AND m2.id IN (chatReads.lastReadMessageId, VALUES(lastReadMessageId))
          ORDER BY IFNULL(m2.seq, UNIX_TIMESTAMP(m2.createdAt) * 1000) DESC
          LIMIT 1
        ),
        updatedAt = NOW()
      `,
      [roomId, userId, targetId],
    );
  }

  async getLatestMessageId(roomId: string): Promise<string | null> {
    if (this.msgRepo) {
      const latest = await this.msgRepo
        .createQueryBuilder('m')
        .select(['m.id'])
        .where('m.roomId = :roomId', { roomId })
        .orderBy('m.seq', 'DESC')
        .getOne();
      return latest?.id ?? null;
    }
    const rows = await this.ds.query(
      `
      SELECT id
      FROM chatMessages
      WHERE roomId = ?
      ORDER BY IFNULL(seq, UNIX_TIMESTAMP(createdAt) * 1000) DESC
      LIMIT 1
      `,
      [roomId],
    );
    return rows?.[0]?.id ?? null;
  }

    // ── DS 기반 내 방 목록 ─────────
  // src/features/chats/chats.service.ts

    // ── DS 기반 내 방 목록 ─────────
  //   - opts 형태({ meUserId, limit })도 받고
  //   - 그냥 meUserId 문자열만 넘겨도 동작하도록 처리
  async listMyRooms(optsOrMeUserId: any) {
    let meUserId: string;
    let limit = 50;

    if (typeof optsOrMeUserId === 'string') {
      // ChatRoomsController처럼 string만 넘긴 경우
      meUserId = optsOrMeUserId;
    } else if (optsOrMeUserId && typeof optsOrMeUserId === 'object') {
      // ChatsController처럼 { meUserId, mine, limit } 넘긴 경우
      meUserId = String(optsOrMeUserId.meUserId);
      if (optsOrMeUserId.limit != null) {
        const n = Number(optsOrMeUserId.limit);
        if (!Number.isNaN(n) && n > 0 && n <= 200) {
          limit = n;
        }
      }
    } else {
      throw new BadRequestException('meUserId required');
    }

    assertUuidLike(meUserId, 'meUserId');

    const rows = await this.ds.query(
    `
    SELECT
      r.id,
      r.id AS roomId,
      r.lastSnippet,
      r.lastMessageAt,
      -- 내가 buyer면 seller 이름/이메일, 내가 seller면 buyer 이름/이메일
      CASE
        WHEN r.buyerId = ? THEN us.name
        WHEN r.sellerId = ? THEN ub.name
        ELSE NULL
      END AS partnerName,
      CASE
        WHEN r.buyerId = ? THEN us.email
        WHEN r.sellerId = ? THEN ub.email
        ELSE NULL
      END AS partnerEmail
    FROM chatRooms r
      LEFT JOIN users ub ON ub.id = r.buyerId
      LEFT JOIN users us ON us.id = r.sellerId
    WHERE r.buyerId = ? OR r.sellerId = ?
    ORDER BY COALESCE(r.lastMessageAt, r.createdAt) DESC
    LIMIT ?
    `,
    // ? 7개 → meUserId 여섯 번 + limit 한 번
    [meUserId, meUserId, meUserId, meUserId, meUserId, meUserId, limit],
  );

    // 아래 helper로 shape 정리
    return rows.map((r: any) => keyifyRoomRow(r));
  }

}

// 내부 헬퍼
function keyifyRoomRow(r: any) {
  return {
    id: String(r.id ?? r.roomId),
    roomId: String(r.roomId ?? r.id),
    lastSnippet: r.lastSnippet ?? '',
    lastMessageAt: r.lastMessageAt ?? null,
    partnerName: r.partnerName ?? '',
    partnerEmail: r.partnerEmail ?? '',
  };
}

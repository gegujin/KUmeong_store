// src/features/chats/chats.service.ts  (MySQL 전용 간소화)
import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { v1 as uuidv1 } from 'uuid';
import { ChatMessage } from '../../features/chats/entities/chat-message.entity'; // 경로 프로젝트에 맞게

// ─────────────────────────────────────────────────────────────
// UUID 검증 유틸
// ─────────────────────────────────────────────────────────────
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function assertUuidLike(val: string | null | undefined, name = 'id') {
  if (!val || typeof val !== 'string' || !UUID_RE.test(val)) {
    throw new BadRequestException(`${name} invalid`);
  }
}

// createdAt(ms) → 의사 seq (백업용)
function seqFromDate(d: Date) {
  return Math.floor(d.getTime());
}

type ChatMessageWire = {
  id: string;
  roomId: string;
  senderId: string;
  text: string;
  timestamp: string; // ISO 8601
  seq: number; // int
  readByMe?: boolean;
};

@Injectable()
export class ChatsService {
  constructor(
    private readonly ds: DataSource,
    @Optional() @InjectRepository(ChatMessage) private readonly msgRepo?: Repository<ChatMessage>,
  ) {}

  // ─────────────────────────────────────────────────────────────
  // 존재/멤버십 확인
  // ─────────────────────────────────────────────────────────────
  async ensureRoomExists(roomId: string): Promise<boolean> {
    const row = await this.ds.query(`SELECT id FROM chatRooms WHERE id = ? LIMIT 1`, [roomId]);
    return row.length > 0;
  }

  async ensureRoomMember(roomId: string, userId: string): Promise<boolean> {
    const rows = await this.ds.query(
      `SELECT id FROM chatRooms WHERE id = ? AND (buyerId = ? OR sellerId = ?) LIMIT 1`,
      [roomId, userId, userId],
    );
    return rows.length > 0;
  }

  // ─────────────────────────────────────────────────────────────
  // 거래(상품) 채팅방 보장 (멱등)
  // ─────────────────────────────────────────────────────────────
  async ensureTradeRoom(meUserId: string, productId: string) {
    assertUuidLike(meUserId, 'meUserId');
    assertUuidLike(productId, 'productId');

    // 1) 상품/판매자 조회
    const [prod] = await this.ds.query(
      `SELECT id, sellerId, title, priceWon
         FROM products
        WHERE id = ? AND deletedAt IS NULL
        LIMIT 1`,
      [productId],
    );
    if (!prod) throw new NotFoundException('PRODUCT_NOT_FOUND');

    const buyerId = meUserId;
    const sellerId = String(prod.sellerId);
    if (buyerId === sellerId) throw new BadRequestException('CANNOT_CHAT_WITH_SELF_PRODUCT');

    // 2) 차단 관계 검사 (상호)
    const [blockedAB] = await this.ds.query(
      `SELECT 1 FROM userBlocks WHERE blockerId=? AND blockedId=? LIMIT 1`,
      [sellerId, buyerId],
    );
    if (blockedAB) throw new ForbiddenException('BLOCKED');

    const [blockedBA] = await this.ds.query(
      `SELECT 1 FROM userBlocks WHERE blockerId=? AND blockedId=? LIMIT 1`,
      [buyerId, sellerId],
    );
    if (blockedBA) throw new ForbiddenException('BLOCKED');

    // 3) 멱등 upsert (유니크: (type, pairMinId, pairMaxId, productIdNorm))
    //    TRADE라도 buyer/seller를 정렬해 넣고, 조회도 정렬 기준으로 한다.
    const pairMin = buyerId < sellerId ? buyerId : sellerId;
    const pairMax = buyerId < sellerId ? sellerId : buyerId;

    await this.ds.query(
      `INSERT INTO chatRooms (id, \`type\`, productId, buyerId, sellerId)
       VALUES (UUID(), 'TRADE', ?, ?, ?)
       ON DUPLICATE KEY UPDATE id = id`,
      [productId, pairMin, pairMax],
    );

    // 4) room 조회 (+ last*)
    const [room] = await this.ds.query(
      `SELECT id, \`type\`, productId, buyerId, sellerId,
              lastMessageId, lastMessageAt, lastSenderId, lastSnippet, createdAt
         FROM chatRooms
        WHERE \`type\`='TRADE' AND productId=? AND buyerId=? AND sellerId=?
        LIMIT 1`,
      [productId, pairMin, pairMax],
    );
    if (!room) throw new Error('ROOM_RESOLVE_FAILED');

    // 프런트 헤더용 상품 미니 정보 포함
    (room as any).product = {
      id: String(prod.id),
      title: String(prod.title),
      priceWon: Number(prod.priceWon),
    };

    return room as {
      id: string;
      type: 'TRADE';
      productId: string;
      buyerId: string;
      sellerId: string;
      lastMessageId: string | null;
      lastMessageAt: string | null;
      lastSenderId: string | null;
      lastSnippet: string | null;
      createdAt: string;
      product: { id: string; title: string; priceWon: number };
    };
  }

  // ─────────────────────────────────────────────────────────────
  // 친구 DM 방 보장 (MySQL 전용)
  // ─────────────────────────────────────────────────────────────
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

    // 페어 정규화 (항상 a<b) → a=buyerId, b=sellerId
    const [a, b] = [meUserId, peerUserId].sort();

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

  // ─────────────────────────────────────────────────────────────
  // 메시지 조회/추가 (MySQL 전용)
  // ─────────────────────────────────────────────────────────────
  async fetchMessagesSinceSeq(args: {
    roomId: string;
    sinceSeq: number; // 0 이하면 최신 N개
    limit: number;
    meUserId: string;
  }): Promise<ChatMessageWire[]> {
    const { roomId, sinceSeq, limit } = args;
    assertUuidLike(roomId, 'roomId');

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
      rows.reverse(); // 화면에서는 과거→현재 순
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
      const created = r.createdAt instanceof Date ? r.createdAt : new Date(r.createdAt);
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

      const id = uuidv1(); // ✅ v1 UUID 사용 (스키마와 일치)
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
    async sendMessage(
    roomId: string,
    senderId: string,
    dto: { text: string; clientMessageId?: string },
  ): Promise<ChatMessageWire> {
    assertUuidLike(roomId, 'roomId');
    assertUuidLike(senderId, 'senderId');
    const text = (dto.text ?? '').toString();
    if (!text) throw new BadRequestException('text required');

    // 0) 스키마에 clientMessageId 컬럼이 있는지 캐시 없이 가볍게 점검
    //    - 컬럼이 없으면 기존 append 로 fallback
    let hasClientIdColumn = true;
    try {
      await this.ds.query(
        `SELECT clientMessageId FROM chatMessages WHERE roomId = ? LIMIT 1`,
        [roomId],
      );
    } catch {
      hasClientIdColumn = false;
    }

    // 1) clientMessageId가 없거나, 컬럼이 없다면 그냥 append
    if (!dto.clientMessageId || !hasClientIdColumn) {
      return this.appendText({ roomId, senderId, text });
    }

    const clientId = String(dto.clientMessageId);

    // 2) 선행 조회(이미 들어간 중복이 있으면 그대로 반환 → 멱등)
    const pre = await this.ds.query(
      `
      SELECT id, roomId, senderId, content, createdAt,
            IFNULL(seq, UNIX_TIMESTAMP(createdAt) * 1000) AS seq
      FROM chatMessages
      WHERE roomId = ? AND clientMessageId = ?
      LIMIT 1
      `,
      [roomId, clientId],
    );
    if (pre?.length) {
      const r = pre[0];
      const created = r.createdAt instanceof Date ? r.createdAt : new Date(r.createdAt);
      return {
        id: String(r.id),
        roomId: String(r.roomId),
        senderId: String(r.senderId),
        text: r.content ?? '',
        timestamp: created.toISOString(),
        seq: Number(r.seq ?? seqFromDate(created)),
        readByMe: true,
      };
    }

    // 3) 삽입 시도 (UNIQUE (roomId, clientMessageId) 가 있다면 동시경합도 안전)
    const id = uuidv1();
    const createdAt = new Date();
    try {
      await this.ds.query(
        `
        INSERT INTO chatMessages (id, roomId, senderId, type, content, clientMessageId, createdAt)
        VALUES (?, ?, ?, 'TEXT', ?, ?, ?)
        `,
        [id, roomId, senderId, text, clientId, createdAt],
      );
    } catch (e: any) {
      // 동시삽입으로 인한 중복키 → 기존 레코드 재조회 후 반환(멱등)
      if (e?.code === 'ER_DUP_ENTRY' || e?.errno === 1062) {
        const again = await this.ds.query(
          `
          SELECT id, roomId, senderId, content, createdAt,
                IFNULL(seq, UNIX_TIMESTAMP(createdAt) * 1000) AS seq
          FROM chatMessages
          WHERE roomId = ? AND clientMessageId = ?
          LIMIT 1
          `,
          [roomId, clientId],
        );
        if (again?.length) {
          const r = again[0];
          const created = r.createdAt instanceof Date ? r.createdAt : new Date(r.createdAt);
          return {
            id: String(r.id),
            roomId: String(r.roomId),
            senderId: String(r.senderId),
            text: r.content ?? '',
            timestamp: created.toISOString(),
            seq: Number(r.seq ?? seqFromDate(created)),
            readByMe: true,
          };
        }
      }
      throw e;
    }

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

  // ─────────────────────────────────────────────────────────────
  // 읽음 커서 업데이트 (MySQL 전용 upsert)
  // ─────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────
  // 읽음 커서 업데이트(“앞으로만” 전진) + 최신 자동결정 (MySQL 전용)
  // ─────────────────────────────────────────────────────────────
  async markReadTo(opts: { roomId: string; userId: string; lastMessageId: string | null }) {
    const { roomId, userId } = opts;
    assertUuidLike(roomId, 'roomId');
    assertUuidLike(userId, 'userId');

    // 타겟 메시지 결정
    let targetId = opts.lastMessageId;

    if (targetId) {
      assertUuidLike(targetId, 'lastMessageId');

      // msgRepo 있으면 exist, 없으면 쿼리 확인
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
      // 최신 메시지로
      const latest = await this.getLatestMessageId(roomId);
      if (!latest) return; // 메시지 없으면 스킵
      targetId = latest;
    }

    // seq가 더 큰 id만 선택되도록 전진 보장 UPSERT
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

  // 최신 메시지 id (MySQL 전용 + msgRepo 지원)
  async getLatestMessageId(roomId: string): Promise<string | null> {
    assertUuidLike(roomId, 'roomId');

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
}

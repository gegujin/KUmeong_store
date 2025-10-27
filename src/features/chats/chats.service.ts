// src/features/chats/chats.service.ts  (MySQL 전용 간소화)
import { BadRequestException, Injectable, Optional } from '@nestjs/common';
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
  seq: number;       // int
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

    // chatRooms UNIQUE(type, productId, buyerId, sellerId) 필요
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

// src/features/chats/chats.service.ts
import { BadRequestException, Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { v1 as uuidv1 } from 'uuid';

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

// ─────────────────────────────────────────────────────────────
// DB 방언 감지
// ─────────────────────────────────────────────────────────────
function dbType(ds: DataSource): string | undefined {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return (ds.options as any)?.type;
}
function isMySQL(ds: DataSource) {
  const t = dbType(ds);
  return t === 'mysql' || t === 'mariadb';
}
function isSQLite(ds: DataSource) {
  const t = dbType(ds);
  return t === 'sqlite' || t === 'better-sqlite3';
}

/** createdAt(ms) → 의사 seq */
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
  constructor(private readonly ds: DataSource) {}

  /**
   * 채팅방 존재 체크
   * - 컨트롤러에서 404를 줄지 판단하기 위해 사용
   */
  async ensureRoomExists(roomId: string): Promise<boolean> {
    const row = await this.ds.query(
      `SELECT id FROM chatRooms WHERE id = ? LIMIT 1`,
      [roomId],
    );
    return row.length > 0;
  }

  // ✅ 친구 DM 방 보장/조회 — 드라이버/검증/충돌처리 강화
  async ensureFriendRoom(args: {
    meUserId: string;
    peerUserId: string;
  }): Promise<string> {
    let { meUserId, peerUserId } = args;

    // ── 입력값/형식 검증(400) ─────────────────────────────
    if (!meUserId || !peerUserId) {
      throw new BadRequestException('MISSING_USER_ID');
    }
    if (meUserId === peerUserId) {
      throw new BadRequestException('SELF_DM_NOT_ALLOWED');
    }
    if (!UUID_RE.test(meUserId)) {
      throw new BadRequestException('ME_USER_ID_INVALID');
    }
    if (!UUID_RE.test(peerUserId)) {
      throw new BadRequestException('PEER_USER_ID_INVALID');
    }

    // 1) 실제 users 테이블 존재 검증 (FK 에러를 사전에 4xx로 변환)
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

    // 2) 페어 정규화 (항상 a<b) → a=buyerId, b=sellerId
    const [a, b] = [meUserId, peerUserId].sort();

    // 3) 드라이버별 upsert
    if (isMySQL(this.ds)) {
      // ⚠️ chatRooms에 UNIQUE(type, productId, buyerId, sellerId) 인덱스 필요
      await this.ds.query(
        `
        INSERT INTO chatRooms (id, \`type\`, productId, buyerId, sellerId, createdAt)
        VALUES (UUID(), 'FRIEND', NULL, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE id = id
        `,
        [a, b],
      );
    } else {
      // SQLite/기타: uuid 사전생성 후 충돌은 무시
      const newId = uuidv1();
      try {
        await this.ds.query(
          `
          INSERT INTO chatRooms (id, \`type\`, productId, buyerId, sellerId, createdAt)
          VALUES (?, 'FRIEND', NULL, ?, ?, CURRENT_TIMESTAMP)
          `,
          [newId, a, b],
        );
      } catch {
        // 유니크 충돌 → 이미 존재
      }
    }

    // 4) id 조회
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

    if (!rows?.length) {
      throw new Error('ROOM_RESOLVE_FAILED');
    }
    return rows[0].id as string;
  }

  /**
   * 메시지 목록(최근 limit or sinceSeq 이후)
   * - ChatApi.fetchMessagesSinceSeq 와 1:1 매핑
   */
  async fetchMessagesSinceSeq(args: {
    roomId: string;
    sinceSeq: number;
    limit: number;
    meUserId: string; // 현재는 사용 X(향후 readByMe 계산 등에 사용할 수 있음)
  }): Promise<ChatMessageWire[]> {
    const { roomId, sinceSeq, limit } = args;

    // sinceSeq <= 0 : 최근 limit개 (최신→과거로 뽑고 reverse)
    if (sinceSeq <= 0) {
      const rows = await this.ds.query(
        `
        SELECT id, roomId, senderId, type, content, fileUrl, createdAt
        FROM chatMessages
        WHERE roomId = ?
        ORDER BY createdAt DESC, id DESC
        LIMIT ?
        `,
        [roomId, limit],
      );
      rows.reverse(); // 과거 → 현재 순으로 반환
      return rows.map((r: any) => {
        const created =
          r.createdAt instanceof Date ? r.createdAt : new Date(r.createdAt);
        return {
          id: r.id,
          roomId: r.roomId,
          senderId: r.senderId,
          text: r.content ?? '',
          timestamp: created.toISOString(),
          seq: seqFromDate(created),
          readByMe: undefined,
        };
      });
    }

    // sinceSeq > 0 : 방언별 분기
    let rows: any[] = [];
    if (isMySQL(this.ds)) {
      // MySQL/MariaDB
      rows = await this.ds.query(
        `
        SELECT id, roomId, senderId, type, content, fileUrl, createdAt
        FROM chatMessages
        WHERE roomId = ?
          AND UNIX_TIMESTAMP(createdAt) * 1000 > ?
        ORDER BY createdAt ASC, id ASC
        LIMIT ?
        `,
        [roomId, sinceSeq, limit],
      );
    } else if (isSQLite(this.ds)) {
      // SQLite
      rows = await this.ds.query(
        `
        SELECT id, roomId, senderId, type, content, fileUrl, createdAt
        FROM chatMessages
        WHERE roomId = ?
          AND (CAST(strftime('%s', createdAt) AS INTEGER) * 1000) > ?
        ORDER BY createdAt ASC, id ASC
        LIMIT ?
        `,
        [roomId, sinceSeq, limit],
      );
    } else {
      // 기타 드라이버: 전체에서 메모리 필터(예비)
      rows = await this.ds.query(
        `
        SELECT id, roomId, senderId, type, content, fileUrl, createdAt
        FROM chatMessages
        WHERE roomId = ?
        ORDER BY createdAt ASC, id ASC
        LIMIT ?
        `,
        [roomId, limit],
      );
      rows = rows.filter((r: any) => {
        const created =
          r.createdAt instanceof Date ? r.createdAt : new Date(r.createdAt);
        return created.getTime() > sinceSeq;
      });
    }

    return rows.map((r: any) => {
      const created =
        r.createdAt instanceof Date ? r.createdAt : new Date(r.createdAt);
      return {
        id: r.id,
        roomId: r.roomId,
        senderId: r.senderId,
        text: r.content ?? '',
        timestamp: created.toISOString(),
        seq: seqFromDate(created),
        readByMe: undefined,
      };
    });
  }

  /**
   * 텍스트 메시지 저장
   * - ChatApi.sendMessage 와 1:1 매핑
   */
  async appendText(args: {
    roomId: string;
    senderId: string;
    text: string;
  }): Promise<ChatMessageWire> {
    const { roomId, senderId, text } = args;
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
      readByMe: true, // 보낸 본인 기준
    };
  }

  /**
   * 읽음 커서 업데이트
   * - ChatApi.markRead 와 1:1 매핑
   * - MySQL: ON DUPLICATE KEY
   * - SQLite: ON CONFLICT(roomId, userId)
   *   (⚠️ 반드시 chatReads(roomId,userId) UNIQUE 인덱스 필요)
   */
  async updateReadCursor(args: {
    roomId: string;
    userId: string;
    lastMessageId: string;
  }): Promise<void> {
    const { roomId, userId, lastMessageId } = args;

    if (isMySQL(this.ds)) {
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
      return;
    }

    if (isSQLite(this.ds)) {
      await this.ds.query(
        `
        INSERT INTO chatReads (roomId, userId, lastReadMessageId, updatedAt)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(roomId, userId) DO UPDATE SET
          lastReadMessageId = excluded.lastReadMessageId,
          updatedAt = CURRENT_TIMESTAMP
        `,
        [roomId, userId, lastMessageId],
      );
      return;
    }

    // 기타 드라이버: 멱등 upsert 대체(트랜잭션 권장)
    const existing = await this.ds.query(
      `SELECT roomId FROM chatReads WHERE roomId = ? AND userId = ? LIMIT 1`,
      [roomId, userId],
    );
    if (existing.length === 0) {
      await this.ds.query(
        `INSERT INTO chatReads (roomId, userId, lastReadMessageId, updatedAt)
         VALUES (?, ?, ?, CURRENT_TIMESTAMP)`,
        [roomId, userId, lastMessageId],
      );
    } else {
      await this.ds.query(
        `UPDATE chatReads
         SET lastReadMessageId = ?, updatedAt = CURRENT_TIMESTAMP
         WHERE roomId = ? AND userId = ?`,
        [lastMessageId, roomId, userId],
      );
    }
  }
}

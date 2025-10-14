// C:\Users\82105\KU-meong Store\kumeong-api\src\features\chats\chats.service.ts
import { Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { v4 as uuidv4 } from 'uuid';

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

/**
 * createdAt(ms)를 의사 seq로 사용
 * - DB에 seq 칼럼이 없어도 프론트의 sinceSeq 로직이 동작하도록 보장
 */
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

  /**
   * 채팅방 존재 보장 (없으면 생성, 있으면 no-op)
   * - MySQL/MariaDB: ON DUPLICATE KEY
   * - SQLite: ON CONFLICT(id) DO NOTHING
   * - 기타 드라이버: try-insert 후 에러 무시
   */
  async ensureRoomExistsOrCreate(roomId: string): Promise<void> {
    if (!roomId) return;

    if (isMySQL(this.ds)) {
      await this.ds.query(
        `
        INSERT INTO chatRooms (id, createdAt)
        VALUES (?, NOW())
        ON DUPLICATE KEY UPDATE id = id
        `,
        [roomId],
      );
      return;
    }

    if (isSQLite(this.ds)) {
      await this.ds.query(
        `
        INSERT INTO chatRooms (id, createdAt)
        VALUES (?, CURRENT_TIMESTAMP)
        ON CONFLICT(id) DO NOTHING
        `,
        [roomId],
      );
      return;
    }

    // 기타 드라이버: 멱등 시도
    try {
      await this.ds.query(
        `INSERT INTO chatRooms (id, createdAt) VALUES (?, CURRENT_TIMESTAMP)`,
        [roomId],
      );
    } catch {
      // 이미 있으면 무시
    }
  }

  /**
   * 메시지 목록(최근 limit or sinceSeq 이후)
   * - ChatApi.fetchMessagesSinceSeq 와 1:1 매핑
   * - 반환 스키마는 chat_api.dart 의 ChatMessage.fromJson 에 맞춤
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
        const created = r.createdAt instanceof Date ? r.createdAt : new Date(r.createdAt);
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
      // SQLite: createdAt이 DATETIME이면 strftime 사용 가능
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
      // 기타 드라이버: 일단 전체를 뽑아서 메모리 비교 (권장X, 예비용)
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
        const created = r.createdAt instanceof Date ? r.createdAt : new Date(r.createdAt);
        return created.getTime() > sinceSeq;
      });
    }

    return rows.map((r: any) => {
      const created = r.createdAt instanceof Date ? r.createdAt : new Date(r.createdAt);
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
   * - 저장 직후 프론트에 돌려주는 스키마도 chat_api.dart 기대치에 맞춤
   */
  async appendText(args: {
    roomId: string;
    senderId: string;
    text: string;
  }): Promise<ChatMessageWire> {
    const { roomId, senderId, text } = args;
    const id = uuidv4();
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
   *   (⚠️ 반드시 chatReads(roomId,userId) UNIQUE 인덱스가 있어야 합니다)
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

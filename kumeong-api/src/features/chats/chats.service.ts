// C:\Users\82105\KU-meong Store\kumeong-api\src\features\chats\chats.service.ts
import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { randomUUID } from 'crypto';

import { Conversation } from './entities/conversation.entity';
import { ConversationMessage } from './entities/conversation-message.entity';
import { normalizeId, isUuid } from '../../common/utils/ids';

type UUID = string;

interface ChatMessageDto {
  id: string;
  senderId: string;
  content: string;
  createdAt: string; // ISO
  readByPeer?: boolean;
  readByMe?: boolean;
}

/** 컨트롤러 방어와 별도로 서비스에서도 한 번 더 검증 */
function assertUuidLike(v: string, field: string) {
  if (!v || !isUuid(v)) {
    throw new BadRequestException(`${field} must be a UUID (8-4-4-4-12)`);
  }
}

/** 두 UUID를 사전식 정렬(A<=B) */
function normalizePair(a: UUID, b: UUID): [UUID, UUID] {
  return a <= b ? ([a, b] as [UUID, UUID]) : ([b, a] as [UUID, UUID]);
}

/* ─────────────────────────────────────────────────────────────
 * (A,B) → conversationId 메모리 캐시 (LRU-lite)
 * 서버 재시작 시 리셋되어도 무방한 수준의 단기 캐시
 * ────────────────────────────────────────────────────────────*/
const CONV_CACHE_TTL_MS = 60_000; // 1분
type CacheEntry = { id: string; at: number };
const convCache = new Map<string, CacheEntry>();

function cacheKey(a: string, b: string) {
  return `${a}|${b}`;
}
function cacheGet(a: string, b: string): string | null {
  const k = cacheKey(a, b);
  const hit = convCache.get(k);
  if (!hit) return null;
  if (Date.now() - hit.at > CONV_CACHE_TTL_MS) {
    convCache.delete(k);
    return null;
  }
  return hit.id;
}
function cacheSet(a: string, b: string, id: string) {
  convCache.set(cacheKey(a, b), { id, at: Date.now() });
}
function cacheDel(a: string, b: string) {
  convCache.delete(cacheKey(a, b));
}

/* ─────────────────────────────────────────────────────────────
 * 읽음 처리 호출 최소화용 캐시
 * `${me}|${peer}` -> lastMessageId
 * ────────────────────────────────────────────────────────────*/
const markReadCache = new Map<string, string>();
function pairKey(a: string, b: string) {
  const [A, B] = normalizePair(a, b);
  return `${A}|${B}`;
}

@Injectable()
export class ChatsService {
  private readonly logger = new Logger(ChatsService.name);

  // 간단한 카운터(임시 메트릭)
  private listCalls = 0;
  private findConvCalls = 0;
  private markReadCalls = 0;

  constructor(
    @InjectRepository(Conversation)
    private readonly convRepo: Repository<Conversation>,
    @InjectRepository(ConversationMessage)
    private readonly msgRepo: Repository<ConversationMessage>,
    private readonly ds: DataSource,
  ) {}

  getDebugMetrics() {
    return {
      listCalls: this.listCalls,
      findConvCalls: this.findConvCalls,
      markReadCalls: this.markReadCalls,
      ts: new Date().toISOString(),
    };
  }

  /**
   * me/peer를 정규화하여 대화방을 찾거나 생성
   * - 스키마: (participantA, participantB) UNIQUE
   * - 경쟁상황: INSERT ... ON DUPLICATE KEY 로 단일 방 보장
   * - 캐시: 같은 (A,B)에 대한 반복 SELECT 최소화
   */
  private async findOrCreateConversation(meRaw: UUID, peerRaw: UUID): Promise<Conversation> {
    this.findConvCalls++;

    const me = normalizeId(meRaw);
    const peer = normalizeId(peerRaw);
    if (!me || !peer) throw new BadRequestException('me/peer must be a UUID');
    if (me === peer) throw new BadRequestException('me and peer cannot be the same (UUID)');
    assertUuidLike(me, 'me');
    assertUuidLike(peer, 'peer');

    const [A, B] = normalizePair(me, peer);

    // 0) 캐시 히트
    const cachedId = cacheGet(A, B);
    if (cachedId) {
      const fast = await this.convRepo.findOne({ where: { id: cachedId } });
      if (fast) {
        this.logger.debug(`convCache HIT ${A}|${B} -> ${cachedId}`);
        return fast;
      }
      this.logger.debug(`convCache STALE ${A}|${B} -> ${cachedId}`);
    }

    // 1) 빠른 조회
    const existing = await this.convRepo.findOne({ where: { participantA: A, participantB: B } });
    if (existing) {
      cacheSet(A, B, existing.id);
      this.logger.debug(`convCache MISS ${A}|${B} -> ${existing.id}`);
      return existing;
    }

    
    // 2) 경쟁상황 대비 upsert (엔티티 매핑 사용: participantA/B → participant_a/b)
    const newId = randomUUID();
    await this.convRepo.upsert(
      { id: newId, participantA: A, participantB: B },
      { conflictPaths: ['participantA', 'participantB'] }, // UNIQUE (participant_a, participant_b)
    );


    // 3) 확정 조회
    const conv = await this.convRepo.findOne({ where: { participantA: A, participantB: B } });
    if (!conv) throw new BadRequestException('failed to create or fetch conversation');

    cacheSet(A, B, conv.id);
    this.logger.debug(`convCache CREATE ${A}|${B} -> ${conv.id}`);
    return conv;
  }


  /** 메시지 전송 */
  async sendMessage(meRaw: UUID, peerRaw: UUID, text: string): Promise<ChatMessageDto> {
    const content = String(text ?? '').trim();
    if (!content) throw new BadRequestException('text is required');

    const conv = await this.findOrCreateConversation(meRaw, peerRaw);

    const saved = await this.msgRepo.save(
      this.msgRepo.create({
        id: randomUUID(),
        conversationId: conv.id,
        senderId: normalizeId(meRaw), // 저장 시에도 정규화 보장
        content,
      }),
    );

    return {
      id: saved.id,
      senderId: saved.senderId,
      content: saved.content ?? '',
      createdAt: saved.createdAt.toISOString(),
      readByPeer: undefined,
      readByMe: undefined,
    };
  }

  /**
   * 메시지 목록
   * - createdAt ASC, id ASC 안정 정렬 (인덱스: conversationId, createdAt, id)
   * - afterId가 있으면 해당 메시지 “이후”만 (동일 시각이면 id가 더 큰 것만)
   */
  async listMessages(meRaw: UUID, peerRaw: UUID, afterId?: UUID, limit = 50): Promise<ChatMessageDto[]> {
    this.listCalls++;

    const conv = await this.findOrCreateConversation(meRaw, peerRaw);

    const n = Number(limit);
    const take = Number.isFinite(n) ? Math.min(Math.max(n, 1), 100) : 50; // 상한 100

    const qb = this.msgRepo
      .createQueryBuilder('m')
      .where('m.conversationId = :cid', { cid: conv.id })
      .orderBy('m.createdAt', 'ASC')
      .addOrderBy('m.id', 'ASC')
      .take(take);

    // afterId가 UUID면 anchor 기준으로 이후만 (인덱스 정렬과 정확히 일치)
    if (afterId && isUuid(afterId)) {
      const anchor = await this.msgRepo.findOne({
        where: { id: afterId, conversationId: conv.id },
        select: ['id', 'createdAt'],
      });
      if (anchor) {
        qb.andWhere(
          '(m.createdAt > :t OR (m.createdAt = :t AND m.id > :afterId))',
          { t: anchor.createdAt, afterId },
        );
      }
    }

    const rows = await qb.getMany();
    return rows.map<ChatMessageDto>((m) => ({
      id: m.id,
      senderId: m.senderId,
      content: m.content ?? '',
      createdAt: m.createdAt.toISOString(),
      readByPeer: undefined,
      readByMe: undefined,
    }));
  }

  /**
   * 읽음 처리 (중복 호출 최소화용 캐시 내장)
   * - 같은 pair(me,peer)에 대해 같은 lastMessageId로 반복 요청이 오면 SKIP
   * - 추후 conversation_reads 테이블 도입 시, 여기서 upsert로 확장
   */
  async markRead(meRaw: UUID, peerRaw: UUID, lastMessageId: UUID) {
    this.markReadCalls++;

    const me = normalizeId(meRaw);
    const peer = normalizeId(peerRaw);
    assertUuidLike(me, 'me');
    assertUuidLike(peer, 'peer');
    if (!lastMessageId || !isUuid(lastMessageId)) {
      // 형식 불량은 조용히 무시 (프런트 유연성). 단, 서버는 UUID만 저장한다.
      this.logger.debug(`markRead IGNORE invalid lastMessageId for ${pairKey(me, peer)}`);
      return { ok: true, skipped: true };
    }

    // 방 보장 (정상 사용자 쌍인지 확인)
    await this.findOrCreateConversation(me, peer);

    const key = pairKey(me, peer);
    if (markReadCache.get(key) === lastMessageId) {
      this.logger.debug(`markRead SKIP ${key} upTo=${lastMessageId}`);
      return { ok: true, skipped: true };
    }
    markReadCache.set(key, lastMessageId);

    // 현재는 no-op (DB 테이블 없이도 중복 억제/로그로 충분)
    this.logger.debug(`markRead WRITE ${key} upTo=${lastMessageId}`);
    return { ok: true };
  }

  /* ─────────────────────────────────────────────────────────────
   * 채팅방 나가기: (me, peer) 간 대화 내용을 모두 삭제하고 방 제거
   * - 프런트 요구사항: 이후 재입장 시 완전 신규 방처럼 보이게
   * - 구현: 메시지 → 방 순서로 삭제
   * - 주의: 서비스 정책에 따라 soft-delete로 바꿀 수 있음
   * ────────────────────────────────────────────────────────────*/
  async leaveConversation(meRaw: UUID, peerRaw: UUID) {
    const me = normalizeId(meRaw);
    const peer = normalizeId(peerRaw);
    if (!me || !peer) throw new BadRequestException('me/peer must be a UUID');
    if (me === peer) throw new BadRequestException('me and peer cannot be the same');
    assertUuidLike(me, 'me');
    assertUuidLike(peer, 'peer');
    const [A, B] = normalizePair(me, peer);

    const conv = await this.convRepo.findOne({
      where: { participantA: A, participantB: B },
      select: ['id', 'participantA', 'participantB'],
    });

    if (!conv) {
      // 방이 없으면 성공으로 처리 (멱등)
      return { ok: true, deleted: 0 };
    }

    await this.ds.transaction(async (trx) => {
      // 메시지 삭제
      await trx
        .createQueryBuilder()
        .delete()
        .from(ConversationMessage)
        .where('conversationId = :cid', { cid: conv.id })
        .execute();

      // 방 삭제
      await trx
        .createQueryBuilder()
        .delete()
        .from(Conversation)
        .where('id = :cid', { cid: conv.id })
        .execute();
    });

    // 캐시 제거
    cacheDel(A, B);
    return { ok: true, deleted: 1 };
  }

  /* 선택) 신고/차단: 컨트롤러 연결만 하면 되도록 기본 형태 제공 */
  async reportPeer(meRaw: UUID, peerRaw: UUID, reason?: string) {
    const me = normalizeId(meRaw);
    const peer = normalizeId(peerRaw);
    assertUuidLike(me, 'me');
    assertUuidLike(peer, 'peer');
    // TODO: reports 테이블에 저장하거나, 모더레이션 큐로 전송
    return { ok: true };
  }

  async blockPeer(meRaw: UUID, peerRaw: UUID) {
    const me = normalizeId(meRaw);
    const peer = normalizeId(peerRaw);
    assertUuidLike(me, 'me');
    assertUuidLike(peer, 'peer');
    // TODO: blocks 테이블에 upsert (me, peer)
    return { ok: true };
  }
}

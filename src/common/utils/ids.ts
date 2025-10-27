// ✅ 교체/보강 코드: C:\Users\82105\KU-meong Store\kumeong-api\src\common\utils\ids.ts
import { v1 as uuidv1, validate as uuidValidate } from 'uuid';

/** 새 ID는 무조건 UUIDv1 */
export const makeId = () => uuidv1().toLowerCase();

/** UUID 형식 검증(버전 무관) */
export function isUuid(v: unknown): v is string {
  return typeof v === 'string' && uuidValidate(v);
}

/**
 * 숫자형 ID ↔ UUID(CHAR(36)) 변환 유틸
 * - "1" → "00000000-0000-0000-0000-000000000001"
 * - 이미 UUID면 그대로
 * - 그 외는 ''(빈 문자열)
 */
function extractDigits(s: string): string {
  let out = '';
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if (c >= 48 && c <= 57) out += s[i];
  }
  return out;
}
function leftPadZeros(s: string, totalLen: number): string {
  const need = totalLen - s.length;
  if (need <= 0) return s;
  let zeros = '';
  for (let i = 0; i < need; i++) zeros += '0';
  return zeros + s;
}

/** ID를 표준 UUID(CHAR(36))로 정규화 */
export function normalizeId(raw: unknown): string {
  const s = raw == null ? '' : String(raw).trim();
  if (!s) return '';
  if (isUuid(s)) return s.toLowerCase();

  const digits = extractDigits(s);
  if (!digits) return '';

  const start = Math.max(0, digits.length - 12);
  const last12 = digits.substring(start);
  const padded = leftPadZeros(last12, 12);

  return `00000000-0000-0000-0000-${padded}`;
}

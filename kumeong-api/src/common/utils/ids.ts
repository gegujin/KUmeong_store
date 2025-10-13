// C:\Users\82105\KU-meong Store\kumeong-api\src\common\utils\ids.ts

/**
 * 숫자형 ID ↔ UUID(CHAR(36)) 변환 유틸
 * - "1"        → "00000000-0000-0000-0000-000000000001"
 * - "42"       → "00000000-0000-0000-0000-000000000042"
 * - "673456"   → "00000000-0000-0000-0000-000000673456"
 * - "123456789012345" → "00000000-0000-0000-0000-234567890123" (오른쪽 12자리)
 * - 이미 UUID면 그대로
 * - 그 외는 ''(빈 문자열)
 */

// 간단한 UUID 형식 체크(정규식은 test만 사용: replace 미사용)
const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUuid(v: unknown): v is string {
  return typeof v === 'string' && UUID_REGEX.test(v);
}

/** 문자열에서 숫자만 뽑아내기 (replace 없이) */
function extractDigits(s: string): string {
  let out = '';
  for (let i = 0; i < s.length; i++) {
    const code = s.charCodeAt(i);
    // '0'(48) ~ '9'(57)
    if (code >= 48 && code <= 57) out += s[i];
  }
  return out;
}

/** 왼쪽 0 패딩 (padStart 없이) */
function leftPadZeros(s: string, totalLen: number): string {
  const need = totalLen - s.length;
  if (need <= 0) return s;
  let zeros = '';
  for (let i = 0; i < need; i++) zeros += '0';
  return zeros + s;
}

/** ID를 표준 UUID(CHAR(36))로 정규화 (replace 미사용 버전) */
export function normalizeId(raw: unknown): string {
  const s = raw == null ? '' : String(raw).trim();
  if (!s) return '';

  // 이미 UUID면 그대로
  if (isUuid(s)) return s;

  // 숫자만 추출
  const digits = extractDigits(s);
  if (!digits) return '';

  // 오른쪽 12자리 사용 (slice 대신 substring 사용)
  const start = Math.max(0, digits.length - 12);
  const last12 = digits.substring(start);

  // 12자리로 왼쪽 0 패딩
  const padded = leftPadZeros(last12, 12);

  return `00000000-0000-0000-0000-${padded}`;
}

/**
 * 공용 TypeORM Transformer 모음
 * - BIGINT 컬럼을 number로 변환
 * - NULL 안전 처리 포함
 */

export const numberTransformer = {
  /**
   * DB에 넣을 때 호출됨 (number → 그대로)
   */
  to: (value: number | null | undefined): number | null => {
    if (value === undefined || value === null) return null;
    return value;
  },

  /**
   * DB에서 꺼낼 때 호출됨 (string | bigint → number)
   */
  from: (value: string | number | bigint | null): number | null => {
    if (value === undefined || value === null) return null;
    return Number(value);
  },
};

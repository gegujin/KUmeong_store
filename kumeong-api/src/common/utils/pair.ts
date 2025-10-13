// src/common/utils/pair.ts
export function pair(a: number, b: number) {
  return a <= b ? [a, b] as const : [b, a] as const;
}

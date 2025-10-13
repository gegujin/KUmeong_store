// C:\Users\82105\KU-meong Store\kumeong-api\src\features\friends\types\errors.ts
export const ERR = {
  SELF_NOT_ALLOWED: 'SELF_NOT_ALLOWED',
  BLOCKED: 'BLOCKED',
  ALREADY_FRIEND: 'ALREADY_FRIEND',
  ALREADY_REQUESTED: 'ALREADY_REQUESTED',
  NOT_PENDING: 'NOT_PENDING',
  NOT_TARGET: 'NOT_TARGET',
  NOT_OWNER: 'NOT_OWNER',
  NOT_FRIEND: 'NOT_FRIEND',
} as const;

export type ErrorCode = keyof typeof ERR;

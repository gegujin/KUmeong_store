import type { UserRole } from '../../users/entities/user.entity';

export type SafeUser = {
  id: number;          // ← number로 변경
  email: string;
  role: UserRole;
  name?: string;
  universityName?: string | null;
  universityVerified?: boolean;
};

// 호환용
export type JwtUser = SafeUser;

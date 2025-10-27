// src/modules/auth/auth.types.ts
import { UserRole } from '../../../features/users/entities/user.entity'; // 경로는 프로젝트 구조에 맞게 조정

// JWT에 넣어 서명/복호화할 페이로드 타입
export interface JwtPayload {
  sub: string;     // ✅ 항상 사용자 UUID
  email: string;
  role: UserRole;
}

// 가드 통과 후 req.user에 올라올 사용자 뷰 타입
export interface AuthUser {
  id: string;      // ✅ payload.sub → id 로 매핑
  email: string;
  role: UserRole;
}

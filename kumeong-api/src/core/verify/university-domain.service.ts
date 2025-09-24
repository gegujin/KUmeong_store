// src/core/verify/university-domain.service.ts
import { Injectable } from '@nestjs/common';
import { isAcademic } from 'swot-node'; // true if *.edu / *.ac.kr 등 학술 기관

@Injectable()
export class UniversityDomainService {
  async isUniversityEmail(email: string, expectedUnivName?: string) {
    const domain = email.split('@')[1]?.toLowerCase();
    if (!domain) return { ok: false, reason: 'NO_DOMAIN' };
    const academic = isAcademic(email);
    if (!academic) return { ok: false, reason: 'NOT_ACADEMIC_DOMAIN' };
    // 선택: 학교명 매칭(간단 버전 — 실서비스는 매핑 테이블을 권장)
    if (expectedUnivName) {
      const norm = (s: string) => s.replace(/\s+/g, '').toLowerCase();
      if (!norm(domain).includes('ac.kr') && !norm(domain).includes('edu')) {
        // 해외/비표준 예외는 별도 화이트리스트로
      }
    }
    return { ok: true };
  }
}

import { Injectable } from '@nestjs/common';
import { isAcademic } from 'swot-node'; // *.edu, *.ac.kr 등 학술 도메인 판별

type Reason = 'NO_DOMAIN' | 'NOT_ACADEMIC_DOMAIN';

@Injectable()
export class UniversityDomainService {
  async isUniversityEmail(email: string, expectedUnivName?: string) {
    const domain = email.split('@')[1]?.toLowerCase();
    if (!domain) return { ok: false, reason: 'NO_DOMAIN' as Reason };

    const academic = isAcademic(email); // 도메인만 줘도 동작
    if (!academic) return { ok: false, reason: 'NOT_ACADEMIC_DOMAIN' as Reason };

    // (선택) expectedUnivName 매칭이 필요하면 여기에 로직 추가
    return { ok: true as const };
  }
}

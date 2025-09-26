// // kumeong-api/src/features/university/university-verification.controller.ts
// import { Body, Controller, Headers, HttpCode, HttpStatus, Post } from '@nestjs/common';
// import { SendEmailCodeDto } from '../dto/send-email-code.dto';
// import { VerifyEmailCodeDto } from '../dto/verify-email-code.dto';
// import { CodeStoreService } from '../../core/verify/code-store.service';
// import { UniversityDomainService } from '../../core/verify/university-domain.service';
// import { UniversityEmailService } from './university-email.service';
// import { UsersService } from '../../modules/users/users.service';
// import { JwtService } from '@nestjs/jwt';

// const CODE_LENGTH = Number(process.env.EMAIL_CODE_LENGTH ?? 6);
// // ✅ 프로덕션 여부 고정
// const isProd = process.env.NODE_ENV === 'production';

// function generateNumericCode(len = CODE_LENGTH) {
//   let s = '';
//   for (let i = 0; i < len; i++) s += Math.floor(Math.random() * 10).toString();
//   return s; // 선행 0 허용
// }

// /**
//  * Base path: /university/email
//  * - POST /university/email/send
//  * - POST /university/email/verify
//  * - POST /university/email/dev/peek   (DEV 전용)
//  */
// @Controller('university/email')
// export class UniversityVerificationController {
//   constructor(
//     private readonly codeStore: CodeStoreService,
//     private readonly domainSvc: UniversityDomainService,
//     private readonly uniEmail: UniversityEmailService,
//     private readonly usersService: UsersService,
//     private readonly jwt: JwtService,
//   ) {}

//   /** ① 인증코드 메일 전송 */
//   @Post('send')
//   @HttpCode(HttpStatus.OK)
//   async send(@Body() dto: SendEmailCodeDto) {
//     const email = String(dto.email ?? '').trim().toLowerCase();

//     // *.ac.kr 확인 + 학교명 파싱
//     const { schoolName } = this.domainSvc.assertUniversityEmail(email);

//     // 정책/쿨다운 확인
//     const policy = this.codeStore.getPolicy(); // { ttlSec, cooldownSec, maxAttempts }
//     const can = this.codeStore.canSend(email);
//     if (!can.ok) {
//       return { ok: false as const, reason: 'cooldown' as const, nextSendAt: can.nextSendAt };
//     }

//     // 코드 생성
//     const code = generateNumericCode();

//     // ✅ DEV에서만 코드 콘솔 노출
//     if (!isProd) {
//       console.log(`[DEV][EMAIL-CODE] ${email} -> ${code} (ttl:${policy.ttlSec}s)`);
//     }

//     // 실제 메일 발송(DEV에서는 실패해도 진행)
//     try {
//       await this.uniEmail.sendVerificationCode(email, code, policy.ttlSec);
//     } catch (e) {
//       if (isProd) {
//         return { ok: false as const, reason: 'mail_send_failed' as const };
//       }
//       console.warn(
//         '[UniversityVerification] sendVerificationCode failed (dev ignored):',
//         (e as any)?.message ?? e,
//       );
//     }

//     // 저장(만료/시도횟수/마지막발송 갱신)
//     this.codeStore.set(email, code);

//     const nextSendAt = new Date(Date.now() + policy.cooldownSec * 1000).toISOString();
//     const res: any = { ok: true, ttlSec: policy.ttlSec, nextSendAt, school: schoolName };

//     // ✅ DEV에서만 devCode 포함
//     if (!isProd) res.devCode = code;

//     return res;
//   }

//   /** ② 인증코드 검증 */
//   @Post('verify')
//   @HttpCode(HttpStatus.OK)
//   async verify(@Body() dto: VerifyEmailCodeDto) {
//     const email = String(dto.email ?? '').trim().toLowerCase();

//     // 코드 검증 (expired | mismatch | too_many | not_found 등 사유 포함)
//     const result = this.codeStore.verify(email, dto.code);
//     if (!result.ok) {
//       return { ok: false as const, reason: result.reason };
//     }

//     // 이메일에서 학교명 재파싱
//     const { schoolName } = this.domainSvc.assertUniversityEmail(email);

//     // 사용자 프로필 갱신 (메모리/DB 모두 커버)
//     const upd = await this.usersService.markUniversityVerifiedByEmail(email, schoolName);
//     const profileUpdated = !!(upd as any)?.updated || !!(upd as any)?.already;

//     // ✅ 학교인증 전용 토큰 생성 (회원가입 시 요구)
//     const univToken = await this.jwt.signAsync(
//       { email, purpose: 'univ', school: schoolName },
//       {
//         secret: process.env.UNIV_TOKEN_SECRET ?? 'dev_univ_token_secret',
//         expiresIn: process.env.UNIV_TOKEN_EXPIRES ?? '30m',
//       },
//     );

//     if (!upd.ok) {
//       // 유저 미존재 등: 인증 자체는 통과했지만 프로필 반영 실패 사유 전달
//       return {
//         ok: true as const,
//         verified: true as const,
//         profileUpdated: false as const,
//         profileReason: (upd as any)?.reason,
//         school: schoolName,
//         univToken, // 발급은 정상 진행
//       };
//     }

//     return {
//       ok: true as const,
//       verified: true as const,
//       profileUpdated,
//       school: schoolName,
//       profileSource: (upd as any)?.source ?? null,
//       univToken, // ✅ 반환
//     };
//   }

//   /** ③ (DEV 전용) 현재 유효한 코드 조회
//    *  - PROD 또는 ALLOW_CODE_PEEK !== 'true' → forbidden
//    *  - 헤더 X-Dev-Secret 이 .env의 DEV_CODE_PEEK_SECRET와 일치해야 함
//    *  - 만료/시도초과/not_found면 ok:false, reason:'not_found'
//    */
//   @Post('dev/peek')
//   @HttpCode(HttpStatus.OK)
//   async devPeek(
//     @Body() body: { email: string },
//     @Headers('x-dev-secret') devSecret: string,
//   ) {
//     if (isProd || process.env.ALLOW_CODE_PEEK !== 'true') {
//       return { ok: false as const, reason: 'forbidden' as const, message: 'disabled_in_prod' };
//     }

//     const expected = process.env.DEV_CODE_PEEK_SECRET ?? '';
//     if (!expected || devSecret !== expected) {
//       return { ok: false as const, reason: 'unauthorized' as const, message: 'invalid_dev_secret' };
//     }

//     const email = String(body?.email ?? '').trim().toLowerCase();
//     if (!email) return { ok: false as const, reason: 'bad_request' as const, message: 'email_required' };

//     // 학교 이메일 규칙 검증(도메인/형식)
//     try {
//       this.domainSvc.assertUniversityEmail(email);
//     } catch {
//       return { ok: false as const, reason: 'bad_request' as const, message: 'invalid_univ_email' };
//     }

//     // CodeStore의 유효 코드 조회 (별도 메서드 필요)
//     const peek = this.codeStore.peekActiveCode(email);
//     if (!peek) {
//       return { ok: false as const, reason: 'not_found' as const };
//     }

//     // ✅ DEV 전용이므로 코드 그대로 반환
//     return { ok: true as const, code: peek.code, expiresAt: peek.expiresAt };
//   }
// }

// kumeong-api/src/features/university/university-verification.controller.ts
import { Body, Controller, Headers, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { SendEmailCodeDto } from '../dto/send-email-code.dto';
import { VerifyEmailCodeDto } from '../dto/verify-email-code.dto';
import { CodeStoreService } from '../../core/verify/code-store.service';
import { UniversityDomainService } from '../../core/verify/university-domain.service';
import { UniversityEmailService } from './university-email.service';
import { UsersService } from '../../modules/users/users.service';
import { JwtService } from '@nestjs/jwt';

const CODE_LENGTH = Number(process.env.EMAIL_CODE_LENGTH ?? 6);
// ✅ 프로덕션 여부 고정
const isProd = process.env.NODE_ENV === 'production';

function generateNumericCode(len = CODE_LENGTH) {
  let s = '';
  for (let i = 0; i < len; i++) s += Math.floor(Math.random() * 10).toString();
  return s; // 선행 0 허용
}

/**
 * Base path: /university/email
 * - POST /university/email/send
 * - POST /university/email/verify
 * - POST /university/email/dev/peek   (DEV 전용)
 */
@Controller('university/email')
export class UniversityVerificationController {
  constructor(
    private readonly codeStore: CodeStoreService,
    private readonly domainSvc: UniversityDomainService,
    private readonly uniEmail: UniversityEmailService,
    private readonly usersService: UsersService,
    private readonly jwt: JwtService,
  ) {}

  /** ① 인증코드 메일 전송 */
  @Post('send')
  @HttpCode(HttpStatus.OK)
  async send(@Body() dto: SendEmailCodeDto) {
    const email = String(dto.email ?? '').trim().toLowerCase();

    // *.ac.kr 확인 + 학교명 파싱
    const { schoolName } = this.domainSvc.assertUniversityEmail(email);

    // 정책/쿨다운 확인
    const policy = this.codeStore.getPolicy(); // { ttlSec, cooldownSec, maxAttempts }
    const can = this.codeStore.canSend(email);
    if (!can.ok) {
      return { ok: false as const, reason: 'cooldown' as const, nextSendAt: can.nextSendAt };
    }

    // 코드 생성
    const code = generateNumericCode();

    // ✅ DEV에서만 코드 콘솔 노출 (응답에는 절대 포함 X)
    if (!isProd) {
      console.log(`[DEV][EMAIL-CODE] ${email} -> ${code} (ttl:${policy.ttlSec}s)`);
    }

    // 실제 메일 발송(DEV에서는 실패해도 진행)
    try {
      await this.uniEmail.sendVerificationCode(email, code, policy.ttlSec);
    } catch (e) {
      if (isProd) {
        return { ok: false as const, reason: 'mail_send_failed' as const };
      }
      console.warn(
        '[UniversityVerification] sendVerificationCode failed (dev ignored):',
        (e as any)?.message ?? e,
      );
    }

    // 저장(만료/시도횟수/마지막발송 갱신)
    this.codeStore.set(email, code);

    const nextSendAt = new Date(Date.now() + policy.cooldownSec * 1000).toISOString();
    // ✅ devCode 미포함 응답
    return { ok: true, ttlSec: policy.ttlSec, nextSendAt, school: schoolName };
  }

  /** ② 인증코드 검증 */
  @Post('verify')
  @HttpCode(HttpStatus.OK)
  async verify(@Body() dto: VerifyEmailCodeDto) {
    const email = String(dto.email ?? '').trim().toLowerCase();

    // 코드 검증 (expired | mismatch | too_many | not_found 등 사유 포함)
    const result = this.codeStore.verify(email, dto.code);
    if (!result.ok) {
      return { ok: false as const, reason: result.reason };
    }

    // 이메일에서 학교명 재파싱
    const { schoolName } = this.domainSvc.assertUniversityEmail(email);

    // 사용자 프로필 갱신 (메모리/DB 모두 커버)
    const upd = await this.usersService.markUniversityVerifiedByEmail(email, schoolName);
    const profileUpdated = !!(upd as any)?.updated || !!(upd as any)?.already;

    // ✅ 학교인증 전용 토큰 생성 (회원가입 시 요구)
    const univToken = await this.jwt.signAsync(
      { email, purpose: 'univ', school: schoolName },
      {
        secret: process.env.UNIV_TOKEN_SECRET ?? 'dev_univ_token_secret',
        expiresIn: process.env.UNIV_TOKEN_EXPIRES ?? '30m',
      },
    );

    if (!upd.ok) {
      // 유저 미존재 등: 인증 자체는 통과했지만 프로필 반영 실패 사유 전달
      return {
        ok: true as const,
        verified: true as const,
        profileUpdated: false as const,
        profileReason: (upd as any)?.reason,
        school: schoolName,
        univToken, // 발급은 정상 진행
      };
    }

    return {
      ok: true as const,
      verified: true as const,
      profileUpdated,
      school: schoolName,
      profileSource: (upd as any)?.source ?? null,
      univToken, // ✅ 반환
    };
  }

  /** ③ (DEV 전용) 현재 유효한 코드 조회
   *  - PROD 또는 ALLOW_CODE_PEEK !== 'true' → forbidden
   *  - 헤더 X-Dev-Secret 이 .env의 DEV_CODE_PEEK_SECRET와 일치해야 함
   *  - 만료/시도초과/not_found면 ok:false, reason:'not_found'
   */
  @Post('dev/peek')
  @HttpCode(HttpStatus.OK)
  async devPeek(
    @Body() body: { email: string },
    @Headers('x-dev-secret') devSecret: string,
  ) {
    if (isProd || process.env.ALLOW_CODE_PEEK !== 'true') {
      return { ok: false as const, reason: 'forbidden' as const, message: 'disabled_in_prod' };
    }

    const expected = process.env.DEV_CODE_PEEK_SECRET ?? '';
    if (!expected || devSecret !== expected) {
      return { ok: false as const, reason: 'unauthorized' as const, message: 'invalid_dev_secret' };
    }

    const email = String(body?.email ?? '').trim().toLowerCase();
    if (!email) return { ok: false as const, reason: 'bad_request' as const, message: 'email_required' };

    // 학교 이메일 규칙 검증(도메인/형식)
    try {
      this.domainSvc.assertUniversityEmail(email);
    } catch {
      return { ok: false as const, reason: 'bad_request' as const, message: 'invalid_univ_email' };
    }

    // CodeStore의 유효 코드 조회
    const peek = this.codeStore.peekActiveCode(email);
    if (!peek) {
      return { ok: false as const, reason: 'not_found' as const };
    }

    // ✅ DEV 전용이므로 코드 그대로 반환
    return { ok: true as const, code: peek.code, expiresAt: peek.expiresAt };
  }
}

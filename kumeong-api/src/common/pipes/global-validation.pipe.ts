// src/common/pipes/global-validation.pipe.ts
import { BadRequestException, ValidationError, ValidationPipe } from '@nestjs/common';

// ─────────────────────────────────────────────────────────────
// 유틸: 순환 참조 안전 직렬화 + 길이 제한
// ─────────────────────────────────────────────────────────────
function safePreview(val: unknown, limit = 200): unknown {
  try {
    if (val == null) return val;
    if (typeof val === 'string') {
      return val.length > limit ? `${val.slice(0, limit)}… (len=${val.length})` : val;
    }
    if (typeof val === 'number' || typeof val === 'boolean') return val;
    if (typeof val === 'bigint') return `${val.toString()}n`;
    if (Array.isArray(val)) {
      const s = JSON.stringify(val, getCircularReplacer());
      return s.length > limit ? `${s.slice(0, limit)}… (len=${s.length})` : JSON.parse(s);
    }
    if (typeof val === 'object') {
      const s = JSON.stringify(val, getCircularReplacer());
      return s.length > limit ? `${s.slice(0, limit)}… (len=${s.length})` : JSON.parse(s);
    }
    return String(val);
  } catch {
    return '[unserializable]';
  }
}

function getCircularReplacer() {
  const seen = new WeakSet();
  return (_key: string, value: unknown) => {
    if (typeof value === 'object' && value !== null) {
      if (seen.has(value as object)) return '[Circular]';
      seen.add(value as object);
    }
    return value as any;
  };
}

// ─────────────────────────────────────────────────────────────
// 유틸: ValidationError 트리 → 평탄화(경로 포함)
// ─────────────────────────────────────────────────────────────
type FlatError = {
  targetDto?: string;
  path: string; // user.profile.email 처럼 중첩 경로
  value?: unknown;
  constraints?: Record<string, string>;
};

function flattenErrors(errs: ValidationError[], prefix = ''): FlatError[] {
  const out: FlatError[] = [];
  for (const e of errs ?? []) {
    const path = prefix ? `${prefix}.${e.property}` : e.property;
    const base: FlatError = {
      targetDto: (e.target as any)?.constructor?.name,
      path,
      value: safePreview(e.value),
      constraints: e.constraints,
    };
    if (e.constraints && Object.keys(e.constraints).length) {
      out.push(base);
    }
    if (e.children && e.children.length) {
      out.push(...flattenErrors(e.children, path));
    }
    // children만 있고 현재 노드에 constraints가 없는 경우도 경로만 남길 필요 없다면 생략됨
  }
  return out;
}

// ─────────────────────────────────────────────────────────────
// 글로벌 ValidationPipe 팩토리
// ─────────────────────────────────────────────────────────────
export function createGlobalValidationPipe() {
  return new ValidationPipe({
    whitelist: true,                 // DTO에 선언되지 않은 필드 제거
    forbidNonWhitelisted: false,     // 필요 시 true로 바꾸면 알 수 없는 필드에서 바로 400
    forbidUnknownValues: false,      // class-validator의 "unknown object" 경고 무시
    transform: true,                 // DTO로 변환
    transformOptions: { enableImplicitConversion: true }, // number/string 등 암시적 변환 허용
    stopAtFirstError: false,         // 모든 에러 수집
    validationError: {
      target: false,                 // 원본 객체 전체 노출 방지
      value: false,                  // 기본 value 노출 끔(우리가 safePreview로 대체 제공)
    },
    exceptionFactory: (errors: ValidationError[]) => {
      const details = flattenErrors(errors);

      // 파일/라인 포함된 스택 캡처 (source-map-support가 TS 라인으로 매핑)
      const stack = new Error('ValidationError').stack;

      // 라우트/컨트롤러 정보는 RouteContextInterceptor + ValidationErrorFilter에서 합쳐서 응답
      return new BadRequestException({
        message: 'Validation failed',
        details,
        stack,
      });
    },
  });
}

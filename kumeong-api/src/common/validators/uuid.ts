// src/common/validators/uuid.ts

import { registerDecorator, ValidationOptions } from 'class-validator';

/**
 * UUID v1 정규식:
 *  - time-low(8) - time-mid(4) - version=1 + time-hi(3) - variant(8|9|a|b) + clock-seq(3) - node(12)
 */
export const UUID_V1 =
  /^[0-9a-f]{8}-[0-9a-f]{4}-1[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** (옵션) 하이픈 포함 36자 UUID 대략 검증(버전 불문) */
export const UUID_36 =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** 런타임 헬퍼 */
export const isUuidV1 = (v: unknown): v is string =>
  typeof v === 'string' && UUID_V1.test(v);

/**
 * class-validator용 커스텀 데코레이터
 * 사용법:  @IsUUIDv1({ message: 'UUIDv1 형식이어야 합니다.' })
 */
export function IsUUIDv1(validationOptions?: ValidationOptions) {
  return function (object: object, propertyName: string) {
    registerDecorator({
      name: 'IsUUIDv1',
      target: object.constructor,
      propertyName,
      options: validationOptions,
      validator: {
        validate(value: any) {
          return typeof value === 'string' && UUID_V1.test(value);
        },
        defaultMessage() {
          return 'UUIDv1 형식이 아닙니다.';
        },
      },
    });
  };
}

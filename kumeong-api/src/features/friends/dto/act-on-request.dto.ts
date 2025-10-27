// src/features/friends/dto/act-on-request.dto.ts
import { IsUUIDv1 } from '../../../common/validators/uuid';

export class ActOnRequestDto {
  @IsUUIDv1({ message: 'requestId는 UUIDv1 형식이어야 합니다.' })
  requestId!: string;
}

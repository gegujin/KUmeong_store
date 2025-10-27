import { Transform } from 'class-transformer';
import { IsOptional, IsString, MaxLength } from 'class-validator';

export class PutReadCursorDto {
  /**
   * Accepts any of:
   * - lastReadMessageId (preferred)
   * - lastMessageId / messageId / lastReadId
   * - lastReadSeq / seq (서버에서 seq→messageId 매핑을 지원한다면)
   */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Transform(({ value, obj }) =>
    value ??
    obj.lastReadMessageId ??
    obj.lastMessageId ??
    obj.messageId ??
    obj.lastReadId ??
    obj.lastReadSeq ??
    obj.seq
  )
  lastReadMessageId?: string;
}

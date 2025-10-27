// ✅ 교체 코드: src/common/pipes/relaxed-uuid.pipe.ts (파일명 유지해도 됨)
import { BadRequestException, Injectable, PipeTransform } from '@nestjs/common';
import { validate as uuidValidate } from 'uuid';

@Injectable()
export class RelaxedUuidPipe implements PipeTransform<string, string> {
  transform(value: string): string {
    const v = (value ?? '').trim();
    if (!uuidValidate(v)) {
      throw new BadRequestException('param must be a valid UUID');
    }
    return v.toLowerCase();
  }
}

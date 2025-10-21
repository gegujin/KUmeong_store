// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\products\dto\create-product.dto.ts
import {
  IsArray,
  ArrayMaxSize,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { ProductStatus } from '../entities/product.entity';

export class CreateProductDto {
  @ApiProperty({ example: '캠퍼스 패딩', maxLength: 100, description: '상품 제목' })
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : value,
  )
  @IsString()
  @MaxLength(100)
  title!: string;

  @ApiProperty({
    example: 30000,
    minimum: 0,
    description: '가격(정수). 문자열로 와도 숫자로 변환됩니다.',
  })
  @Transform(({ value }) => {
    if (typeof value === 'string') {
      const n = Number(value.replace(/[, ]/g, ''));
      return Number.isFinite(n) ? Math.trunc(n) : value;
    }
    return Number.isFinite(value) ? Math.trunc(value) : value;
  })
  @IsInt()
  @Min(0) // 무료 나눔 허용 안 하려면 1로 변경
  price!: number;

  @ApiPropertyOptional({
    enum: ProductStatus,
    example: ProductStatus.ON_SALE, // ✅ LISTED → ON_SALE
    description: '상품 상태',
  })
  @IsOptional()
  @IsEnum(ProductStatus)
  status?: ProductStatus;

  @ApiPropertyOptional({ example: '거의 새상품입니다.', description: '설명' })
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : value,
  )
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ example: '의류', description: '카테고리' })
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : value,
  )
  @IsOptional()
  @IsString()
  category?: string;

  @ApiPropertyOptional({
    type: [String],
    example: ['https://.../img1.jpg', 'https://.../img2.jpg'],
    description:
      '이미지 URL 배열. 단일 문자열 또는 콤마구분 문자열도 허용됨(배열로 변환).',
  })
  @Transform(({ value }) => {
    if (value == null) return value;
    if (Array.isArray(value)) {
      return value
        .map((v) => (typeof v === 'string' ? v.trim() : v))
        .filter((v) => typeof v === 'string' && v.length > 0);
    }
    if (typeof value === 'string') {
      // "url1, url2" → ["url1","url2"]
      return value
        .split(',')
        .map((v) => v.trim())
        .filter((v) => v.length > 0);
    }
    return value;
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  // @IsUrl({}, { each: true }) // URL만 허용하려면 주석 해제
  @IsString({ each: true })
  images?: string[];
}

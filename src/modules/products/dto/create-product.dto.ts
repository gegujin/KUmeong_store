// C:\Users\82105\KU-meong Store\kumeong-api\src\modules\products\dto\create-product.dto.ts
import {
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { ProductStatus } from '../entities/product.entity';

export class CreateProductDto {
  @ApiProperty({
    example: '캠퍼스 패딩',
    maxLength: 100,
    description: '상품 제목',
  })
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : value,
  )
  @IsString()
  @IsNotEmpty()
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
  priceWon!: number; // ✅ DB/엔티티 기준으로 변경

  @ApiPropertyOptional({ example: '의류', description: '카테고리' })
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : value,
  )
  @IsOptional()
  @IsString()
  @MaxLength(50)
  category?: string;

  @ApiPropertyOptional({ example: '거의 새상품입니다.', description: '상품 설명' })
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : value,
  )
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({
    enum: ProductStatus,
    example: ProductStatus.LISTED, // ✅ 실제 ENUM 값으로 수정
    description: '상품 상태 (LISTED, RESERVED, SOLD)',
  })
  @IsOptional()
  @IsEnum(ProductStatus)
  status?: ProductStatus;
}

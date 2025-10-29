// kumeong-api/src/modules/products/dto/create-product.dto.ts
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
  @ApiProperty({ example: '캠퍼스 패딩', maxLength: 100, description: '상품 제목' })
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : value,
  )
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  title!: string;

  @ApiProperty({ example: 30000, minimum: 0, description: '가격(정수).' })
  @Transform(({ value }) => {
    if (typeof value === 'string') {
      const n = Number(value.replace(/[, ]/g, ''));
      return Number.isFinite(n) ? Math.trunc(n) : value;
    }
    return Number.isFinite(value) ? Math.trunc(value) : value;
  })
  @IsInt()
  priceWon!: number;

  // ✅ categoryPath: 프론트 "의류/패션>남성의류" 형태 공백 정리
  @ApiPropertyOptional({ example: '의류/패션>남성의류' })
  @Transform(({ value }) =>
    typeof value === 'string'
      ? value.replace(/\s*>\s*/g, '>').replace(/\s+/g, ' ').trim()
      : value,
  )
  @IsOptional()
  @IsString()
  @MaxLength(50)
  categoryPath?: string;

  @ApiPropertyOptional({ example: '모시래마을' })
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : value,
  )
  @IsOptional()
  @IsString()
  @MaxLength(120)
  locationText?: string;

  @ApiPropertyOptional({
    enum: ProductStatus,
    example: ProductStatus.LISTED,
    description: '상품 상태 (LISTED, RESERVED, SOLD)',
  })
  @IsOptional()
  @IsEnum(ProductStatus)
  status?: ProductStatus;

  @ApiPropertyOptional({ example: '거의 새상품입니다.' })
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsOptional()
  @IsString()
  description?: string;
}

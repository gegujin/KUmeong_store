// src/products/dto/create-product.dto.ts
import {
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

// 공통 trim 변환기
const trim = ({ value }: { value: any }) =>
  typeof value === 'string' ? value.trim() : value;

export class CreateProductDto {
  @ApiProperty({ example: '과잠', maxLength: 100, description: '상품 제목' })
  @Transform(trim)
  @IsString()
  @MaxLength(100)
  title!: string;

  @ApiProperty({ example: 1000, minimum: 0, description: '가격(정수)' })
  @Transform(({ value }) => {
    if (value === null || value === undefined || value === '') return 0;
    // "1,234" 같은 문자열도 허용
    const n =
      typeof value === 'string'
        ? Number(value.replace(/[, ]/g, ''))
        : Number(value);
    if (!Number.isFinite(n) || n < 0) return 0;
    return Math.floor(n);
  })
  @IsInt({ message: 'priceWon must be an integer number' })
  @Min(0, { message: 'priceWon must not be less than 0' })
  priceWon!: number;

  @ApiPropertyOptional({ example: '거의 새상품입니다.', description: '상품 설명' })
  @Transform(trim)
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional({ example: '의류/패션 > 남성의류', description: '카테고리' })
  @Transform(trim)
  @IsOptional()
  @IsString()
  @MaxLength(50)
  category?: string;

  @ApiPropertyOptional({
    example: '겨울, 아우터',
    description: '태그(현재 문자열로 수신)',
  })
  @Transform(trim)
  @IsOptional()
  @IsString()
  tags?: string;

  @ApiPropertyOptional({
    enum: ProductStatus,
    example: ProductStatus.ON_SALE, // ✅ 엔티티/DB 값과 일치시키세요
    description: '상품 상태',
  })
  @IsOptional()
  @IsEnum(ProductStatus)
  status?: ProductStatus;

  @ApiPropertyOptional({ example: '서울시 성북구', description: '거래 위치(텍스트)' })
  @Transform(trim)
  @IsOptional()
  @IsString()
  @MaxLength(120)
  locationText?: string;
}
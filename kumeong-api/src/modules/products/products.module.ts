// src/modules/products/products.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MulterModule } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { join } from 'path';
import * as fs from 'fs';

import { ProductsController } from './products.controller';
import { ProductsService } from './products.service';
import { Product } from './entities/product.entity';
import { ProductImage } from './entities/product-image.entity';

const UPLOAD_DIR = join(process.cwd(), 'uploads');

// 안전한 파일명 생성
function safeFilename(original: string) {
  const safe = original.replace(/[^\w.\-]+/g, '_');
  return `${Date.now()}-${safe}`;
}

@Module({
  imports: [
    TypeOrmModule.forFeature([Product, ProductImage]),
    MulterModule.register({
      storage: diskStorage({
        destination: (_req, _file, cb) => {
          try {
            if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });
          } catch { /* ignore */ }
          cb(null, UPLOAD_DIR); // ✅ ./uploads (main.ts에서 /uploads 정적 서빙)
        },
        filename: (_req, file, cb) => cb(null, safeFilename(file.originalname)),
      }),
      // 10MB, 최대 10장
      limits: { fileSize: 10 * 1024 * 1024, files: 10 },
      // 이미지만 허용
      fileFilter: (_req, file, cb) => {
        const ok = /^image\//i.test(file.mimetype);
        cb(null, ok);
      },
    }),
  ],
  controllers: [ProductsController],
  providers: [ProductsService],
  exports: [ProductsService],
})
export class ProductsModule {}

export { UPLOAD_DIR };

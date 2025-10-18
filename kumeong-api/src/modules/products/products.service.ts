// src/products/products.service.ts
import {
  Injectable,
  NotFoundException,
  BadRequestException,
  InternalServerErrorException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Product, ProductStatus } from './entities/product.entity';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import * as fs from 'fs';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class ProductsService {
  constructor(
    @InjectRepository(Product)
    private readonly repo: Repository<Product>,
  ) {}

  async findAll(q: any) {
    // 안전한 파싱 (NaN 방지)
    const rawPage = Number(q?.page ?? 1);
    const rawLimit = Number(q?.limit ?? 20);
    const page = Math.max(1, Number.isFinite(rawPage) ? rawPage : 1);
    const limit = Math.min(100, Math.max(1, Number.isFinite(rawLimit) ? rawLimit : 20));

    const qb = this.repo.createQueryBuilder('p').where('1=1');

    if (q?.q) qb.andWhere('(p.title LIKE :kw OR p.description LIKE :kw)', { kw: `%${q.q}%` });
    if (q?.category) qb.andWhere('p.category = :category', { category: q.category });

    // status가 enum과 일치하는지 체크 (잘못된 값이면 400)
    if (q?.status != null) {
      const s = String(q.status) as keyof typeof ProductStatus;
      const enumValues: string[] = Object.values(ProductStatus) as any;
      if (!enumValues.includes(q.status)) {
        // 혹시 키로 들어오면 값으로 변환 시도
        const mapped = (ProductStatus as any)[s];
        if (!mapped) throw new BadRequestException('invalid_status');
        qb.andWhere('p.status = :status', { status: mapped });
      } else {
        qb.andWhere('p.status = :status', { status: q.status });
      }
    }

    // 숫자 필터
    if (q?.priceMin != null) {
      const v = Number(q.priceMin);
      if (!Number.isFinite(v)) throw new BadRequestException('invalid_priceMin');
      qb.andWhere('p.priceWon >= :min', { min: v });
    }
    if (q?.priceMax != null) {
      const v = Number(q.priceMax);
      if (!Number.isFinite(v)) throw new BadRequestException('invalid_priceMax');
      qb.andWhere('p.priceWon <= :max', { max: v });
    }

    qb.orderBy('p.createdAt', 'DESC').skip((page - 1) * limit).take(limit);

    const [items, total] = await qb.getManyAndCount();
    const pages = Math.max(1, Math.ceil(total / limit));
    return { items, page, limit, total, pages };
  }

  async findOne(id: string): Promise<Product> {
    const item = await this.repo.findOne({ where: { id } });
    if (!item) throw new NotFoundException('Product not found');
    return item;
  }

  async createWithOwner(dto: CreateProductDto, ownerId: string, files?: Express.Multer.File[]): Promise<Product> {
    const imageUrls: string[] = [];

    // 업로드 루트는 main.ts의 static과 동일: public/uploads
    const uploadsDir = path.join(process.cwd(), 'public', 'uploads');
    try {
      await fs.promises.mkdir(uploadsDir, { recursive: true });
    } catch {
      throw new InternalServerErrorException('failed_to_prepare_upload_dir');
    }

    if (files?.length) {
      for (const file of files) {
        // 메모리 저장을 가정(컨트롤러에서 memoryStorage 설정)
        if (!file?.buffer) continue;

        // 이미지 외엔 거부(이중 방어)
        if (!file.mimetype?.startsWith('image/')) {
          throw new BadRequestException('only_image_allowed');
        }

        const safeOriginal = path.basename(file.originalname).replace(/\s+/g, '_');
        const filename = `${uuidv4()}_${safeOriginal}`;
        const filePath = path.join(uploadsDir, filename);

        try {
          await fs.promises.writeFile(filePath, file.buffer);
        } catch {
          throw new InternalServerErrorException('failed_to_save_file');
        }

        imageUrls.push(`/uploads/${filename}`); // main.ts 의 static(/uploads)와 매칭
      }
    }

    // ⚠️ 상태 기본값: 엔티티 enum에 맞게 수정
    // (예: ProductStatus.LISTED / ON_SALE 등 실제 enum 값과 일치해야 함)
    const status = (dto.status ?? (ProductStatus as any).LISTED ?? (ProductStatus as any).ON_SALE) as ProductStatus;

    const entity = this.repo.create({
      title: dto.title,
      priceWon: dto.priceWon,
      description: dto.description,
      category: dto.category,
      sellerId: ownerId,
      status,
      images: imageUrls,
    });

    try {
      return await this.repo.save(entity);
    } catch (e: any) {
      // (선택) 유니크/제약 등 DB 에러 매핑
      // if (e?.code === 'ER_DUP_ENTRY') throw new ConflictException('duplicated_product');
      throw e;
    }
  }

  async update(id: string, dto: UpdateProductDto): Promise<Product> {
    const product = await this.repo.findOne({ where: { id } });
    if (!product) throw new NotFoundException('Product not found');

    Object.assign(product, dto);
    return this.repo.save(product);
  }

  async remove(id: string): Promise<{ deleted: true; id: string }> {
    const product = await this.repo.findOne({ where: { id } });
    if (!product) throw new NotFoundException('Product not found');

    await this.repo.delete(id);
    return { deleted: true, id };
  }
}

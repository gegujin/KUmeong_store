// src/modules/products/products.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DeepPartial, Repository } from 'typeorm';
import { Product, ProductStatus } from './entities/product.entity';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import { QueryProductDto } from './dto/query-product.dto';
import { ProductImage } from './entities/product-image.entity'; // ✅
import { promises as fs } from 'fs';               // ✅
import { join } from 'path';                       // ✅

@Injectable()
export class ProductsService {
  constructor(
    @InjectRepository(Product) private readonly repo: Repository<Product>,
    @InjectRepository(ProductImage) private readonly imageRepo: Repository<ProductImage>, // ✅
  ) {}

  // 목록: 이미지 포함 + ord ASC 정렬
  async findAll(
    q: QueryProductDto,
  ): Promise<{ items: Product[]; page: number; limit: number; total: number; pages: number }> {
    const page = Math.max(1, Number(q?.page ?? 1));
    const limit = Math.min(100, Math.max(1, Number(q?.limit ?? 20)));

    const allowedSort: Array<'createdAt' | 'priceWon' | 'title'> = ['createdAt', 'priceWon', 'title'];
    const orderField = (allowedSort.includes(q?.sort as any) ? (q?.sort as any) : 'createdAt') as
      | 'createdAt' | 'priceWon' | 'title';
    const orderDir: 'ASC' | 'DESC' =
      ((q?.order ?? 'DESC').toString().toUpperCase() === 'ASC' ? 'ASC' : 'DESC');

    const qb = this.repo
      .createQueryBuilder('p')
      .leftJoinAndSelect('p.images', 'img')            // ✅ 이미지 조인
      .where('p.deletedAt IS NULL');

    const status = (q?.status as ProductStatus) ?? ProductStatus.LISTED;
    qb.andWhere('p.status = :status', { status });

    if (q?.q) {
      qb.andWhere('(p.title LIKE :kw OR p.description LIKE :kw OR p.category LIKE :kw)', {
        kw: `%${q.q}%`,
      });
    }

    const catExact = q?.category?.trim();
    const catPrefixRaw = !catExact ? q?.categoryPrefix?.trim() : undefined;
    if (catExact) qb.andWhere('p.category = :category', { category: catExact });
    else if (catPrefixRaw) {
      const esc = catPrefixRaw.replace(/([%_\\])/g, '\\$1');
      qb.andWhere('p.category LIKE :pref ESCAPE "\\\\"', { pref: `${esc}%` });
    }

    if (q?.priceWonMin != null) qb.andWhere('p.priceWon >= :min', { min: Number(q.priceWonMin) });
    if (q?.priceWonMax != null) qb.andWhere('p.priceWon <= :max', { max: Number(q.priceWonMax) });

    qb.orderBy(`p.${orderField}`, orderDir)
      .addOrderBy('p.id', 'DESC')
      .addOrderBy('img.ord', 'ASC')                  // ✅ 첫 이미지 먼저
      .skip((page - 1) * limit)
      .take(limit);

    const [items, total] = await qb.getManyAndCount();
    const pages = Math.max(1, Math.ceil(total / limit));
    return { items, page, limit, total, pages };
  }

  // 단건: 이미지 포함 + ord ASC 정렬
  async findOne(id: string): Promise<Product> {
    const row = await this.repo
      .createQueryBuilder('p')
      .leftJoinAndSelect('p.images', 'img')
      .where('p.id = :id', { id })
      .andWhere('p.deletedAt IS NULL')
      .orderBy('img.ord', 'ASC')                     // ✅ 정렬
      .getOne();

    if (!row) throw new NotFoundException('Product not found');
    return row;
  }

  // 생성: 업로드 파일을 ProductImage로 저장 (ord 사용)
  async create(
    sellerId: string,
    dto: CreateProductDto,
    files: Array<{ filename?: string; path?: string }> = [],
  ): Promise<Product> {
    const entity = this.repo.create({
      title: dto.title,
      priceWon: dto.priceWon,
      category: dto.category,
      description: dto.description,
      locationText: dto.locationText,               // ✅ 위치 저장
      status: ProductStatus.LISTED,
      sellerId,
    } as DeepPartial<Product>);

    const saved = await this.repo.save(entity);

    if (files && files.length > 0) {
      const imgs: DeepPartial<ProductImage>[] = files.map((f, idx) => ({
        productId: saved.id,
        url: f.filename
          ? `/uploads/${f.filename}`
          : (f.path?.replace(/^.*(\/uploads\/)/, '/uploads/') ?? ''),
        ord: idx,                                    // ✅ ord로 순서 저장
      }));
      await this.imageRepo.save(this.imageRepo.create(imgs));
    }

    return this.findOne(saved.id);                  // ✅ 이미지 포함 재조회
  }

  // 수정: 위치/기타 반영 후 이미지 포함 재조회
  async update(id: string, dto: UpdateProductDto): Promise<Product> {
    const exists = await this.repo.findOne({ where: { id } });
    if (!exists || exists.deletedAt) throw new NotFoundException('Product not found');

    const merged = this.repo.merge(exists, {
      title: dto.title,
      priceWon: dto.priceWon,
      category: dto.category,
      description: dto.description,
      locationText: dto.locationText,               // ✅ 위치 수정 반영
      status: dto.status,
    } as DeepPartial<Product>);

    await this.repo.save(merged);
    return this.findOne(id);
  }

  async remove(id: string): Promise<{ deleted: true; id: string }> {
    const exists = await this.repo.findOne({ where: { id } });
    if (!exists || exists.deletedAt) throw new NotFoundException('Product not found');
    await this.repo.update(id, { deletedAt: () => 'CURRENT_TIMESTAMP' } as any);
    return { deleted: true, id };
  }
}

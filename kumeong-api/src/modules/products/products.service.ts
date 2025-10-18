import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Product, ProductStatus } from './entities/product.entity';
import { CreateProductDto } from './dto/create-product.dto';
import { UpdateProductDto } from './dto/update-product.dto';
import * as fs from 'fs';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';
import type { Express } from 'express';

@Injectable()
export class ProductsService {
  constructor(
    @InjectRepository(Product)
    private readonly repo: Repository<Product>,
  ) {}

  async findAll(q: any) {
    const page = Math.max(1, Number(q?.page ?? 1));
    const limit = Math.min(100, Math.max(1, Number(q?.limit ?? 20)));

    const qb = this.repo.createQueryBuilder('p').where('1=1');
    if (q?.q) qb.andWhere('(p.title LIKE :kw OR p.description LIKE :kw)', { kw: `%${q.q}%` });
    if (q?.category) qb.andWhere('p.category = :category', { category: q.category });
    if (q?.status) qb.andWhere('p.status = :status', { status: q.status });
    if (q?.priceMin != null) qb.andWhere('p.priceWon >= :min', { min: Number(q.priceMin) });
    if (q?.priceMax != null) qb.andWhere('p.priceWon <= :max', { max: Number(q.priceMax) });

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

    if (files?.length) {
      const uploadsDir = path.join(__dirname, '..', '..', 'uploads');
      if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });

      for (const file of files) {
        if (!file.buffer) continue; // 안전 체크
        const filename = `${uuidv4()}_${file.originalname}`;
        const filePath = path.join(uploadsDir, filename);
        fs.writeFileSync(filePath, file.buffer);
        imageUrls.push(`/uploads/${filename}`);
      }
    }

    const entity = this.repo.create({
      title: dto.title,
      priceWon: dto.priceWon, // price -> priceWon
      description: dto.description,
      category: dto.category,
      sellerId: ownerId,       // ownerId -> sellerId
      status: dto.status ?? ProductStatus.ON_SALE,
      images: imageUrls,
    });

    return this.repo.save(entity);
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

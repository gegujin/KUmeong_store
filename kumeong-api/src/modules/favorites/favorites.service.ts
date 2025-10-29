// src/modules/favorites/favorites.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { v4 as uuidv4 } from 'uuid';
import { Favorite } from './entities/favorite.entity';
import { Product } from '../products/entities/product.entity';

@Injectable()
export class FavoritesService {
  constructor(
    @InjectRepository(Favorite) private readonly favRepo: Repository<Favorite>,
    @InjectRepository(Product) private readonly prodRepo: Repository<Product>,
    private readonly ds: DataSource,
  ) {}

  /** 특정 상품 최종 찜 개수 */
  async countForProduct(productId: string): Promise<number> {
    return this.favRepo.count({ where: { productId } });
  }

  /** 하트 토글 (최종 상태 + 카운트 반환) */
  async toggle(meId: string, productId: string) {
    // 상품 존재 확인
    const product = await this.prodRepo.findOne({ where: { id: productId } });
    if (!product) throw new NotFoundException('상품을 찾을 수 없습니다.');

    // 트랜잭션으로 토글 + 카운트 읽기 일관성 확보
    const result = await this.ds.transaction(async (tm) => {
      const repo = tm.getRepository(Favorite);

      const existing = await repo.findOne({
        where: { ownerUserId: meId, productId },
      });

      if (existing) {
        await repo.delete({ ownerUserId: meId, productId });
        const cnt = await repo.count({ where: { productId } });
        return { isFavorited: false, favoriteCount: cnt };
      } else {
        await repo.save({
          id: uuidv4(),
          ownerUserId: meId,
          productId,
        });
        const cnt = await repo.count({ where: { productId } });
        return { isFavorited: true, favoriteCount: cnt };
      }
    });

    return result;
  }

  /** 내가 찜한 상품 리스트 (상품 카드 호환 필드) */
  async listMine(meId: string, page = 1, limit = 20) {
    const offset = (page - 1) * limit;

    const items = await this.ds
      .createQueryBuilder()
      .from('favorites', 'f')
      .innerJoin('products', 'p', 'p.id = f.productId')
      .select([
        'p.id           AS id',
        'p.title        AS title',
        'p.priceWon     AS priceWon',
        'p.status       AS status',
        'p.description  AS description',
        'p.category     AS category',
        'p.images       AS images',
        'p.sellerId     AS sellerId',
        'p.createdAt    AS createdAt',
        'p.updatedAt    AS updatedAt',
        'p.deletedAt    AS deletedAt',
        'p.locationText AS locationText',
        'f.createdAt    AS f_createdAt', // 정렬 컬럼
      ])
      .where('f.ownerUserId = :uid', { uid: meId })
      .orderBy('f.createdAt', 'DESC')
      .offset(offset)
      .limit(limit)
      .getRawMany();

    const totalRow = await this.ds
      .createQueryBuilder()
      .from('favorites', 'f')
      .select('COUNT(*)', 'cnt')
      .where('f.ownerUserId = :uid', { uid: meId })
      .getRawOne();

    const normalized = items.map((r: any) => ({
      id: r.id,
      title: r.title,
      priceWon: Number(r.priceWon ?? r.pricewon ?? 0),
      status: r.status,
      description: r.description,
      category: r.category,
      images: Array.isArray(r.images)
        ? r.images
        : (typeof r.images === 'string' && r.images.trim().startsWith('[')
            ? JSON.parse(r.images)
            : []),
      sellerId: r.sellerId ?? r.sellerid,
      createdAt: r.createdAt ?? r.createdat,
      updatedAt: r.updatedAt ?? r.updatedat,
      deletedAt: r.deletedAt ?? r.deletedat,
      locationText: r.locationText ?? r.locationtext,
      isFavorited: true,
    }));

    return {
      items: normalized,
      total: Number(totalRow?.cnt ?? 0),
      page,
      limit,
    };
  }
}

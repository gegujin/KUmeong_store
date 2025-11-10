// src/modules/favorites/favorites.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Favorite } from './entities/favorite.entity';
import { v4 as uuidv4 } from 'uuid';
import { Product } from '../products/entities/product.entity';

@Injectable()
export class FavoritesService {
  constructor(
    @InjectRepository(Favorite) private readonly favRepo: Repository<Favorite>,
    @InjectRepository(Product)  private readonly prodRepo: Repository<Product>,
    private readonly ds: DataSource,
  ) {}

  /**
   * 하트(찜) 토글
   * - 결과에 isFavorited + favoriteCount(총 찜수) 반환
   * - 유니크 충돌(1062)도 안전 처리
   * - 경합 상황 완화(빠른 연타)용 트랜잭션 적용
   *
   * ⚠️ DB에 UNIQUE(ownerUserId, productId) 인덱스가 있어야 중복행 자체가 생성되지 않음.
   *   예) ALTER TABLE favorites ADD UNIQUE KEY ux_fav_owner_product (ownerUserId, productId);
   */
  async toggle(meId: string, productId: string) {
    // 상품 존재 확인
    const p = await this.prodRepo.findOne({ where: { id: productId } });
    if (!p) throw new NotFoundException('상품을 찾을 수 없습니다.');

    return await this.ds.transaction(async (manager) => {
      const favRepo = manager.withRepository(this.favRepo);

      // 현재 상태 조회
      const exists = await favRepo.findOne({ where: { ownerUserId: meId, productId } });

      if (exists) {
        await favRepo.delete({ ownerUserId: meId, productId });
        const favoriteCount = await favRepo.count({ where: { productId } });
        return { isFavorited: false, favoriteCount, productId };
      }

      // 신규 저장 (유니크 충돌 방지)
      try {
        await favRepo.insert({
          id: uuidv4(),
          ownerUserId: meId,
          productId,
        });
      } catch (e: any) {
        // MySQL: ER_DUP_ENTRY (1062) → 이미 찜 상태로 간주
        if (!(e?.code === 'ER_DUP_ENTRY' || e?.errno === 1062)) {
          throw e;
        }
      }

      const favoriteCount = await favRepo.count({ where: { productId } });
      return { isFavorited: true, favoriteCount, productId };
    });
  }

  /**
   * 내가 찜한 상품 리스트
   * - 1 상품 = 1 행 보장 (중복 제거)
   * - f.createdAt(찜한 시간) 기준 최신순
   * - total = DISTINCT(productId) 카운트
   *
   * 구현 포인트:
   *  1) COUNT(DISTINCT f.productId) 로 총 개수 계산
   *  2) GROUP BY p.id + MAX(f.createdAt) 로 정렬 기준(f_createdAt) 뽑고
   *     나머지 칼럼은 ANY_VALUE()로 집계해 중복을 1행으로 압축 (ONLY_FULL_GROUP_BY 안전)
   */
  async listMine(meId: string, page = 1, limit = 20) {
    const offset = (page - 1) * limit;

    // 총 개수: productId 기준 중복 제거
    const totalRow = await this.ds
      .createQueryBuilder()
      .from('favorites', 'f')
      .select('COUNT(DISTINCT f.productId)', 'cnt')
      .where('f.ownerUserId = :uid', { uid: meId })
      .getRawOne<{ cnt: string }>();

    const total = Number(totalRow?.cnt ?? 0);

    if (total === 0) {
      return { items: [], total: 0, page, limit };
    }

    // 목록: 1상품 1행으로 압축 + 찜한 시간 최신순
    // MySQL 8+ 가정. (ANY_VALUE 사용으로 ONLY_FULL_GROUP_BY 대응)
    const rows = await this.ds
      .createQueryBuilder()
      .from((qb) => {
        return qb
          .from('favorites', 'f')
          .innerJoin('products', 'p', 'p.id = f.productId')
          .select([
            'p.id                                               AS id',
            'ANY_VALUE(p.title)                                AS title',
            'ANY_VALUE(p.priceWon)                             AS priceWon',
            'ANY_VALUE(p.status)                               AS status',
            'ANY_VALUE(p.description)                          AS description',
            'ANY_VALUE(p.category)                             AS category',
            'ANY_VALUE(p.images)                               AS images',
            'ANY_VALUE(p.sellerId)                             AS sellerId',
            'ANY_VALUE(p.createdAt)                            AS createdAt',
            'ANY_VALUE(p.updatedAt)                            AS updatedAt',
            'ANY_VALUE(p.deletedAt)                            AS deletedAt',
            'ANY_VALUE(p.locationText)                         AS locationText',
            'MAX(f.createdAt)                                  AS f_createdAt',
          ])
          .where('f.ownerUserId = :uid', { uid: meId })
          .groupBy('p.id');
      }, 'favp')
      .select('*')
      .orderBy('favp.f_createdAt', 'DESC')
      .offset(offset)
      .limit(limit)
      .getRawMany();

    const items = rows.map((r: any) => ({
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
      // f_createdAt은 정렬에만 사용하므로 응답에는 포함하지 않음
    }));

    return { items, total, page, limit };
  }
}

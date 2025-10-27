import { ViewEntity, ViewColumn } from 'typeorm';

@ViewEntity({ name: 'vwUserTrustTrade' })
export class VwUserTrustTrade {
  @ViewColumn()
  userId!: string;

  @ViewColumn()
  displayName!: string;

  @ViewColumn()
  avgRating!: number;

  @ViewColumn()
  reviewCount!: number;

  @ViewColumn()
  tradeCount!: number;
}

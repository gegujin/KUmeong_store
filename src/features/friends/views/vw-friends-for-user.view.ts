import { ViewEntity, ViewColumn } from 'typeorm';

@ViewEntity({ name: 'vwFriendsForUser' })
export class VwFriendsForUser {
  @ViewColumn()
  meId!: string;

  @ViewColumn()
  friendId!: string;

  @ViewColumn()
  friendName!: string;

  @ViewColumn()
  friendEmail!: string;

  @ViewColumn()
  friendedAt!: Date;
}

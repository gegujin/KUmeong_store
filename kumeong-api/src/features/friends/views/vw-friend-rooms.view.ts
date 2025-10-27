import { ViewEntity, ViewColumn } from 'typeorm';

@ViewEntity({ name: 'vwFriendRooms' })
export class VwFriendRooms {
  @ViewColumn()
  friendRowId!: string;

  @ViewColumn()
  pairMinId!: string;

  @ViewColumn()
  pairMaxId!: string;

  @ViewColumn()
  roomId!: string;
}

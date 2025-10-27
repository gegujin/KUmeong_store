import { ViewEntity, ViewColumn } from 'typeorm';

@ViewEntity({ name: 'vwFriendRequestsForUser' })
export class VwFriendRequestsForUser {
  @ViewColumn()
  meId!: string;

  @ViewColumn()
  box!: 'incoming' | 'outgoing';

  @ViewColumn()
  requestId!: string;

  @ViewColumn()
  otherUserId!: string;

  @ViewColumn()
  otherName!: string;

  @ViewColumn()
  otherEmail!: string;

  @ViewColumn()
  requestedAt!: Date;
}

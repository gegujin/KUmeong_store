# 영어 버전

## 🧩 Domain ↔ DB ↔ API ↔ Realtime Event Mapping (EN)

* **Auth/Sign-up (s001–s004)**

  * **DB**: `users`, `email_codes` (or Redis)
  * **REST**: `POST /auth/email/send-code`, `POST /auth/email/verify`, `POST /auth/sign-up`, `POST /auth/sign-in`, `GET /auth/me`
  * **RT**: N/A

* **Search/Filter (k001–k004, c001–c004)**

  * **DB**: `products`, `product_images`, `product_tags`, `categories`
  * **REST**: `GET /products?query=&category=&tags=&minPrice=&maxPrice=&sort=`
  * **RT**: (Optional) `products:update` — broadcast inventory/price updates

* **Product Listing (u001–u004)**

  * **DB**: `products`, `product_images`, `product_tags`, `locations`
  * **REST**: `POST /products`, `POST /products/:id/images`, `PATCH /products/:id`
  * **Storage**: Presigned URL — `POST /storage/presign`
  * **RT**: `products:new`, `products:updated`

* **Trade/Chat (m001–m005 + t005)**

  * **DB**: `chat_rooms(type=TRADE_DM|FRIEND_DM, trade_id)`, `chat_room_members`, `chat_messages`, `trades`, `trade_events`
  * **REST**: `POST /chat/rooms`, `GET /chat/rooms`, `GET /chat/rooms/:id/messages`, `POST /chat/rooms/:id/messages`
  * **RT**: `message:new`, `receipt:update`, `room:typing` *(opt: `moderation:flag`)*
  * **Policy**: 24h/48h timers via CRON (or BullMQ), persisted in `trade_events`

* **Favorites (h001–h004)**

  * **DB**: `product_favorites`
  * **REST**: `POST /products/:id/favorite`, `DELETE /products/:id/favorite`, `GET /me/favorites`
  * **RT**: (Optional) `products:fav-count-updated`

* **Notifications (a001–a004)**

  * **DB**: `notifications` (optional)
  * **RT**: `notify:new {type, refId, title, body, deeplink}`
  * **Deep-links**: `/chat/:roomId`, `/trade/:id`, `/product/:id`, …

* **Reputation/Reviews (r001–r003)**

  * **DB**: `reviews` (stars/comments), `users` (response-speed cache)
  * **REST**: `POST /trades/:id/reviews`, `GET /users/:id/reviews`
  * **Aggregation**: batch/trigger to maintain avg rating & response speed

* **Escrow/Payment (p001–p005)**

  * **DB**: `payment_intents`, `trades`, `trade_events`, (settlement) `payouts`
  * **REST**: `POST /payments/intents`, `POST /trades/:id/confirm`, `POST /trades/:id/refund`
  * **CRON**: **72h auto-confirm (p004)** → write `trade_events` → settle (p005)

* **Friends/DM (f001–f004)**

  * **DB**: `friends(status=PENDING|ACCEPTED|BLOCKED)`, `friend_requests`
  * **REST**: `POST /friends/requests`, `POST /friends/requests/:id/accept`, `DELETE /friends/:id`, `GET /friends`
  * **DM room**: `POST /chat/rooms { type: FRIEND_DM, participantId }`

* **Mode & Delivery (t001–t004, d001–d004)**

  * **DB**: `delivery_requests`, `delivery`, `trade_events`
  * **REST**: `POST /delivery/requests`, `POST /delivery/:id/accept`, `PATCH /delivery/:id/status`
  * **RT**: `delivery:update {requestId, status, eta, courierLocation?}`
  * **State machine**: REQUESTED → ACCEPTED → PICKED_UP → IN_TRANSIT → DELIVERED → CONFIRMED

---

## 🔄 State Machines (EN)

**Trade**

1. `INIT → NEGOTIATING → ESCROW_HELD → BUYER_CONFIRMED → SETTLED`
2. In `NEGOTIATING`, **24h no-response ⇒ warning**, **48h ⇒ penalty** *(m004)*
3. After `ESCROW_HELD`, **auto-confirm at 72h ⇒ BUYER_CONFIRMED** *(p004)*

**Delivery**
`REQUESTED → ACCEPTED → PICKED_UP → IN_TRANSIT → DELIVERED → CONFIRMED`
(At `DELIVERED`, trigger trade confirmation/review flow *(d004)*)

---

## 📡 WebSocket Events (Draft, EN)

| Event             | Payload (example)                                                | Trigger                                        |
| ----------------- | ---------------------------------------------------------------- | ---------------------------------------------- |
| `message:new`     | `{roomId, messageId, senderId, content, contentType, createdAt}` | On chat sent                                   |
| `receipt:update`  | `{roomId, userId, lastReadMessageId}`                            | On read offset update                          |
| `room:typing`     | `{roomId, userId}`                                               | On typing                                      |
| `notify:new`      | `{type, refId, title, body, deeplink}`                           | On notification emit                           |
| `delivery:update` | `{requestId, status, eta, courierLocation?}`                     | On delivery status change                      |
| `trade:status`    | `{tradeId, prev, next, at}`                                      | On trade state transition (incl. auto-confirm) |

---

## 📋 Feature Tracking Matrix (EN)

> Progress values are tentative and should be kept up-to-date.

| Group         | Major Feature         | Detail                                  | ID   | Progress |
| ------------- | --------------------- | --------------------------------------- | ---- | -------: |
| Sign-up/Auth  | Email verification    | Request code to school email            | s001 |     100% |
|               |                       | Submit received code to server          | s002 |     100% |
|               | Account creation      | Sign up with ID/password                | s003 |     100% |
| Login         | Login                 | Use after sign-up                       | s004 |     100% |
| Search        | Keyword               | Explore products by query               | k001 |      80% |
|               |                       | Name/description keyword match          | k002 |      70% |
|               |                       | Category/tag filter                     | k003 |      80% |
|               |                       | Tap result → detail page                | k004 |      60% |
| Filter        | Category filter       | Browse by category (L/M/S)              | c001 |      70% |
|               |                       | Sub-category (e.g., tops/bottoms)       | c002 |      80% |
|               |                       | Price/sort/tag composite filter         | c003 |      30% |
|               |                       | Realtime filter updates                 | c004 |      20% |
| Listing       | Product form          | 1–10 images upload                      | u001 |      80% |
|               |                       | Title/price/description                 | u002 |      80% |
|               |                       | Multi-tag selection                     | u003 |      80% |
|               | Location              | Address/map on listing                  | u004 |      10% |
| Trade/Chat    | Trade chat            | 1:1 messaging for deals                 | m001 |      70% |
|               |                       | Price negotiation/terms                 | m002 |       0% |
|               |                       | Auto save trade history                 | m003 |       0% |
|               | Policy                | 24h warn / 48h penalty                  | m004 |       0% |
|               |                       | Inappropriate language moderation       | m005 |       0% |
| Favorites     | Wish/like             | Like product                            | h001 |      60% |
|               |                       | List in My Page                         | h002 |      50% |
|               |                       | De-dupe/unlike                          | h003 |      50% |
|               |                       | Popular by like counts                  | h004 |      20% |
| Notifications | Inbox                 | Unified notification list               | a001 |      60% |
|               |                       | Chat/trade/system notifications         | a002 |      50% |
|               |                       | Read/unread states                      | a003 |       0% |
|               |                       | Deep-link to target page                | a004 |      10% |
| Reputation    | Reviews               | View trust score/history                | r001 |      20% |
|               |                       | Rate & review after deal                | r002 |      50% |
|               |                       | Avg stars, review count, response speed | r003 |       0% |
| Escrow        | Payment               | Hold funds in escrow                    | p001 |       0% |
|               |                       | Buyer decision within 3 days            | p002 |       0% |
|               |                       | Refund before decision                  | p003 |       0% |
|               |                       | Auto-confirm if no decision             | p004 |       0% |
|               |                       | Settle to seller after confirm          | p005 |       0% |
| Friends       | Add friend            | Register other users                    | f001 |      60% |
|               |                       | Add by nickname/ID/chat                 | f002 |      60% |
|               |                       | View status/products/reputation         | f003 |      30% |
|               |                       | Block/remove                            | f004 |      50% |
| Mode          | Face-to-face/Delivery | Choose mode                             | t001 |      70% |
|               |                       | (Planned) Address & shipping            | t003 |       0% |
|               |                       | Mode-specific trade states              | t004 |      40% |
|               |                       | Chat during trade                       | t005 |      50% |
| Delivery      | Flow                  | Email/vehicle disclosure                | d001 |      60% |
|               |                       | Check/accept/reject delivery info       | d002 |      20% |
|               |                       | Realtime delivery tracking              | d003 |      40% |
|               | Complete              | Delivery done → confirm/review          | d004 |      50% |

---

## 🛠 Milestones (EN, example)

* **M1.** Stabilize search/filter *(k001–k004, c001–c004, u001–u003)*
* **M2.** Trade chat MVP *(m001, m002, m003 + read/typing)*
* **M3.** Friends/DM beta *(f001–f004, FRIEND_DM)*
* **M4.** Delivery (lite) *(d001–d003 + map/route)*
* **M5.** Reputation/Reviews *(r001–r003)*
* **M6.** Escrow basics *(p001–p005, 72h CRON)*
* **M7.** Notifications (lite) *(a001–a004 in-app/local, deep-link)*

---

## ⚙️ Environment Note (typo fix, EN)

> In `.env` example, split the JWT lines properly (no backslash).

```ini
# JWT
JWT_SECRET=change_me_in_prod
JWT_EXPIRES=7d
BCRYPT_SALT_ROUNDS=10
```

---

## 📁 Docs & Diagram Paths (EN)

* **ERD/sequence**: `docs/architecture/`
* **App screenshots**: `docs/screens/`
* Reference images directly in README where helpful.
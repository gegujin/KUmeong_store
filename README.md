# 한글 버전
## 🧩 도메인 ↔ DB ↔ API ↔ 실시간 이벤트 매핑

* **회원/인증 (s001–s004)**

  * **DB**: `users`, `email_codes`(또는 Redis)
  * **REST**: `POST /auth/email/send-code`, `POST /auth/email/verify`, `POST /auth/sign-up`, `POST /auth/sign-in`, `GET /auth/me`
  * **RT**: (해당 없음)

* **검색/필터 (k001–k004, c001–c004)**

  * **DB**: `products`, `product_images`, `product_tags`, `categories`
  * **REST**: `GET /products?query=&category=&tags=&minPrice=&maxPrice=&sort=`
  * **RT**: (선택) `products:update` — 재고/가격 변경 브로드캐스트

* **상품 등록 (u001–u004)**

  * **DB**: `products`, `product_images`, `product_tags`, `locations`
  * **REST**: `POST /products`, `POST /products/:id/images`, `PATCH /products/:id`
  * **스토리지**: Presigned URL — `POST /storage/presign`
  * **RT**: `products:new`, `products:updated`

* **거래/채팅 (m001–m005 + t005)**

  * **DB**: `chat_rooms(type=TRADE_DM|FRIEND_DM, trade_id)`, `chat_room_members`, `chat_messages`, `trades`, `trade_events`
  * **REST**: `POST /chat/rooms`, `GET /chat/rooms`, `GET /chat/rooms/:id/messages`, `POST /chat/rooms/:id/messages`
  * **RT**: `message:new`, `receipt:update`, `room:typing` *(옵션: `moderation:flag`)*
  * **정책**: 24h/48h 타이머 — CRON(or BullMQ)으로 `trade_events` 기록

* **찜 (h001–h004)**

  * **DB**: `product_favorites`
  * **REST**: `POST /products/:id/favorite`, `DELETE /products/:id/favorite`, `GET /me/favorites`
  * **RT**: (선택) `products:fav-count-updated`

* **알림 (a001–a004)**

  * **DB**: `notifications`(선택)
  * **RT**: `notify:new {type, refId, title, body, deeplink}`
  * **딥링크**: `/chat/:roomId`, `/trade/:id`, `/product/:id` 등

* **신뢰도/후기 (r001–r003)**

  * **DB**: `reviews`(별점/후기), `users`(응답속도 캐시)
  * **REST**: `POST /trades/:id/reviews`, `GET /users/:id/reviews`
  * **집계**: 배치/트리거로 평균 별점/응답속도 업데이트

* **안심결제/에스크로 (p001–p005)**

  * **DB**: `payment_intents`, `trades`, `trade_events`, (정산) `payouts`
  * **REST**: `POST /payments/intents`, `POST /trades/:id/confirm`, `POST /trades/:id/refund`
  * **CRON**: **72h 자동 확정(p004)** → `trade_events` 기록 → 정산(p005)

* **친구/DM (f001–f004)**

  * **DB**: `friends(status=PENDING|ACCEPTED|BLOCKED)`, `friend_requests`
  * **REST**: `POST /friends/requests`, `POST /friends/requests/:id/accept`, `DELETE /friends/:id`, `GET /friends`
  * **DM 방 생성**: `POST /chat/rooms {type: FRIEND_DM, participantId}`

* **거래방식/배달 (t001–t004, d001–d004)**

  * **DB**: `delivery_requests`, `delivery`, `trade_events`
  * **REST**: `POST /delivery/requests`, `POST /delivery/:id/accept`, `PATCH /delivery/:id/status`
  * **RT**: `delivery:update {requestId, status, eta, courierLocation?}`
  * **상태머신**: REQUESTED → ACCEPTED → PICKED_UP → IN_TRANSIT → DELIVERED → CONFIRMED

---

## 🔄 상태머신 요약

**Trade**

1. `INIT → NEGOTIATING → ESCROW_HELD → BUYER_CONFIRMED → SETTLED`
2. NEGOTIATING에서 **24h 미응답 ⇒ 경고**, **48h ⇒ 페널티** *(m004)*
3. ESCROW_HELD 이후 **72h 경과 ⇒ 자동 확정(BUYER_CONFIRMED)** *(p004)*

**Delivery**
`REQUESTED → ACCEPTED → PICKED_UP → IN_TRANSIT → DELIVERED → CONFIRMED`
(DELIVERED 시 거래 확정/리뷰 흐름 연동 *(d004)*)

---

## 📡 WebSocket 이벤트 (초안)

| 이벤트               | 페이로드 예시                                                          | 트리거                |
| ----------------- | ---------------------------------------------------------------- | ------------------ |
| `message:new`     | `{roomId, messageId, senderId, content, contentType, createdAt}` | 채팅 전송              |
| `receipt:update`  | `{roomId, userId, lastReadMessageId}`                            | 읽음 위치 변경           |
| `room:typing`     | `{roomId, userId}`                                               | 타이핑                |
| `notify:new`      | `{type, refId, title, body, deeplink}`                           | 알림 생성              |
| `delivery:update` | `{requestId, status, eta, courierLocation?}`                     | 배달 상태 변경           |
| `trade:status`    | `{tradeId, prev, next, at}`                                      | 거래 상태 전이(자동 확정 포함) |

---

## 📋 기능 추적 매트릭스 (Feature Status)

> 진행도는 개발 시점 기준 값입니다. 이 표로 요구사항을 추적/공유합니다.

| 기능군     | 주 기능    | 상세 기능              | ID   |  진행도 |
| ------- | ------- | ------------------ | ---- | ---: |
| 회원가입/인증 | 이메일 인증  | 학교 이메일로 인증번호 요청    | s001 | 100% |
|         |         | 서버로 전송된 인증번호 입력    | s002 | 100% |
|         | 계정 생성   | 아이디/비밀번호로 회원가입     | s003 | 100% |
| 로그인     | 로그인     | 가입 후 로그인 사용        | s004 | 100% |
| 검색      | 키워드 검색  | 검색어 입력으로 상품 탐색     | k001 |  80% |
|         |         | 이름/설명 키워드 기반 결과    | k002 |  70% |
|         |         | 카테고리/태그 필터 추가 검색   | k003 |  80% |
|         |         | 결과 클릭 시 상세 이동      | k004 |  60% |
| 필터      | 카테고리 필터 | 대/중/소 분류 탐색        | c001 |  70% |
|         |         | 하위 분류 선택(상의/하의 등)  | c002 |  80% |
|         |         | 가격/정렬/태그 복합 필터     | c003 |  30% |
|         |         | 필터 결과 실시간 반영       | c004 |  20% |
| 상품 등록   | 정보 입력   | 이미지 1–10장 업로드      | u001 |  80% |
|         |         | 제목/가격/설명 입력        | u002 |  80% |
|         |         | 다중 태그 지정           | u003 |  80% |
|         | 위치      | 지도/주소 포함 등록        | u004 |  10% |
| 거래(채팅)  | 거래 채팅   | 1:1 채팅으로 거래 진행     | m001 |  70% |
|         |         | 가격 협의/조건 조율        | m002 |   0% |
|         |         | 거래 기록 자동 저장        | m003 |   0% |
|         | 정책      | 24h 미응답 경고/48h 페널티 | m004 |   0% |
|         |         | 부적절 언어 감지 경고/차단    | m005 |   0% |
| 찜       | 관심      | 상품 찜(좋아요)          | h001 |  60% |
|         |         | 마이페이지에서 찜 목록       | h002 |  50% |
|         |         | 중복 방지/취소           | h003 |  50% |
|         |         | 찜 수로 인기 상품         | h004 |  20% |
| 알림      | 알림 목록   | 알림 통합 조회           | a001 |  60% |
|         |         | 채팅/거래/시스템 알림 수신    | a002 |  50% |
|         |         | 읽음/안읽음 구분          | a003 |   0% |
|         |         | 클릭 시 딥링크 이동        | a004 |  10% |
| 신뢰도     | 후기      | 거래 이력/신뢰도 확인       | r001 |  20% |
|         |         | 별점/후기 작성           | r002 |  50% |
|         |         | 평균별점/후기수/응답속도      | r003 |   0% |
| 안심결제    | 에스크로    | 금액 예치              | p001 |   0% |
|         |         | 3일 내 구매 결정         | p002 |   0% |
|         |         | 결정 전 환불 가능         | p003 |   0% |
|         |         | 미확정 자동 확정          | p004 |   0% |
|         |         | 확정 후 판매자 정산        | p005 |   0% |
| 친구      | 친구 추가   | 사용자 친구 등록          | f001 |  60% |
|         |         | 닉네임/ID/채팅 기반 추가    | f002 |  60% |
|         |         | 상태/상품/신뢰도 확인       | f003 |  30% |
|         |         | 차단/삭제              | f004 |  50% |
| 거래방식    | 직거래/배달  | 직거래/배달 선택          | t001 |  70% |
|         |         | (예약) 배달 주소/발송      | t003 |   0% |
|         |         | 방식별 거래 상태          | t004 |  40% |
|         |         | 채팅 중 거래 소통         | t005 |  50% |
| 배달      | 진행      | 이메일/이동수단 공개        | d001 |  60% |
|         |         | 배달 정보 확인/수락/거절     | d002 |  20% |
|         |         | 배달 상태 실시간 확인       | d003 |  40% |
|         | 완료      | 배달 완료→확정/리뷰        | d004 |  50% |

---

## 🛠 마일스톤 (예시)

* **M1.** 검색/필터 안정화 *(k001–k004, c001–c004, u001–u003)*
* **M2.** 거래 채팅 MVP *(m001, m002, m003 + 읽음/타이핑)*
* **M3.** 친구/DM 베타 *(f001–f004, FRIEND_DM)*
* **M4.** 배달 라이트 *(d001–d003 + 지도/경로)*
* **M5.** 신뢰도/후기 *(r001–r003)*
* **M6.** 에스크로 기초 *(p001–p005, 72h CRON)*
* **M7.** 알림 라이트 *(a001–a004 인앱/로컬, 딥링크)*

---

## ⚙️ 환경 변수 메모 (오탈자 수정)

> `.env` 예시에서 아래처럼 분리하세요. 역슬래시(`\`)는 필요 없습니다.

```ini
# JWT
JWT_SECRET=change_me_in_prod
JWT_EXPIRES=7d
BCRYPT_SALT_ROUNDS=10
```

---

## 📁 문서/다이어그램 경로

* **ERD/시퀀스**: `docs/architecture/`
* **화면 스크린샷**: `docs/screens/`
* README 본문에서 해당 파일을 이미지로 직접 참조해 주세요.


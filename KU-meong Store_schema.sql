-- =====================================
-- KUMEONG_STORE SCHEMA + 샘플 데이터
-- =====================================

-- 1. 데이터베이스 생성 및 선택
CREATE DATABASE IF NOT EXISTS kumeong_store
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE kumeong_store;

-- 2. 외래키 제약 비활성화 (테이블 삭제 안전하게)
SET FOREIGN_KEY_CHECKS = 0;

-- 3. 기존 테이블 삭제
DROP TABLE IF EXISTS chat_messages;
DROP TABLE IF EXISTS chat_rooms;
DROP TABLE IF EXISTS push_tokens;
DROP TABLE IF EXISTS reports;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS delivery_requests;
DROP TABLE IF EXISTS delivery;
DROP TABLE IF EXISTS payment_intents;
DROP TABLE IF EXISTS trade_events;
DROP TABLE IF EXISTS trades;
DROP TABLE IF EXISTS product_favorites;
DROP TABLE IF EXISTS product_images;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS users;

-- 4. 외래키 제약 활성화
SET FOREIGN_KEY_CHECKS = 1;

-- =====================================
-- 5. 테이블 생성
-- =====================================

-- 5-1. users
CREATE TABLE users (
    id CHAR(36) NOT NULL PRIMARY KEY,
    email VARCHAR(120) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    reputation INT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL
) ENGINE=InnoDB;

-- 5-2. products
CREATE TABLE products (
    id CHAR(36) NOT NULL PRIMARY KEY,
    seller_id CHAR(36) NOT NULL,
    title VARCHAR(100) NOT NULL,
    price_won INT NOT NULL,
    status ENUM('LISTED','RESERVED','SOLD') NOT NULL DEFAULT 'LISTED',
    description TEXT NULL,
    category VARCHAR(50) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,
    CONSTRAINT fk_products_seller FOREIGN KEY (seller_id) REFERENCES users(id)
      ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 5-3. product_images
CREATE TABLE product_images (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    product_id CHAR(36) NOT NULL,
    url VARCHAR(500) NOT NULL,
    ord INT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_product_images_product FOREIGN KEY (product_id) REFERENCES products(id)
      ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 5-4. product_favorites
CREATE TABLE product_favorites (
    user_id CHAR(36) NOT NULL,
    product_id CHAR(36) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, product_id),
    CONSTRAINT fk_fav_user FOREIGN KEY (user_id) REFERENCES users(id)
      ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_fav_product FOREIGN KEY (product_id) REFERENCES products(id)
      ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 5-5. trades
CREATE TABLE trades (
    id CHAR(36) NOT NULL PRIMARY KEY,
    product_id CHAR(36) NOT NULL,
    buyer_id CHAR(36) NOT NULL,
    seller_id CHAR(36) NOT NULL,
    amount_won INT NOT NULL,
    status ENUM('CREATED','PAID_ESCROW','CANCELED','CONFIRMED') NOT NULL DEFAULT 'CREATED',
    confirm_by DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,
    CONSTRAINT fk_trades_product FOREIGN KEY (product_id) REFERENCES products(id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_trades_buyer FOREIGN KEY (buyer_id) REFERENCES users(id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_trades_seller FOREIGN KEY (seller_id) REFERENCES users(id)
      ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 5-6. trade_events
CREATE TABLE trade_events (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    trade_id CHAR(36) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    meta_json JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_trade_events_trade FOREIGN KEY (trade_id) REFERENCES trades(id)
      ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 5-7. payment_intents
CREATE TABLE payment_intents (
    id CHAR(36) NOT NULL PRIMARY KEY,
    trade_id CHAR(36) NOT NULL,
    provider VARCHAR(40) NOT NULL,
    external_id VARCHAR(120) NOT NULL,
    amount_won INT NOT NULL,
    status ENUM('PENDING','AUTHORIZED','CANCELED','CAPTURED','FAILED') NOT NULL DEFAULT 'PENDING',
    webhook_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_payment_ext UNIQUE (provider, external_id),
    CONSTRAINT fk_payment_trade FOREIGN KEY (trade_id) REFERENCES trades(id)
      ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 5-8. delivery_requests (KU대리)
CREATE TABLE delivery_requests (
    id CHAR(36) NOT NULL PRIMARY KEY,
    requester_id CHAR(36) NOT NULL,
    rider_id CHAR(36) NULL,
    product_id CHAR(36) NULL,
    price_won INT NOT NULL DEFAULT 0,
    status ENUM('REQUESTED','ACCEPTED','STARTED','COMPLETED','CANCELED') NOT NULL DEFAULT 'REQUESTED',
    start_lat DECIMAL(10,7) NOT NULL,
    start_lng DECIMAL(10,7) NOT NULL,
    end_lat DECIMAL(10,7) NOT NULL,
    end_lng DECIMAL(10,7) NOT NULL,
    started_at DATETIME NULL,
    completed_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME NULL,
    CONSTRAINT fk_delivery_req_user FOREIGN KEY (requester_id) REFERENCES users(id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_delivery_rider FOREIGN KEY (rider_id) REFERENCES users(id)
      ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_delivery_product FOREIGN KEY (product_id) REFERENCES products(id)
      ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- 5-9. reviews
CREATE TABLE reviews (
    id CHAR(36) NOT NULL PRIMARY KEY,
    reviewer_id CHAR(36) NOT NULL,
    target_id CHAR(36) NOT NULL,
    trade_id CHAR(36) NULL,
    rating TINYINT NOT NULL,
    comment TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_reviews_reviewer FOREIGN KEY (reviewer_id) REFERENCES users(id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_reviews_target FOREIGN KEY (target_id) REFERENCES users(id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_reviews_trade FOREIGN KEY (trade_id) REFERENCES trades(id)
      ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT ck_reviews_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- 5-10. reports
CREATE TABLE reports (
    id CHAR(36) NOT NULL PRIMARY KEY,
    reporter_id CHAR(36) NOT NULL,
    target_type ENUM('USER','PRODUCT','TRADE','DELIVERY') NOT NULL,
    target_id CHAR(36) NOT NULL,
    reason VARCHAR(200) NOT NULL,
    detail TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_reports_reporter FOREIGN KEY (reporter_id) REFERENCES users(id)
      ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 5-11. push_tokens
CREATE TABLE push_tokens (
    user_id CHAR(36) NOT NULL,
    device_id VARCHAR(80) NOT NULL,
    token VARCHAR(255) NOT NULL,
    platform ENUM('android','ios','web') NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, device_id),
    CONSTRAINT fk_push_tokens_user FOREIGN KEY (user_id) REFERENCES users(id)
      ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 5-12. chat_rooms
CREATE TABLE chat_rooms (
    id CHAR(36) NOT NULL PRIMARY KEY,
    product_id CHAR(36) NULL,
    buyer_id CHAR(36) NOT NULL,
    seller_id CHAR(36) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_chat_room_product FOREIGN KEY (product_id) REFERENCES products(id)
      ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_chat_room_buyer FOREIGN KEY (buyer_id) REFERENCES users(id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_chat_room_seller FOREIGN KEY (seller_id) REFERENCES users(id)
      ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 5-13. chat_messages
CREATE TABLE chat_messages (
    id CHAR(36) NOT NULL PRIMARY KEY,
    room_id CHAR(36) NOT NULL,
    sender_id CHAR(36) NOT NULL,
    type ENUM('TEXT','FILE','SYSTEM') NOT NULL DEFAULT 'TEXT',
    content TEXT NULL,
    file_url VARCHAR(500) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_chat_msg_room FOREIGN KEY (room_id) REFERENCES chat_rooms(id)
      ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_chat_msg_sender FOREIGN KEY (sender_id) REFERENCES users(id)
      ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- =====================================
-- 6. 샘플 데이터 삽입
-- =====================================

-- 6-1. users
INSERT INTO users (id, email, name, password_hash) VALUES
('11111111-1111-1111-1111-111111111111','student@kku.ac.kr','KKU Student','$2a$10$examplehash'),
('22222222-2222-2222-2222-222222222222','rider@kku.ac.kr','Rider','$2a$10$examplehash'),
('33333333-3333-3333-3333-333333333333','buyer@kku.ac.kr','Buyer','$2a$10$examplehash');

-- 6-2. products
INSERT INTO products (id, seller_id, title, price_won, description, category) VALUES
('aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1','11111111-1111-1111-1111-111111111111','캠퍼스 패딩',30000,'상태 좋아요','의류'),
('aaaaaaa2-aaaa-aaaa-aaaa-aaaaaaaaaaa2','11111111-1111-1111-1111-111111111111','노트북',700000,'중고 노트북','전자기기');

-- 6-3. product_images
INSERT INTO product_images (product_id, url, ord) VALUES
('aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1','https://example.com/p1.jpg',0),
('aaaaaaa2-aaaa-aaaa-aaaa-aaaaaaaaaaa2','https://example.com/p2.jpg',0);

-- 6-4. product_favorites
INSERT INTO product_favorites (user_id, product_id) VALUES
('33333333-3333-3333-3333-333333333333','aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1');

-- 6-5. trades
INSERT INTO trades (id, product_id, buyer_id, seller_id, amount_won, status) VALUES
('bbbbbbb1-bbbb-bbbb-bbbb-bbbbbbbbbbb1','aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1','33333333-3333-3333-3333-333333333333','11111111-1111-1111-1111-111111111111',30000,'CREATED');

-- 6-6. delivery_requests (KU대리)
INSERT INTO delivery_requests (id, requester_id, rider_id, product_id, price_won, status, start_lat, start_lng, end_lat, end_lng) VALUES
('d1111111-d111-d111-d111-d11111111111','33333333-3333-3333-3333-333333333333','22222222-2222-2222-2222-222222222222','aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1',5000,'REQUESTED',36.3741,127.3655,36.3700,127.3600);

-- 6-7. reviews
INSERT INTO reviews (id, reviewer_id, target_id, trade_id, rating, comment) VALUES
('r1111111-r111-r111-r111-r11111111111','33333333-3333-3333-3333-333333333333','11111111-1111-1111-1111-111111111111','bbbbbbb1-bbbb-bbbb-bbbb-bbbbbbbbbbb1',5,'좋은 거래였습니다!');

-- 6-8. payment_intents
INSERT INTO payment_intents (id, trade_id, provider, external_id, amount_won, status) VALUES
('p1111111-p111-p111-p111-p11111111111','bbbbbbb1-bbbb-bbbb-bbbb-bbbbbbbbbbb1','kakao','kakaopay_001',30000,'PENDING');

-- 6-9. chat_rooms
INSERT INTO chat_rooms (id, product_id, buyer_id, seller_id) VALUES
('cr111111-cr11-cr11-cr11-cr1111111111','aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1','33333333-3333-3333-3333-333333333333','11111111-1111-1111-1111-111111111111');

-- 6-10. chat_messages
INSERT INTO chat_messages (id, room_id, sender_id, type, content) VALUES
('cm111111-cm11-cm11-cm11-cm1111111111','cr111111-cr11-cr11-cr11-cr1111111111','33333333-3333-3333-3333-333333333333','TEXT','안녕하세요! 상품 문의드립니다.');

-- 6-11. push_tokens
INSERT INTO push_tokens (user_id, device_id, token, platform) VALUES
('11111111-1111-1111-1111-111111111111','device001','token_abc','android');

-- =====================================
-- 완전 샘플 데이터 포함 끝
-- =====================================


-- 🔹 MySQL UPDATE statements --
UPDATE users SET password_hash='$2b$10$fYRqWvvzWFL.pVfcbgaj9u1UGzgdm1hp45V1lSS7D8Y2ydJJhphfK' WHERE email='student@kku.ac.kr';
UPDATE users SET password_hash='$2b$10$F1ydbYHyibklSXpQHZxeP.PbDsvtC83ao/KGSK/69qe/ch220zIOi' WHERE email='rider@kku.ac.kr';
UPDATE users SET password_hash='$2b$10$IXg9sGv7aTvarYn7Ny2IGOp6n8RkAPDqIzvWP2soLm26zl9UAIeOq' WHERE email='buyer@kku.ac.kr';

SELECT email, password_hash, CHAR_LENGTH(password_hash) AS len
FROM users
WHERE email='student@kku.ac.kr';

SELECT email, password_hash, CHAR_LENGTH(password_hash) FROM users WHERE email='student@kku.ac.kr';

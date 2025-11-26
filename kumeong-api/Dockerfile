# ========================
# 1) Build Stage
# ========================
FROM node:20-alpine AS builder

WORKDIR /usr/src/app

# 의존성 설치
COPY package*.json ./
RUN npm ci

# 소스 복사
COPY . .

# NestJS build
RUN npm run build


# ========================
# 2) Runtime Stage
# ========================
FROM node:20-alpine

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm ci --omit=dev

# dist 복사
COPY --from=builder /usr/src/app/dist ./dist

# ⛔ 너가 추가했던 templates 복사는 정상
COPY --from=builder /usr/src/app/templates ./templates

# ⭐⭐ 여기 추가가 핵심 ⭐⭐
# 업로드된 이미지 제공을 위해 uploads 폴더 포함시키기
COPY --from=builder /usr/src/app/uploads ./uploads

# 포트 노출
EXPOSE 3000

CMD ["node", "dist/main.js"]
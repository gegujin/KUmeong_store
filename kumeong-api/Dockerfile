# ========================
# 1) Build Stage
# ========================
FROM node:20-alpine AS builder

WORKDIR /app

# NestJS 빌드에 필요한 파일 먼저 복사
COPY package*.json ./
COPY tsconfig*.json ./
COPY nest-cli.json ./

# 의존성 설치
RUN npm ci

# 전체 소스 복사
COPY . .

# NestJS 빌드 (src/migrations → dist/migrations 자동 생성)
RUN npm run build


# ========================
# 2) Runtime Stage
# ========================
FROM node:20-alpine

WORKDIR /app

# 프로덕션 의존성 설치
COPY package*.json ./
RUN npm ci --omit=dev

# 빌드 결과 복사 (dist + migrations 포함)
COPY --from=builder /app/dist ./dist

# 템플릿 + 업로드 폴더 복사 (있으면)
COPY --from=builder /app/templates ./templates
COPY --from=builder /app/uploads ./uploads

# 포트 노출
EXPOSE 3000

# 실행
CMD ["node", "dist/main.js"]

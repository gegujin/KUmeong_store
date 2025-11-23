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

# 런타임 의존성만 설치
COPY package*.json ./
RUN npm ci --omit=dev

# 빌드 결과물 복사
COPY --from=builder /usr/src/app/dist ./dist

# 포트 문서용
EXPOSE 3000

# ENV 설정 제거 (K8s에서 주입)
# ENV NODE_ENV=production  <-- 제거
# ENV PORT=3000            <-- 제거

CMD ["node", "dist/main.js"]

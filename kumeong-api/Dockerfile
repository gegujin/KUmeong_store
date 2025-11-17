# ========================
# 1) 빌드 스테이지
# ========================
FROM node:20-alpine AS builder

# 작업 디렉토리
WORKDIR /usr/src/app

# package.json / package-lock.json만 먼저 복사 → 설치 캐시 활용
COPY package*.json ./

# 의존성 설치 (개발 의존성 포함 - 빌드용)
RUN npm ci

# 나머지 소스 코드 복사
COPY . .

# NestJS 빌드 (dist/ 생성)
RUN npm run build

# ========================
# 2) 런타임 스테이지
# ========================
FROM node:20-alpine

WORKDIR /usr/src/app

# 런타임에 필요한 의존성만 설치 (dev 제외)
COPY package*.json ./
RUN npm ci --omit=dev

# 빌드 산출물만 복사
COPY --from=builder /usr/src/app/dist ./dist

# 기본 환경 변수 (필요 시 override 가능)
ENV NODE_ENV=production
ENV PORT=3000

# 컨테이너 포트 노출 (문서용)
EXPOSE 3000

# NestJS 앱 실행
CMD ["node", "dist/main.js"]

# ===============================
# 1) Flutter Web 빌드 스테이지
# ===============================
FROM ghcr.io/cirruslabs/flutter:3.35.6 AS build

WORKDIR /app

RUN git config --global --add safe.directory /usr/local/flutter

# API_ORIGIN을 docker build 시 전달받음
ARG API_ORIGIN
ENV API_ORIGIN=${API_ORIGIN}

# ---- 의존성 설치 ----
COPY pubspec.yaml ./pubspec.yaml
COPY pubspec.lock ./pubspec.lock
RUN flutter pub get

# ---- Flutter 소스 복사 ----
COPY lib ./lib
COPY web ./web

# ---- assets (없어도 에러 안 나도록 존재 시만 복사) ----
COPY assets ./assets

# ---- Flutter Web 빌드 ----
RUN flutter config --enable-web \
  && flutter build web --release \
     --dart-define=API_ORIGIN=${API_ORIGIN}

# ===============================
# 2) Nginx 정적 웹 배포 스테이지
# ===============================
FROM nginx:1.27-alpine

# Flutter Web 빌드 결과 복사
COPY --from=build /app/build/web /usr/share/nginx/html

# Nginx 설정 복사 (SPA 라우팅 위해 필수)
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

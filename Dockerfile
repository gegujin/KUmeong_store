# ===============================
# 1) Flutter Web 빌드 스테이지
# ===============================
FROM ghcr.io/cirruslabs/flutter:3.35.6 AS build

WORKDIR /app

RUN git config --global --add safe.directory /usr/local/flutter

ARG API_ORIGIN
ENV API_ORIGIN=${API_ORIGIN}

# ---- 의존성 설치 ----
COPY pubspec.yaml ./
COPY pubspec.lock ./
RUN flutter pub get

# ---- Flutter 소스만 복사 ----
COPY lib/ ./lib/
COPY web/ ./web/

# 🔥 assets 폴더가 실제로 있다면 아래 COPY가 성공함
# 없다면 프로젝트 루트에 빈 assets 폴더 만들어주면 됨
COPY assets/ ./assets/

# ---- Flutter 웹 빌드 ----
RUN flutter config --enable-web \
  && flutter build web --release \
      --dart-define=API_ORIGIN=${API_ORIGIN}

# ===============================
# 2) Nginx 정적 웹 배포
# ===============================
FROM nginx:1.27-alpine

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

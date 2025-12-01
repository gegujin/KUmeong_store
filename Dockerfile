# ===============================
# 1) Flutter Web 빌드 스테이지
# ===============================
FROM ghcr.io/cirruslabs/flutter:3.35.6 AS build

WORKDIR /app

RUN git config --global --add safe.directory /usr/local/flutter

# ---- 의존성 설치 ----
COPY pubspec.yaml ./pubspec.yaml
COPY pubspec.lock ./pubspec.lock
RUN flutter pub get

# ---- 소스 복사 ----
COPY lib ./lib
COPY web ./web
COPY assets ./assets

# ---- ENV 변수 주입 ----
ARG API_BASE_URL

# ---- Flutter Web 빌드 ----
RUN flutter config --enable-web \
  && flutter build web --release \
     --dart-define=API_BASE_URL=${API_BASE_URL}

# ===============================
# 2) Nginx 스테이지
# ===============================
FROM nginx:1.27-alpine

COPY --from=build /app/build/web /usr/share/nginx/html

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

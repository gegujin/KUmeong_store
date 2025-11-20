# ===============================
# 1) Flutter Web 빌드 스테이지 (공식 Flutter 이미지)
# ===============================
FROM ghcr.io/cirruslabs/flutter:3.35.6 AS build

WORKDIR /app

RUN git config --global --add safe.directory /usr/local/flutter

# API_ORIGIN은 빌드 시 인자로 전달
ARG API_ORIGIN
ENV API_ORIGIN=${API_ORIGIN}

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

RUN flutter config --enable-web \
  && flutter build web --release \
      --no-wasm-dry-run \
      --dart-define=API_ORIGIN=${API_ORIGIN}


# ===============================
# 2) Nginx 정적 웹 배포
# ===============================
FROM nginx:1.27-alpine

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

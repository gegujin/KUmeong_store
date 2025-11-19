# ===============================
# 1) Flutter Web 빌드 스테이지 (공식 Flutter 이미지)
# ===============================
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# git safe.directory 설정
RUN git config --global --add safe.directory /sdks/flutter \
    && git config --global --add safe.directory /app

# 웹 빌드에 필요한 dependencies 설치
RUN apt-get update && apt-get install -y \
    chromium \
    clang \
    libgtk-3-dev \
    liblzma-dev \
    xz-utils \
    && apt-get clean

# API_ORIGIN 전달 가능하도록 build arg 추가
ARG API_ORIGIN
ENV API_ORIGIN=$API_ORIGIN

# pubspec 의존성 설치
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# 전체 프로젝트 복사
COPY . .

# Flutter Web 빌드
RUN flutter config --enable-web \
  && flutter build web --release \
      --no-wasm-dry-run \
      --dart-define=API_ORIGIN=$API_ORIGIN

# ===============================
# 2) Nginx 정적 웹 배포
# ===============================
FROM nginx:1.27-alpine

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

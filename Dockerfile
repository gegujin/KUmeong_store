# ===============================
# 1) Flutter Web 빌드 스테이지
# ===============================
# 네 로컬 버전에 맞춰서 Flutter 3.35.6 사용
FROM ghcr.io/cirruslabs/flutter:3.35.6 AS build

# (이미 flutter/dart/git 등이 들어있는 이미지라고 가정)
WORKDIR /app

# git dubious ownership 방지 (이미지 내부 flutter 디렉터리 기준)
RUN git config --global --add safe.directory /usr/local/flutter

# ──────────────────────────────
# 1단계: pubspec.*만 먼저 복사 + 의존성 설치
#   → pubspec 안 바뀌면 이 레이어 캐시 재사용됨
# ──────────────────────────────
COPY pubspec.yaml pubspec.lock ./ 
# pubspec_overrides.yaml 쓰면 아래처럼 같이 복사
# COPY pubspec.yaml pubspec.lock pubspec_overrides.yaml ./

RUN flutter pub get

# ──────────────────────────────
# 2단계: 나머지 소스 전체 복사
#   .dockerignore로 쓰레기(빌드 결과, .git 등)는 빼줌
# ──────────────────────────────
COPY . .

# 웹 활성화 + 릴리즈 빌드
RUN flutter config --enable-web \
  && flutter build web --release --no-wasm-dry-run

# ===============================
# 2) Nginx로 정적 파일 서빙
# ===============================
FROM nginx:1.27-alpine

# Flutter 빌드 결과물을 nginx 기본 html 디렉터리로 복사
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

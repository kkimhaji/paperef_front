# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Flutter 의존성 캐싱
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# 애플리케이션 코드 복사 및 빌드
COPY . .
RUN flutter build web --release

# Stage 2: Nginx로 서빙
FROM nginx:alpine

# Flutter 빌드 결과물 복사
COPY --from=build /app/build/web /usr/share/nginx/html

# Nginx 설정 복사 (선택사항)
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Flutter 의존성 캐싱
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# 애플리케이션 코드 복사
COPY . .

# Web 플랫폼 확인 및 필요시 활성화
RUN if [ ! -d "web" ]; then \
        echo "⚠️  Web platform not found, creating..." && \
        flutter create . --platforms web; \
    else \
        echo "✓ Web platform found"; \
    fi

# Flutter Web 빌드 (--web-renderer 옵션 제거)
RUN flutter build web --release

# 빌드 결과 확인
RUN ls -la build/web/ && \
    echo "✓ Build completed successfully"

# Stage 2: Nginx로 서빙
FROM nginx:alpine

# Flutter 빌드 결과물 복사
COPY --from=build /app/build/web /usr/share/nginx/html

# Nginx 설정 복사
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 권한 설정
RUN chmod -R 755 /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

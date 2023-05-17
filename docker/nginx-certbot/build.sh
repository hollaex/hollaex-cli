docker manifest create bitholla/nginx-with-certbot:1.24.0 bitholla/nginx-with-certbot:1.24.0-amd64 bitholla/nginx-with-certbot:1.24.0-arm64v8 --amend
docker manifest annotate bitholla/nginx-with-certbot:1.24.0 bitholla/nginx-with-certbot:1.24.0-amd64 --arch amd64
docker manifest annotate bitholla/nginx-with-certbot:1.24.0 bitholla/nginx-with-certbot:1.24.0-arm64v8 --arch arm64
docker manifest push bitholla/nginx-with-certbot:1.24.0
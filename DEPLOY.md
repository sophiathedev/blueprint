# DEPLOY production cho dự án `blueprint`

Repo hiện đã được chỉnh sẵn để đi theo hướng production này:

- Rails web chạy bằng Docker image production
- Sidekiq là worker chính cho Active Job ở production
- Active Storage có thể dùng MinIO qua biến môi trường
- HTTPS đi qua Caddy
- Postgres, Redis, MinIO chạy bằng container riêng

Mục tiêu là để bạn chỉ cần chuẩn bị secret, build image, copy 3 file mẫu trong `deploy/` lên server rồi chạy.

## 1. Những gì repo đã config sẵn

### 1.1 Rails production

[`config/environments/production.rb`](./config/environments/production.rb) hiện đã đọc từ ENV:

- `ACTIVE_STORAGE_SERVICE` để chọn `minio` hoặc `local`
- `ACTIVE_JOB_QUEUE_ADAPTER` với mặc định là `sidekiq`
- `APP_DOMAIN` và `APP_PROTOCOL` để sinh URL đúng domain thật
- `RAILS_ASSUME_SSL` và `RAILS_FORCE_SSL` để chạy an toàn phía sau Caddy

### 1.2 Database production

[`config/database.yml`](./config/database.yml) hiện dùng:

- `POSTGRES_HOST`
- `POSTGRES_PORT`
- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`

App vẫn giữ `solid_cache` và `solid_cable`, và vẫn có sẵn tên database cho `solid_queue` nếu sau này bạn bật lại adapter đó. Nếu không khai báo riêng, Rails sẽ tự dùng:

- `${POSTGRES_DB}_cache`
- `${POSTGRES_DB}_queue`
- `${POSTGRES_DB}_cable`

Với cách deploy bằng container Postgres trong tài liệu này, `rails db:prepare` sẽ tạo chúng giúp bạn.

### 1.3 Sidekiq

[`config/sidekiq.rb`](./config/sidekiq.rb) hiện đã cấu hình Redis cho cả:

- Sidekiq client
- Sidekiq server

[`config/routes.rb`](./config/routes.rb) chỉ mount `/sidekiq` ở production khi bạn có đủ:

- `SIDEKIQ_USERNAME`
- `SIDEKIQ_PASSWORD`

Nếu thiếu 2 biến này thì `/sidekiq` sẽ không được mount, tránh lộ dashboard ra ngoài.

## 2. File mẫu đã có sẵn trong repo

Bạn không cần tự viết lại từ đầu nữa. Repo đã có:

- [`deploy/.env.production.example`](./deploy/.env.production.example)
- [`deploy/compose.prod.yml`](./deploy/compose.prod.yml)
- [`deploy/Caddyfile`](./deploy/Caddyfile)

Trên server, mình khuyên copy chúng thành:

```bash
mkdir -p /opt/blueprint
cp deploy/.env.production.example /opt/blueprint/.env.production
cp deploy/compose.prod.yml /opt/blueprint/compose.prod.yml
cp deploy/Caddyfile /opt/blueprint/Caddyfile
```

## 3. Những giá trị bạn cần chuẩn bị

Đây là phần bạn vẫn phải tự điền trước khi deploy.

### 3.1 Domain và image

Bạn cần:

- `APP_DOMAIN`: domain thật, ví dụ `blueprint.example.com`
- `APP_IMAGE`: image đã build và push lên registry, ví dụ `ghcr.io/your-account/blueprint:2026-03-23-01`

### 3.2 Rails secrets

Bạn cần:

- `RAILS_MASTER_KEY`
- `SECRET_KEY_BASE`

Lưu ý rất quan trọng:

- `RAILS_MASTER_KEY` phải là đúng nội dung file `config/master.key` trên máy local của bạn
- key này thường là chuỗi hex dài `32` ký tự
- không tự generate bừa một chuỗi khác cho `RAILS_MASTER_KEY`
- `RAILS_MASTER_KEY` và `SECRET_KEY_BASE` là 2 giá trị khác nhau

Tạo `SECRET_KEY_BASE` bằng:

```bash
openssl rand -hex 64
```

Nếu lúc chạy `rails db:prepare` bạn gặp lỗi:

```text
ArgumentError: key must be 16 bytes
```

thì gần như chắc chắn `RAILS_MASTER_KEY` đang sai hoặc không đúng file `config/credentials.yml.enc`.

### 3.3 Postgres

Bạn cần điền:

- `POSTGRES_DB`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`

Mặc định file mẫu đang dùng:

- database: `blueprint_production`
- user: `blueprint`

### 3.4 Redis

Thông thường không cần sửa nếu chạy cùng docker network:

```env
REDIS_URL=redis://redis:6379/1
```

### 3.5 MinIO / Active Storage

Bạn cần điền:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_BUCKET`
- `AWS_ENDPOINT`
- `MINIO_ROOT_USER`
- `MINIO_ROOT_PASSWORD`

Nếu dùng MinIO container trong file mẫu thì có thể để:

```env
AWS_ENDPOINT=http://minio:9000
AWS_FORCE_PATH_STYLE=true
ACTIVE_STORAGE_SERVICE=minio
```

### 3.6 Sidekiq dashboard

Bạn cần điền:

- `SIDEKIQ_USERNAME`
- `SIDEKIQ_PASSWORD`

## 4. Server khuyến nghị

- Ubuntu 24.04 LTS hoặc 22.04 LTS
- tối thiểu 2 vCPU, 4 GB RAM, 60 GB SSD
- mở cổng `22`, `80`, `443`
- không public trực tiếp `5432`, `6379`, `9000`, `9001`

## 5. Cài Docker trên server

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
docker --version
docker compose version
```

## 6. Chuẩn bị thư mục deploy

```bash
sudo mkdir -p /opt/blueprint
sudo chown -R $USER:$USER /opt/blueprint
cd /opt/blueprint
```

Copy file mẫu từ repo rồi sửa `.env.production`:

```bash
cp /path/to/repo/deploy/.env.production.example .env.production
cp /path/to/repo/deploy/compose.prod.yml compose.prod.yml
cp /path/to/repo/deploy/Caddyfile Caddyfile
```

Sau đó mở `.env.production` và thay toàn bộ giá trị placeholder.

## 7. Build và push image ứng dụng

Từ máy local hoặc CI:

```bash
docker login ghcr.io
docker build -t ghcr.io/your-account/blueprint:2026-03-23-01 .
docker push ghcr.io/your-account/blueprint:2026-03-23-01
```

Rồi cập nhật:

```env
APP_IMAGE=ghcr.io/your-account/blueprint:2026-03-23-01
```

## 8. Deploy lần đầu

Khởi động hạ tầng:

```bash
cd /opt/blueprint
docker compose --env-file .env.production -f compose.prod.yml pull
docker compose --env-file .env.production -f compose.prod.yml up -d postgres redis minio
```

Tạo bucket MinIO một lần:

```bash
docker compose --env-file .env.production -f compose.prod.yml --profile setup run --rm minio-setup
```

Nếu lệnh trên in ra help của `mc` thay vì tạo bucket, hãy đảm bảo bạn đang dùng bản mới của [`deploy/compose.prod.yml`](/Users/thangnguyen/Desktop/ruby/blueprint/deploy/compose.prod.yml), vì service `minio-setup` đã được chỉnh để chạy qua shell rõ ràng hơn.

Chạy prepare database:

```bash
docker compose --env-file .env.production -f compose.prod.yml run --rm web bundle exec rails db:prepare
```

Khởi động app:

```bash
docker compose --env-file .env.production -f compose.prod.yml up -d web sidekiq caddy
```

## 9. Kiểm tra sau deploy

Kiểm tra các điểm sau:

- `https://your-domain/up`
- đăng nhập được ứng dụng
- upload file hoạt động
- mở được `https://your-domain/sidekiq`
- job Sidekiq chạy được

Xem log:

```bash
docker compose --env-file .env.production -f compose.prod.yml logs -f web
docker compose --env-file .env.production -f compose.prod.yml logs -f sidekiq
```

## 10. Deploy bản mới

Build image mới:

```bash
docker build -t ghcr.io/your-account/blueprint:2026-03-30-01 .
docker push ghcr.io/your-account/blueprint:2026-03-30-01
```

Đổi `APP_IMAGE` trong `.env.production`, rồi chạy:

```bash
cd /opt/blueprint
docker compose --env-file .env.production -f compose.prod.yml pull web sidekiq
docker compose --env-file .env.production -f compose.prod.yml run --rm web bundle exec rails db:prepare
docker compose --env-file .env.production -f compose.prod.yml up -d web sidekiq
```

## 11. Rollback

Sửa `APP_IMAGE` về tag cũ rồi chạy:

```bash
cd /opt/blueprint
docker compose --env-file .env.production -f compose.prod.yml pull web sidekiq
docker compose --env-file .env.production -f compose.prod.yml up -d web sidekiq
```

Nếu release có migration không tương thích ngược, hãy backup database trước khi deploy.

## 12. Backup cơ bản

Backup Postgres:

```bash
mkdir -p /opt/blueprint/backups
cd /opt/blueprint
docker compose --env-file .env.production -f compose.prod.yml exec -T postgres \
  pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" \
  > backups/blueprint_production_$(date +%F_%H-%M-%S).sql
```

Restore Postgres:

```bash
cd /opt/blueprint
cat backups/your_backup.sql | docker compose --env-file .env.production -f compose.prod.yml exec -T postgres \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
```

Backup MinIO:

- backup volume `minio_data`
- hoặc dùng `mc mirror` sang một bucket khác

## 13. Checklist ngắn gọn

Checklist thực tế trước khi bấm deploy:

- build và push image app
- điền đủ mọi placeholder trong `.env.production`
- đảm bảo domain đã trỏ đúng IP server
- mở cổng `80` và `443`
- `up -d postgres redis minio`
- chạy `minio-setup`
- chạy `rails db:prepare`
- `up -d web sidekiq caddy`
- test `/up`, login, upload file, `/sidekiq`

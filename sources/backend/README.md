# 远程会议系统后端

## 本地启动 PostgreSQL

```bash
cd ../../deploy
docker compose --env-file .env up -d postgres
```

## 本地启动 Spring Boot

```bash
cd ../sources/backend
set -a
source ../../deploy/.env
set +a

SPRING_DATASOURCE_URL="jdbc:postgresql://localhost:5432/${POSTGRES_DB}" \
SPRING_DATASOURCE_USERNAME="${POSTGRES_USER}" \
SPRING_DATASOURCE_PASSWORD="${POSTGRES_PASSWORD}" \
mvn spring-boot:run
```

Docker 一键部署首次启动时，如果管理员账号不存在，系统会按 `docker/.env` 自动创建管理员：

```text
账号：ADMIN_ACCOUNT
密码：ADMIN_PASSWORD（安装脚本随机生成）
```

新增普通用户后的默认密码：

```text
Aa123456
```

设置 `DEMO_DATA_ENABLED=true` 后，如果 `meetings` 表为空，系统会写入少量会议和录制样例数据，方便管理后台页面联调。默认关闭。

## 认证与权限

登录接口会签发 JWT：

```text
POST /api/auth/login
```

后台管理接口需要携带：

```text
Authorization: Bearer <accessToken>
```

`/api/admin/**` 当前只允许 `ADMIN` 角色访问。JWT 密钥来自 `deploy/.env` 中的 `JWT_SECRET`。

修改当前登录用户密码：

```text
POST /api/auth/change-password
```

## 后台管理接口进度

已接入 PostgreSQL 的后台服务：

```text
GET    /api/admin/users
POST   /api/admin/users
PATCH  /api/admin/users/{id}/nickname
PATCH  /api/admin/users/{id}/status
POST   /api/admin/users/{id}/reset-password

GET    /api/admin/meetings/online
GET    /api/admin/meetings/history

GET    /api/admin/recordings
DELETE /api/admin/recordings/{id}

GET    /api/admin/system/overview
GET    /api/admin/operation-logs
```

`/api/admin/system/overview` 会返回当前会议数、在线人数、录制任务数、存储空间、CPU/内存/磁盘使用率和服务状态。

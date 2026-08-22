# 远程会议系统

一个由 Spring Boot 后端、Vue 管理后台、macOS 客户端、PostgreSQL、Redis 和 LiveKit 组成的远程会议系统。

## 快速部署

```bash
./docker/install.sh
```

完整说明见 [`docker/README.md`](docker/README.md)。客户端接口约定见 [`docs/client-api.md`](docs/client-api.md)。

## 建议提交到 GitHub 的内容

- `docker/`：一键部署文件（不要提交自动生成的 `docker/.env`）
- `docs/`：接口和项目文档
- `sources/admin-web/`：Vue 管理后台源码
- `sources/backend/`：Spring Boot 后端源码
- `sources/macos-client/`：macOS 客户端源码
- `sql/`：数据库初始化脚本
- 根目录的 `.gitignore`、`.gitattributes`、`README.md`，以及你选定的 `LICENSE`

不要提交旧版 `deploy/`、`scripts/`，以及 `.env`、`.runtime/`、`.aoci/`、`.codex/`、`node_modules/`、`target/`、`.build/`、`dist/`、DMG/App 构建产物、日志或 `.DS_Store`。根目录 `.gitignore` 已覆盖这些内容。

## 发布前检查

项目当前尚未包含开源许可证。正式公开前请选定并添加 `LICENSE`（例如 MIT、Apache-2.0 或 GPL-3.0），同时确认名称、Logo、字体、图片及第三方素材拥有可再分发权限。

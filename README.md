# MeetHarbor

> 开源、可自托管的远程会议系统。

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Java](https://img.shields.io/badge/Java-21-orange.svg)
![macOS](https://img.shields.io/badge/macOS-14%2B-black.svg)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED.svg)

MeetHarbor 提供 macOS 原生会议客户端、Web 管理后台和完整的服务端部署方案。音视频能力基于 LiveKit，业务后端使用 Spring Boot，所有服务可通过 Docker Compose 一键启动。

项目目前处于早期开发阶段，适合本地体验、局域网部署、学习和二次开发。

## 功能

### macOS 客户端

- 用户登录、退出及凭据安全存储
- 创建即时会议和预约会议
- 通过会议号加入、离开及断线重连
- LiveKit 实时音频通话
- 麦克风静音状态同步
- macOS 主屏幕共享
- 参会人、会议历史和录制记录查看
- WebSocket 会议状态信令

### Web 管理后台

- 用户创建、启停、昵称修改及密码重置
- 在线会议和历史会议管理
- 录制记录管理
- 操作日志查询
- 服务状态及主机资源概览

### 服务端

- JWT 登录认证与管理员权限控制
- 会议、成员和会话生命周期管理
- LiveKit 房间创建、删除、令牌签发及 Webhook 接收
- PostgreSQL 持久化和 Redis 状态存储
- Docker 健康检查、数据卷和随机密钥初始化

## 系统架构

```mermaid
flowchart LR
    Client[macOS 客户端] -->|HTTP / WebSocket| Backend[Spring Boot 后端]
    Admin[Web 管理后台] -->|HTTP| Backend
    Client -->|WebRTC| LiveKit[LiveKit]
    Backend --> LiveKit
    Backend --> PostgreSQL[(PostgreSQL)]
    Backend --> Redis[(Redis)]
    LiveKit --> Redis
```

| 组件 | 技术 |
| --- | --- |
| macOS 客户端 | Swift 6、SwiftUI、LiveKit Swift SDK |
| 管理后台 | Vue 3、TypeScript、Vite、Element Plus |
| 业务后端 | Java 21、Spring Boot 3、Spring Security、JPA |
| 实时音视频 | LiveKit |
| 数据服务 | PostgreSQL 16、Redis 7 |
| 部署 | Docker Compose |

## 快速开始

### 环境要求

- Linux 或 macOS
- Docker Engine 24+ 或 Docker Desktop
- Docker Compose 插件

### 一键启动全部服务

```bash
git clone https://github.com/indeedworks/meet-harbor.git
cd meet-harbor
./docker/install.sh
```

安装脚本会自动检测本机局域网地址、生成服务密钥和初始管理员密码，并启动 PostgreSQL、Redis、LiveKit、后端及管理后台。

启动完成后访问：

| 服务 | 默认地址 |
| --- | --- |
| Web 管理后台 | <http://localhost:8088> |
| 后端 API | <http://localhost:8080> |
| LiveKit | `ws://localhost:7880` |

管理员账号和随机生成的密码保存在 `docker/.env`：

```bash
grep -E '^ADMIN_(ACCOUNT|PASSWORD)=' docker/.env
```

如需让局域网内其他设备访问，可在首次启动时指定宿主机地址：

```bash
PUBLIC_HOST=192.168.1.10 ./docker/install.sh
```

完整的配置、升级、日志和数据清理说明见 [Docker 部署文档](docker/README.md)。

## 运行 macOS 客户端

客户端要求 macOS 14+ 和 Swift 6。请先启动服务端，然后执行：

```bash
cd sources/macos-client
swift run
```

首次使用麦克风或屏幕共享时，macOS 会请求相应的系统权限。客户端默认连接 `http://localhost:8080`。

更多说明见 [macOS 客户端文档](sources/macos-client/README.md)。

## 常用运维命令

```bash
# 查看服务状态
docker compose --env-file docker/.env -f docker/compose.yml ps

# 查看实时日志
docker compose --env-file docker/.env -f docker/compose.yml logs -f

# 停止服务
docker compose --env-file docker/.env -f docker/compose.yml down

# 更新源码后重新构建
docker compose --env-file docker/.env -f docker/compose.yml up -d --build
```

## 端口

| 端口 | 协议 | 用途 |
| --- | --- | --- |
| 8088 | TCP | Web 管理后台 |
| 8080 | TCP | 后端 API 与 WebSocket |
| 7880 | TCP | LiveKit 信令 |
| 7881 | TCP | LiveKit RTC over TCP |
| 50000–50100 | UDP | LiveKit WebRTC 媒体传输 |

PostgreSQL 和 Redis 默认只在 Docker 内部网络开放。所有端口均可在 `docker/.env` 中修改。

## 项目结构

```text
meet-harbor/
├── docker/                  # 一键部署脚本和 Compose 配置
├── docs/                    # 客户端 API 文档
├── sources/
│   ├── admin-web/           # Vue 管理后台
│   ├── backend/             # Spring Boot 后端
│   └── macos-client/        # SwiftUI macOS 客户端
└── sql/postgresql/          # PostgreSQL 初始化脚本
```

## 开发文档

- [Docker 部署](docker/README.md)
- [客户端 API](docs/client-api.md)
- [后端开发说明](sources/backend/README.md)
- [macOS 客户端说明](sources/macos-client/README.md)

## 当前限制

- 当前只提供 macOS 原生会议客户端，尚无浏览器、Windows、Linux、iOS 或 Android 客户端。
- 录制模块目前以记录管理为主，尚未集成 LiveKit Egress 录制和文件下载流程。
- Docker 默认配置面向单机和局域网；公网部署还需要域名、TLS/WSS、防火墙和 TURN 配置。
- JWT 暂无刷新令牌接口，访问令牌过期后需要重新登录。

## 参与贡献

欢迎提交 Issue 和 Pull Request。提交代码前，请确保没有包含 `docker/.env`、本地密钥、构建产物或日志文件。

## 许可证

本项目采用 [MIT License](LICENSE)。

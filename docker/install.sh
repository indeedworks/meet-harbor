#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

if ! command -v docker >/dev/null 2>&1; then
  echo "错误：未找到 Docker，请先安装 Docker Desktop 或 Docker Engine。" >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "错误：当前 Docker 未安装 Compose 插件。" >&2
  exit 1
fi

random_hex() {
  bytes=$1
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$bytes"
  else
    od -An -N "$bytes" -tx1 /dev/urandom | tr -d ' \n'
  fi
}

detect_host() {
  if [ -n "${PUBLIC_HOST:-}" ]; then
    printf '%s' "$PUBLIC_HOST"
    return
  fi
  if command -v ipconfig >/dev/null 2>&1; then
    ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || printf '127.0.0.1'
    return
  fi
  if command -v hostname >/dev/null 2>&1; then
    detected=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -n "$detected" ]; then
      printf '%s' "$detected"
      return
    fi
  fi
  printf '127.0.0.1'
}

if [ ! -f .env ]; then
  umask 077
  public_host=$(detect_host)
  postgres_password=$(random_hex 24)
  redis_password=$(random_hex 24)
  livekit_key="lk_$(random_hex 8)"
  livekit_secret=$(random_hex 32)
  jwt_secret=$(random_hex 32)
  admin_password=$(random_hex 12)

  sed \
    -e "s|^PUBLIC_HOST=.*|PUBLIC_HOST=$public_host|" \
    -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$postgres_password|" \
    -e "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=$redis_password|" \
    -e "s|^LIVEKIT_API_KEY=.*|LIVEKIT_API_KEY=$livekit_key|" \
    -e "s|^LIVEKIT_API_SECRET=.*|LIVEKIT_API_SECRET=$livekit_secret|" \
    -e "s|^JWT_SECRET=.*|JWT_SECRET=$jwt_secret|" \
    -e "s|^ADMIN_PASSWORD=.*|ADMIN_PASSWORD=$admin_password|" \
    .env.example > .env
  chmod 600 .env
  echo "已生成 docker/.env（权限 600）。"
else
  echo "复用已有 docker/.env。"
fi

docker compose --env-file .env config >/dev/null
docker compose --env-file .env up -d --build --remove-orphans --wait --wait-timeout 180

admin_port=$(sed -n 's/^ADMIN_WEB_PORT=//p' .env)
backend_port=$(sed -n 's/^BACKEND_PORT=//p' .env)
public_host=$(sed -n 's/^PUBLIC_HOST=//p' .env)
admin_account=$(sed -n 's/^ADMIN_ACCOUNT=//p' .env)
admin_password=$(sed -n 's/^ADMIN_PASSWORD=//p' .env)

echo
echo "部署命令已完成。容器首次构建可能还需要几十秒才能全部就绪。"
echo "管理后台: http://$public_host:$admin_port"
echo "后端 API: http://$public_host:$backend_port"
echo "管理员账号: $admin_account"
echo "管理员初始密码: $admin_password"
echo "请登录后立即修改管理员密码。"
echo
docker compose --env-file .env ps

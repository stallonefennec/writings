#!/bin/bash

# 设置变量
REPO_URL="git@github.com:stallonefennec/memos_backup.git"
LOCAL_PATH="$HOME/.memos"
LOG_FILE="$HOME/memos_update.log"
CONTAINER_NAME="memos" # docker 容器名称
DOCKER_COMPOSE_FILE="docker-compose.yml" # docker-compose 文件路径

# 定义日志函数
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 获取当前日期和时间
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

log "Starting memos update..."

# 检查 Docker 是否正在运行 Memos 容器
if docker ps | grep -q "$CONTAINER_NAME"; then
  log "Memos 容器正在运行，正在停止..."
  # 判断是否是通过 docker-compose 启动的
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
         docker-compose down
       if [[ $? -ne 0 ]]; then
        log "停止 docker-compose 项目失败，请检查 Docker 日志。"
        exit 1
      fi
    else
      docker stop "$CONTAINER_NAME"
      if [[ $? -ne 0 ]]; then
       log "停止容器 $CONTAINER_NAME 失败，请检查 Docker 日志。"
        exit 1
      fi
    fi
    log "Memos 容器已停止."
else
  log "Memos 容器未运行."
fi

# 检查本地目录是否存在,如果存在,先删除该目录
if [ -d "$LOCAL_PATH" ]; then
  log "发现旧的本地数据目录,删除旧的目录: $LOCAL_PATH"
    rm -rf "$LOCAL_PATH"
  if [[ $? -ne 0 ]]; then
    log "删除旧的本地数据目录 $LOCAL_PATH 失败."
    exit 1;
  fi
  log "旧的本地数据目录已删除: $LOCAL_PATH"
fi


# 创建本地目录
log "创建目录: $LOCAL_PATH"
mkdir -p "$LOCAL_PATH" || {
    log "Error: Failed to create directory $LOCAL_PATH"
    exit 1
}

# 进入本地目录
cd "$LOCAL_PATH" || {
  log "Error: Could not change directory to $LOCAL_PATH"
  exit 1
}

# 检查本地仓库是否存在
if [ ! -d ".git" ]; then
  log "Cloning repository..."
  git clone "$REPO_URL" .  # 克隆仓库到当前目录
elif ! git remote -v | grep -q "$REPO_URL"; then # 检查remote origin 是否是 $REPO_URL
    log "Error: Not expected remote repo, exit"
    exit 1
else
    log "Pulling latest changes..."
    git pull origin main # 拉取最新更改
fi


# 检查更新结果
if [ $? -eq 0 ]; then
  log "Update successful!"
else
  log "Error: Update failed!"
  exit 1
fi

log "Update process finished."
docker-compose -f /home/freeluckboy/docker-compose.yml up -d
systemctl restart nginx
log "nginx 已刷新"
exit 0
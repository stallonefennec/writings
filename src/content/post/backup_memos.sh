#!/bin/bash

# 设置变量
REPO_PATH="$HOME/.memos"  # 本地 Git 仓库路径
REMOTE_REPO="git@github.com:stallonefennec/memos_db.git" # 远程 Git 仓库 URL
LOG_FILE="$HOME/memos_backup.log"  # 日志文件路径
CONTAINER_NAME="memos" # docker 容器名称
DOCKER_COMPOSE_FILE="docker-compose.yml" # docker-compose 文件路径

# 定义日志函数
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}
# 获取当前日期和时间，用于日志记录
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

log "Starting memos backup..."

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
# 进入本地仓库目录
cd "$REPO_PATH" || {
  log "Error: Could not change directory to $REPO_PATH"
  exit 1
}

# 添加所有更改
git add . >> "$LOG_FILE" 2>&1

# 判断是否有更改
if ! git diff --cached --quiet --exit-code; then

  # 如果有更改，则提交
  COMMIT_MESSAGE="Auto backup at $TIMESTAMP"
  git commit -m "$COMMIT_MESSAGE" >> "$LOG_FILE" 2>&1

  # 推送到远程仓库
    git push  >> "$LOG_FILE" 2>&1
  if [ $? -eq 0 ]; then
      log "Backup successful!"
  else
        log "Error: Backup failed, push failed."
      exit 1
   fi

else
  log "No changes to commit."
fi

log "Backup process finished."
exit 0
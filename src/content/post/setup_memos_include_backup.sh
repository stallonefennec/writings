#!/bin/bash

# 设置变量
REPO_URL="git@github.com:stallonefennec/memos_backup.git"
LOCAL_PATH="$HOME/.memos"
LOG_FILE="$HOME/memos_operations.log"
CONTAINER_NAME="memos"
DOCKER_COMPOSE_FILE="docker-compose.yml"
BACKUP_REPO_URL="git@github.com:stallonefennec/memos_db.git"

# 定义日志函数
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 获取当前日期和时间
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# 定义停止 Memos 容器的函数
stop_memos_container() {
  log "检查 Memos 容器状态..."
  if docker ps | grep -q "$CONTAINER_NAME"; then
    log "Memos 容器正在运行，正在停止..."
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
      docker-compose down
      if [[ $? -ne 0 ]]; then
        log "停止 docker-compose 项目失败，请检查 Docker 日志。"
        return 1
      fi
    else
      docker stop "$CONTAINER_NAME"
      if [[ $? -ne 0 ]]; then
        log "停止容器 $CONTAINER_NAME 失败，请检查 Docker 日志。"
        return 1
      fi
    fi
    log "Memos 容器已停止。"
  else
    log "Memos 容器未运行。"
  fi
  return 0;
}
# 删除本地memos目录
delete_local_memos_dir() {
   if [ -d "$LOCAL_PATH" ]; then
       log "发现旧的本地数据目录,删除旧的目录: $LOCAL_PATH"
      rm -rf "$LOCAL_PATH"
       if [[ $? -ne 0 ]]; then
          log "删除旧的本地数据目录 $LOCAL_PATH 失败."
            return 1
        fi
      log "旧的本地数据目录已删除: $LOCAL_PATH"
    fi
    return 0
}

# 定义备份 Memos 数据库的函数
backup_memos_db() {
  log "开始备份 Memos 数据库..."
  # 停止 memos 容器
  stop_memos_container;
  if [[ $? -ne 0 ]]; then
    log "停止memos失败，备份取消"
    return 1
  fi;
  # 进入本地仓库目录
   cd "$LOCAL_PATH" || {
    log "Error: Could not change directory to $LOCAL_PATH"
    return 1
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
          return 1
      fi
  else
   log "No changes to commit."
  fi
  log "Memos 数据库备份完成。"
  return 0;
}

# 定义同步 Memos 数据库的函数
sync_memos_db() {
    log "开始同步 Memos 数据库..."
   # 停止 memos 容器
  stop_memos_container;
  if [[ $? -ne 0 ]]; then
      log "停止memos失败，同步取消"
    return 1;
  fi;
    # 删除本地memos目录
  delete_local_memos_dir
    if [[ $? -ne 0 ]]; then
        log "删除本地memos目录失败，同步取消"
      return 1;
   fi
  # 创建本地目录
   log "创建目录: $LOCAL_PATH"
  mkdir -p "$LOCAL_PATH" || {
      log "Error: Failed to create directory $LOCAL_PATH"
     return 1
  }
    # 进入本地目录
  cd "$LOCAL_PATH" || {
    log "Error: Could not change directory to $LOCAL_PATH"
     return 1
  }
  # 检查本地仓库是否存在
  if [ ! -d ".git" ]; then
    log "Cloning repository..."
    git clone "$REPO_URL" .  # 克隆仓库到当前目录
  elif ! git remote -v | grep -q "$REPO_URL"; then # 检查remote origin 是否是 $REPO_URL
       log "Error: Not expected remote repo, exit"
      return 1
  else
    log "Pulling latest changes..."
    git pull origin main # 拉取最新更改
  fi
    # 检查更新结果
  if [ $? -eq 0 ]; then
    log "Update successful!"
  else
    log "Error: Update failed!"
    return 1
  fi
  log "Memos 数据库同步完成。"
    return 0;
}
# 主流程

while true; do
  read -r -p "请选择要执行的操作 (1: 备份, 2: 同步, 3: 退出): " CHOICE

  case "$CHOICE" in
    1)
      backup_memos_db
      if [[ $? -eq 0 ]]; then
         log "Memos 数据库备份成功。"
        else
          log "Memos 数据库备份失败。"
      fi
      ;;
    2)
      sync_memos_db
       if [[ $? -eq 0 ]]; then
        log "Memos 数据库同步成功。"
      else
        log "Memos 数据库同步失败。"
        fi
      ;;
    3)
      log "退出脚本。"
      exit 0
      ;;
    *)
      log "无效选项，请重新选择。"
      ;;
  esac
done
exit 0
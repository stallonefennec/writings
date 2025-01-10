#!/bin/bash

# 设置变量
REPO_URL="git@github.com:stallonefennec/memos_backup.git"
LOCAL_PATH="$HOME/.memos"
LOG_FILE="$HOME/memos_update.log"

# 获取当前日期和时间
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo "[$TIMESTAMP] Starting memos update..." >> "$LOG_FILE"

# 检查本地目录是否存在，如果不存在则创建
if [ ! -d "$LOCAL_PATH" ]; then
  echo "[$TIMESTAMP] Creating directory: $LOCAL_PATH" >> "$LOG_FILE"
  mkdir -p "$LOCAL_PATH" || {
    echo "[$TIMESTAMP] Error: Failed to create directory $LOCAL_PATH" >> "$LOG_FILE"
    exit 1
  }
fi


# 进入本地目录
cd "$LOCAL_PATH" || {
  echo "[$TIMESTAMP] Error: Could not change directory to $LOCAL_PATH" >> "$LOG_FILE"
  exit 1
}

# 检查本地仓库是否存在
if [ ! -d ".git" ]; then
  echo "[$TIMESTAMP] Cloning repository..." >> "$LOG_FILE"
  git clone "$REPO_URL" .  # 克隆仓库到当前目录
elif ! git remote -v | grep -q "$REPO_URL"; then # 检查remote origin 是否是 $REPO_URL
    echo "[$TIMESTAMP]  Error: Not expected remote repo, exit" >> "$LOG_FILE"
    exit 1
else
    echo "[$TIMESTAMP] Pulling latest changes..." >> "$LOG_FILE"
    git pull origin main # 拉取最新更改
fi


# 检查更新结果
if [ $? -eq 0 ]; then
  echo "[$TIMESTAMP] Update successful!" >> "$LOG_FILE"
else
  echo "[$TIMESTAMP] Error: Update failed!" >> "$LOG_FILE"
  exit 1
fi

echo "[$TIMESTAMP] Update process finished." >> "$LOG_FILE"
exit 0
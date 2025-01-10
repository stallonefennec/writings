#!/bin/bash

# 设置变量
REPO_URL="git@github.com:stallonefennec/memos_db.git"  # 远程 Git 仓库 URL
LOCAL_DIR="$HOME/.memos"  # 本地目标目录
TMP_DIR="/tmp/memos_repo" # 临时目录
LOG_FILE="$HOME/memos_sync.log"  # 日志文件路径
BRANCH="main" # 分支名称

# 获取当前日期和时间，用于日志记录
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "[$TIMESTAMP] Starting memos sync..." >> "$LOG_FILE"

# 检查临时目录是否存在，如果存在先删除
if [ -d "$TMP_DIR" ]; then
    echo "[$TIMESTAMP] Remove exist tmp directory: $TMP_DIR" >> "$LOG_FILE"
    rm -rf "$TMP_DIR" >> "$LOG_FILE" 2>&1
fi
# 创建临时目录
mkdir -p "$TMP_DIR" >> "$LOG_FILE" 2>&1

# 克隆远程仓库到临时目录
echo "[$TIMESTAMP] Cloning repository to $TMP_DIR..." >> "$LOG_FILE"
git clone -b "$BRANCH" "$REPO_URL" "$TMP_DIR" >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "[$TIMESTAMP] Error: Git clone failed." >> "$LOG_FILE"
    rm -rf "$TMP_DIR" >> "$LOG_FILE" 2>&1
    exit 1
fi

# 检查本地目录是否存在，如果存在先备份
if [ -d "$LOCAL_DIR" ]; then
  echo "[$TIMESTAMP] Backup old memos directory to $LOCAL_DIR.bak" >> "$LOG_FILE"
   mv "$LOCAL_DIR" "$LOCAL_DIR.bak" >> "$LOG_FILE" 2>&1
fi

# 复制临时目录的内容到本地目录
echo "[$TIMESTAMP] Copying files from $TMP_DIR to $LOCAL_DIR..." >> "$LOG_FILE"
cp -a "$TMP_DIR"/* "$LOCAL_DIR" >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "[$TIMESTAMP] Sync successful! " >> "$LOG_FILE"
else
   echo "[$TIMESTAMP] Error: Sync failed! " >> "$LOG_FILE"
fi

# 删除临时目录
echo "[$TIMESTAMP] Remove tmp directory: $TMP_DIR" >> "$LOG_FILE"
rm -rf "$TMP_DIR" >> "$LOG_FILE" 2>&1

echo "[$TIMESTAMP] Sync process finished." >> "$LOG_FILE"
exit 0
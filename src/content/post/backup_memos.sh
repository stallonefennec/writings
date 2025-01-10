#!/bin/bash

# 设置变量
REPO_PATH="$HOME/.memos"  # 本地 Git 仓库路径
REMOTE_REPO="git@github.com:stallonefennec/memos_db.git" # 远程 Git 仓库 URL
LOG_FILE="$HOME/memos_backup.log"  # 日志文件路径

# 获取当前日期和时间，用于日志记录
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo "[$TIMESTAMP] Starting memos backup..." >> "$LOG_FILE"

# 进入本地仓库目录
cd "$REPO_PATH" || {
  echo "[$TIMESTAMP] Error: Could not change directory to $REPO_PATH" >> "$LOG_FILE"
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
       echo "[$TIMESTAMP] Backup successful!" >> "$LOG_FILE"
  else
        echo "[$TIMESTAMP] Error: Backup failed, push failed." >> "$LOG_FILE"
   fi

else
  echo "[$TIMESTAMP] No changes to commit." >> "$LOG_FILE"
fi

echo "[$TIMESTAMP] Backup process finished." >> "$LOG_FILE"
exit 0
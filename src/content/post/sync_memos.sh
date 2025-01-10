#!/bin/bash

# 设置变量
REPO_URL="git@github.com:stallonefennec/memos_db.git"  # Git 仓库 URL
TARGET_DIR="$HOME/.memos"  # 本地目标目录
TEMP_DIR="$HOME/temp_memos_repo" # 临时目录
LOG_FILE="$HOME/memos_sync.log"

# 获取当前日期和时间，用于日志记录
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo "[$TIMESTAMP] Starting memos sync..." >> "$LOG_FILE"

# 1. 检查目标目录是否存在，如果不存在则创建
if [ ! -d "$TARGET_DIR" ]; then
    echo "[$TIMESTAMP] Target directory $TARGET_DIR does not exist, creating it." >> "$LOG_FILE"
    mkdir -p "$TARGET_DIR" >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "[$TIMESTAMP] Error: Failed to create target directory $TARGET_DIR." >> "$LOG_FILE"
        exit 1
    fi
fi

# 2. 检查临时目录是否存在，如果不存在则创建
if [ ! -d "$TEMP_DIR" ]; then
    echo "[$TIMESTAMP] Temporary directory $TEMP_DIR does not exist, creating it." >> "$LOG_FILE"
    mkdir -p "$TEMP_DIR" >> "$LOG_FILE" 2>&1
        if [ $? -ne 0 ]; then
        echo "[$TIMESTAMP] Error: Failed to create temporary directory $TEMP_DIR." >> "$LOG_FILE"
        exit 1
    fi
fi

# 3. 拉取最新版本
cd "$TEMP_DIR" || {
  echo "[$TIMESTAMP] Error: Could not change directory to $TEMP_DIR" >> "$LOG_FILE"
  exit 1
}


if [ -d "$TEMP_DIR/.git" ]; then
    # 如果临时目录存在git，则先删除git仓库
    echo "[$TIMESTAMP] Temporary directory is git repository, removing it." >> "$LOG_FILE"
    rm -rf "$TEMP_DIR/.git"
fi

git clone "$REPO_URL" .  >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
  echo "[$TIMESTAMP] Error: Failed to clone the repository." >> "$LOG_FILE"
    exit 1
fi



# 4. 删除目标目录下的文件（除了.git目录）
echo "[$TIMESTAMP] Removing existing content from $TARGET_DIR..." >> "$LOG_FILE"
find "$TARGET_DIR" -maxdepth 1 ! -name ".git" -print0 | xargs -0 rm -rf  >> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
    echo "[$TIMESTAMP] Error: Failed to remove existing files in $TARGET_DIR" >> "$LOG_FILE"
    exit 1
fi

# 5. 复制拉取到的内容到目标目录
echo "[$TIMESTAMP] Copying files from $TEMP_DIR to $TARGET_DIR..." >> "$LOG_FILE"
find "$TEMP_DIR" -mindepth 1 -print0 | xargs -0 cp -a -t "$TARGET_DIR"  >> "$LOG_FILE" 2>&1

if [ $? -ne 0 ]; then
    echo "[$TIMESTAMP] Error: Failed to copy the files to target directory." >> "$LOG_FILE"
    exit 1
fi

#6. 删除临时目录
echo "[$TIMESTAMP] Removing temporary directory $TEMP_DIR..." >> "$LOG_FILE"
rm -rf "$TEMP_DIR" >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "[$TIMESTAMP] Error: Failed to remove temporary directory $TEMP_DIR." >> "$LOG_FILE"
    exit 1
fi

echo "[$TIMESTAMP] Sync completed successfully." >> "$LOG_FILE"

exit 0
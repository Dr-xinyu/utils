#!/bin/bash

# ==========================================
# ⚙️ 容器核心配置
# ==========================================
# 你的容器名称
CONTAINER_NAME="fyl_grasp"

# 进入容器时默认使用的 Shell
SHELL_CMD="/bin/bash"

# ==========================================
# 🔍 状态检查逻辑
# ==========================================

# 1. 检查容器是否存在
if ! docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
    echo "❌ 错误: 容器 '$CONTAINER_NAME' 不存在！"
    echo "请先手动创建容器或检查名称是否正确。"
    exit 1
fi

# 2. 检查容器是否正在运行
IS_RUNNING=$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null)

if [ "$IS_RUNNING" = "false" ]; then
    echo "▶️ 容器 '$CONTAINER_NAME' 当前处于停止状态，正在尝试启动..."
    if ! docker start "$CONTAINER_NAME" > /dev/null; then
        echo "❌ 错误: 无法启动容器 '$CONTAINER_NAME'。"
        exit 1
    fi
    echo "✅ 容器已启动。"
fi

# ==========================================
# 🚪 进入容器
# ==========================================
echo "🚀 正在进入容器 '$CONTAINER_NAME'..."
docker exec -it "$CONTAINER_NAME" "$SHELL_CMD"

# 退出后的提示
if [ $? -ne 0 ]; then
    echo "⚠️  进入容器失败（可能是 $SHELL_CMD 不存在，请尝试修改脚本中的 SHELL_CMD 为 /bin/sh）。"
else
    echo "👋 已退出容器终端。"
fi
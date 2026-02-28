#!/bin/bash

# ==========================================
# ⚙️ 1. 环境准备与安全解密
# ==========================================
# 指向你的加密配置文件
CONFIG_FILE="$(dirname "$0")/config.json.enc"

# 关键逻辑：如果当前不是后台守护进程，则执行解密
if [ "$1" != "--internal-do-run" ]; then
    # 检查依赖
    for cmd in jq openssl curl; do
        if ! command -v $cmd &> /dev/null; then
            echo "❌ 错误: 系统未安装 '$cmd' 工具，请先安装。"
            exit 1
        fi
    done

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "❌ 错误: 找不到加密配置文件: $CONFIG_FILE"
        exit 1
    fi

    # 交互式输入密码
    read -s -p "🔒 请输入配置解密密码: " DECRYPT_PASS
    echo ""

    # 内存解密
    DECRYPTED_JSON=$(openssl enc -aes-256-cbc -d -pbkdf2 -iter 100000 -in "$CONFIG_FILE" -pass "pass:$DECRYPT_PASS" 2>/dev/null)

    if [ $? -ne 0 ] || [ -z "$DECRYPTED_JSON" ]; then
        echo "❌ 错误: 密码错误或解密失败！任务中止。"
        exit 1
    fi

    # 提取并安全导出为环境变量（后台子进程会自动继承）
    export PUSHOVER_TOKEN=$(echo "$DECRYPTED_JSON" | jq -r '.pushover_token')
    export PUSHOVER_USER=$(echo "$DECRYPTED_JSON" | jq -r '.pushover_user')

    # 立即清理内存中的敏感数据
    unset DECRYPTED_JSON
    unset DECRYPT_PASS
fi

# ==========================================
# 🔔 2. 封装推送函数
# ==========================================
# 注意：此处的 Token 已经通过环境变量安全传递，无需再次解析文件
send_pushover() {
    local title="$1"
    local message="$2"
    curl -s \
        --form-string "token=${PUSHOVER_TOKEN}" \
        --form-string "user=${PUSHOVER_USER}" \
        --form-string "title=${title}" \
        --form-string "message=${message}" \
        https://api.pushover.net/1/messages.json > /dev/null
}

# ==========================================
# 👻 3. 内部后台执行与日志记录逻辑
# ==========================================
# 如果参数是 --internal-do-run，说明此时已经在后台守护进程中
if [ "$1" == "--internal-do-run" ]; then
    shift
    LOG_FILE="$1"
    shift
    
    TASK_NAME=$(basename "$1")
    FULL_COMMAND="$*"

    # 核心：执行传入的命令，并将所有标准输出(1)和错误输出(2)全部重定向到日志文件
    "$@" > "$LOG_FILE" 2>&1
    EXIT_CODE=$?

    # 根据返回值发送通知，并在通知里附上日志路径
    if [ $EXIT_CODE -eq 0 ]; then
        send_pushover "✅ 任务成功: $TASK_NAME" "任务已在后台执行完成！\n\n日志保存在: $LOG_FILE"
    else
        send_pushover "🚨 任务失败: $TASK_NAME" "任务异常中止 (错误码 $EXIT_CODE)！\n\n请查看日志: $LOG_FILE"
    fi
    exit $EXIT_CODE
fi

# ==========================================
# 🚀 4. 前台解析与参数处理
# ==========================================

RUN_IN_BG=false
# 如果用户传入了 --bg，则开启后台模式
if [ "$1" == "--bg" ]; then
    RUN_IN_BG=true
    shift # 移除 --bg 参数，保留后面的实际执行命令
fi

if [ "$#" -eq 0 ]; then
    echo "❌ 错误: 没有传入需要执行的脚本或命令。"
    echo "💡 用法: $0 [--bg] <要执行的命令> [参数...]"
    echo "💡 示例(前台): $0 python3 spider.py"
    echo "💡 示例(后台): $0 --bg ./transfer.sh /local /remote"
    exit 1
fi

TASK_NAME=$(basename "$1")
# 生成带有时间戳的独立日志文件，例如：/tmp/spider.py_20231024_153022.log
LOG_FILE="/tmp/${TASK_NAME}_$(date +%Y%m%d_%H%M%S).log"

if [ "$RUN_IN_BG" = true ]; then
    echo "========================================="
    echo "✅ 密码验证通过，配置已读取！"
    echo "🚀 任务已提交到后台运行: $TASK_NAME"
    echo "📄 运行日志将保存在: $LOG_FILE"
    echo "💡 实时查看输出请执行: tail -f $LOG_FILE"
    echo "========================================="
    
    # 巧妙利用 nohup 调用脚本自身进入后台，脱离当前终端
    # 注意：此时父进程导出的 PUSHOVER_TOKEN 已经被这个后台进程继承！
    nohup "$0" --internal-do-run "$LOG_FILE" "$@" >/dev/null 2>&1 &
    exit 0
else
    echo "========================================="
    echo "✅ 密码验证通过，配置已读取！"
    echo "▶️ 开始运行任务: $TASK_NAME (前台模式)"
    echo "📄 日志文件: $LOG_FILE"
    echo "========================================="
    
    # 前台运行也把日志导过去
    "$@" > "$LOG_FILE" 2>&1
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo "✅ 执行成功！"
        send_pushover "✅ 任务成功: $TASK_NAME" "命令执行完成。\n\n日志: $LOG_FILE"
    else
        echo "❌ 执行失败！错误码: $EXIT_CODE"
        send_pushover "🚨 任务失败: $TASK_NAME" "命令异常中止 (错误码 $EXIT_CODE)。\n\n日志: $LOG_FILE"
    fi
    exit $EXIT_CODE
fi
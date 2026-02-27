#!/bin/bash

# ==========================================
# 极速智能解压脚本 (静默进度条 + 极速探针 + 最终确认)
# 用法: ./extract.sh [-v] <压缩包路径> [解压目标路径]
# ==========================================

# --- 0. 参数解析 (支持 -v 详细模式) ---
VERBOSE=0
if [ "$1" = "-v" ] || [ "$1" = "--verbose" ]; then
    VERBOSE=1
    shift # 剔除 -v 参数，让后面的参数往前移
fi

if [ -z "$1" ]; then
    echo -e "\033[31m❌ 错误: 未提供压缩包路径。\033[0m"
    echo -e "💡 用法: $0 [-v] <压缩包路径> [解压目标文件夹路径]"
    echo -e "   -v, --verbose   显示解压出的每一个文件详细列表"
    exit 1
fi

ARCHIVE="$1"
DEST_DIR="${2:-.}"
ARCHIVE_PWD=""

if [ ! -f "$ARCHIVE" ]; then
    echo -e "\033[31m❌ 错误: 找不到压缩包 '$ARCHIVE'\033[0m"
    exit 1
fi

BASENAME=$(basename "$ARCHIVE")
DIR_NAME=$(echo "$BASENAME" | sed -E 's/\.(tar\.gz|tar\.bz2|tar\.xz|tgz|tbz2|tar|zip|rar|7z)$//i')
LOWER_NAME=$(echo "$ARCHIVE" | tr '[:upper:]' '[:lower:]')

# --- 定义极速探针函数 ---
get_top_count() {
    local pwd_arg="$1"
    local count=0
    local awk_cmd='BEGIN { FS="/" } $1 != "" { if (!seen[$1]) { seen[$1] = 1; count++; if (count >= 3) exit 0 } } END { print count + 0 }'
    
    case "$LOWER_NAME" in
        *.zip)
            if [ -n "$pwd_arg" ]; then
                count=$(unzip -Z1 -P "$pwd_arg" "$ARCHIVE" 2>/dev/null | awk "$awk_cmd" 2>/dev/null)
            else
                count=$(unzip -Z1 "$ARCHIVE" < /dev/null 2>/dev/null | awk "$awk_cmd" 2>/dev/null)
            fi ;;
        *.rar)
            if [ -n "$pwd_arg" ]; then
                count=$(unrar lb -p"$pwd_arg" "$ARCHIVE" 2>/dev/null | awk "$awk_cmd" 2>/dev/null)
            else
                count=$(unrar lb -p- "$ARCHIVE" < /dev/null 2>/dev/null | awk "$awk_cmd" 2>/dev/null)
            fi ;;
        *.7z)
            if [ -n "$pwd_arg" ]; then
                count=$(7z l -ba -slt -p"$pwd_arg" "$ARCHIVE" 2>/dev/null | grep -i "^Path = " | sed 's/^Path = //i' | awk "$awk_cmd" 2>/dev/null)
            else
                count=$(7z l -ba -slt -p"" "$ARCHIVE" < /dev/null 2>/dev/null | grep -i "^Path = " | sed 's/^Path = //i' | awk "$awk_cmd" 2>/dev/null)
            fi ;;
        *.tar.*|*.tgz|*.tbz2|*.tar)
            count=$(tar -tf "$ARCHIVE" < /dev/null 2>/dev/null | awk "$awk_cmd" 2>/dev/null) ;;
    esac
    echo "$count"
}

# --- 1. 智能防杂乱与密码探针 ---
if [ "$DEST_DIR" = "." ] || [ "$DEST_DIR" = "$PWD" ]; then
    echo -e "🔍 正在极速扫描压缩包结构..."
    TOP_COUNT=$(get_top_count "")

    if [ "$TOP_COUNT" -eq 0 ]; then
        echo -e "\033[33m🔒 无法直接读取内容，压缩包可能已加密。\033[0m"
        read -s -p "🔑 请输入密码 (若无密码请直接回车): " ARCHIVE_PWD
        echo "" 
        
        if [ -n "$ARCHIVE_PWD" ]; then
            echo -e "⏳ 正在验证密码..."
            TOP_COUNT=$(get_top_count "$ARCHIVE_PWD")
            if [ "$TOP_COUNT" -gt 0 ]; then
                echo -e "\033[32m✅ 密码正确！\033[0m"
            else
                echo -e "\033[31m❌ 密码可能错误，依旧无法预览。\033[0m"
            fi
        fi
    fi

    if [ "$TOP_COUNT" -ge 3 ]; then
        echo -e "\033[33m⚠️ 警告: 该压缩包内含 3 个或以上的独立顶层项！\033[0m"
        read -p "👉 是否自动创建文件夹 [$DIR_NAME] 并解压到里面？(Y/n): " USER_CHOICE
        USER_CHOICE=${USER_CHOICE:-Y}
        if [[ "$USER_CHOICE" == [Yy]* ]]; then DEST_DIR="./$DIR_NAME"; fi
    elif [ "$TOP_COUNT" -eq 0 ]; then
        echo -e "\033[33m⚠️ 提示: 无法确认内部结构...\033[0m"
        read -p "👉 是否安全起见，创建文件夹 [$DIR_NAME] 并解压到里面？(Y/n): " USER_CHOICE
        USER_CHOICE=${USER_CHOICE:-Y}
        if [[ "$USER_CHOICE" == [Yy]* ]]; then DEST_DIR="./$DIR_NAME"; fi
    else
        echo -e "✅ 检测完毕: 压缩包内只有 $TOP_COUNT 个顶层项，结构清晰。"
    fi
fi

# --- 2. 检查并创建目标目录 ---
if [ ! -d "$DEST_DIR" ]; then
    mkdir -p "$DEST_DIR" || { echo -e "\033[31m❌ 错误: 无法创建目录 '$DEST_DIR'\033[0m"; exit 1; }
fi

# --- 3. 最终确认 ---
echo ""
echo -e "📌 目标压缩包: \033[36m$ARCHIVE\033[0m"
echo -e "📌 解压至目录: \033[36m$DEST_DIR\033[0m"
if [ "$VERBOSE" -eq 0 ]; then
    echo -e "🤫 当前为静默模式，仅显示进度。"
else
    echo -e "📢 当前为详细模式，将打印所有解压文件。"
fi
read -p "🎯 准备就绪，按 [Enter] 键开始解压，或按 [Ctrl+C] 取消..."

echo "------------------------------------------------------"

# --- 4. 执行解压 (静默进度/详细输出 分支处理) ---
run_tar() {
    local tar_flags="$1"
    if [ "$VERBOSE" -eq 1 ]; then
        tar "-${tar_flags}v" "$ARCHIVE" -C "$DEST_DIR"
    else
        if command -v pv >/dev/null 2>&1; then 
            pv "$ARCHIVE" | tar "-${tar_flags}" - -C "$DEST_DIR"
        else 
            echo "⏳ 正在解压，请稍候..."
            tar "-${tar_flags}" "$ARCHIVE" -C "$DEST_DIR"
        fi
    fi
}

case "$LOWER_NAME" in
    *.tar.gz|*.tgz) run_tar "xzf" ;;
    *.tar.bz2|*.tbz2) run_tar "xjf" ;;
    *.tar.xz) run_tar "xJf" ;;
    *.tar) run_tar "xf" ;;
    *.zip)
        if [ "$VERBOSE" -eq 1 ]; then
            if [ -n "$ARCHIVE_PWD" ]; then unzip -P "$ARCHIVE_PWD" "$ARCHIVE" -d "$DEST_DIR"; else unzip "$ARCHIVE" -d "$DEST_DIR"; fi
        else
            echo "⏳ 正在静默解压 zip，请稍候..."
            if [ -n "$ARCHIVE_PWD" ]; then unzip -q -P "$ARCHIVE_PWD" "$ARCHIVE" -d "$DEST_DIR"; else unzip -q "$ARCHIVE" -d "$DEST_DIR"; fi
        fi ;;
    *.rar)
        if command -v unrar >/dev/null 2>&1; then 
            if [ "$VERBOSE" -eq 1 ]; then
                if [ -n "$ARCHIVE_PWD" ]; then unrar x -p"$ARCHIVE_PWD" "$ARCHIVE" "$DEST_DIR/"; else unrar x "$ARCHIVE" "$DEST_DIR/"; fi
            else
                echo "⏳ 正在静默解压 rar，请稍候..."
                if [ -n "$ARCHIVE_PWD" ]; then unrar x -idq -p"$ARCHIVE_PWD" "$ARCHIVE" "$DEST_DIR/"; else unrar x -idq "$ARCHIVE" "$DEST_DIR/"; fi
            fi
        else 
            if [ "$VERBOSE" -eq 1 ]; then
                if [ -n "$ARCHIVE_PWD" ]; then 7z x -p"$ARCHIVE_PWD" "$ARCHIVE" -o"$DEST_DIR"; else 7z x "$ARCHIVE" -o"$DEST_DIR"; fi
            else
                if [ -n "$ARCHIVE_PWD" ]; then 7z x -bsp1 -bso0 -p"$ARCHIVE_PWD" "$ARCHIVE" -o"$DEST_DIR"; else 7z x -bsp1 -bso0 "$ARCHIVE" -o"$DEST_DIR"; fi
            fi
        fi ;;
    *.7z)
        if [ "$VERBOSE" -eq 1 ]; then
            if [ -n "$ARCHIVE_PWD" ]; then 7z x -p"$ARCHIVE_PWD" "$ARCHIVE" -o"$DEST_DIR"; else 7z x "$ARCHIVE" -o"$DEST_DIR"; fi
        else
            if [ -n "$ARCHIVE_PWD" ]; then 7z x -bsp1 -bso0 -p"$ARCHIVE_PWD" "$ARCHIVE" -o"$DEST_DIR"; else 7z x -bsp1 -bso0 "$ARCHIVE" -o"$DEST_DIR"; fi
        fi ;;
    *)
        echo -e "\033[31m❌ 错误: 不支持的格式 '$ARCHIVE'\033[0m"
        exit 1 ;;
esac

# --- 5. 状态反馈 ---
STATUS=$?
echo "------------------------------------------------------"
if [ $STATUS -eq 0 ]; then
    echo -e "\033[32m🎉 解压成功！文件在: $DEST_DIR\033[0m"
else
    echo -e "\033[31m❌ 解压失败！(错误码: $STATUS)\033[0m"
    exit $STATUS
fi
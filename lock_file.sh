#!/bin/bash

# 定义使用说明函数
show_help() {
    echo "用法: $0 [文件路径] [操作]"
    echo ""
    echo "选项:"
    echo "  -h          显示此帮助信息"
    echo ""
    echo "操作:"
    echo "  lock        锁定文件（不可修改、不可删除）"
    echo "  unlock      解锁文件"
    echo ""
    echo "示例:"
    echo "  $0 ./data.txt lock"
}

# 1. 检查是否请求帮助或参数为空
if [[ "$1" == "-h" || -z "$1" ]]; then
    show_help
    exit 0
fi

# 2. 检查参数个数
if [ $# -ne 2 ]; then
    echo "错误：参数数量不正确。"
    show_help
    exit 1
fi

FILE_PATH=$1
ACTION=$2

# 3. 检查文件是否存在
if [ ! -e "$FILE_PATH" ]; then
    echo "错误: 文件 '$FILE_PATH' 不存在。"
    exit 1
fi

# 4. 执行逻辑
case "$ACTION" in
    "lock")
        sudo chattr +i "$FILE_PATH" && echo "已锁定: $FILE_PATH"
        ;;
    "unlock")
        sudo chattr -i "$FILE_PATH" && echo "已解锁: $FILE_PATH"
        ;;
    *)
        echo "无效操作: '$ACTION'"
        show_help
        exit 1
        ;;
esac

# 显示最终状态
lsattr -d "$FILE_PATH"


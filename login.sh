#!/usr/bin/env bash
# 文件名: go.sh
HOST=9.tcp.vip.cpolar.cn   # 换成你的 IP 或域名
PORT=13333              # 非 22 就改
USER=c1-505           # 用户名
PASS='znkzC1%505'        # 密码

# 直接跳进交互式 shell
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -p "$PORT" "$USER@$HOST"

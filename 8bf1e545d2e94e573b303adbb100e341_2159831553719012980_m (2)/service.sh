#!/system/bin/sh
LOG_FILE="/storage/emulated/0/performance-ai/log/refresh.log"

CURRENT_PROCESSOR=$(getprop ro.product.board)
CURRENT_ANDROID=$(getprop ro.build.version.release)
CURRENT_KERNEL=$(uname -r)

LOG_PROCESSOR=$(awk -F': ' '/: Processor/{print $NF}' "$LOG_FILE" | head -1 | tr -d ' ')
LOG_ANDROID=$(awk -F': ' '/: Android Version/{print $NF}' "$LOG_FILE" | head -1 | tr -d ' ')
LOG_KERNEL=$(awk -F': ' '/Kernel Version/{print $NF}' "$LOG_FILE" | head -1 | tr -d ' ')

# 如果当前设备信息与日志中的记录不一致，则退出
if [ "$CURRENT_PROCESSOR" != "$LOG_PROCESSOR" ] || [ "$CURRENT_ANDROID" != "$LOG_ANDROID" ] || [ "$CURRENT_KERNEL" != "$LOG_KERNEL" ]; then
    exit 0
fi

# 如果 perf_service_@api 已在运行，则退出
if pgrep -f "perf_service_@api" > /dev/null; then
    exit 0
else
    # 否则后台启动安装脚本
    sh /storage/emulated/0/performance-ai/start.sh --install > /dev/null 2>&1 &
    
    # 发送通知：自动启动已部署
    cmd notification post -S bigtext -i "file:///storage/emulated/0/performance-ai/img/banner.png" -t '[Perf AI 状态]' 'PerfAI_Tag' '自动启动已部署' > /dev/null 2>&1 || su -lp 2000 -c "cmd notification post -S bigtext -i \"file:///storage/emulated/0/performance-ai/img/banner.png\" -t '[Perf AI 状态]' 'PerfAI_Tag' '自动启动已部署' > /dev/null 2>&1"
fi

exit 0

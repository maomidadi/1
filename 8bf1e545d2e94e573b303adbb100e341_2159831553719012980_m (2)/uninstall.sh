#!/system/bin/sh

send_notification() {
    cmd notification post -S bigtext -t '性能优化 AI' 'tag' '卸载完成' >/dev/null 2>&1
}

sh /storage/emulated/0/performance-ai/start.sh --uninstall

sleep 10

TARGET="/storage/emulated/0/performance-ai"

if [ -d "$TARGET" ]; then
    rm -rf "$TARGET"
    echo "已删除 $TARGET。"
    send_notification
else
    echo "未找到文件夹 $TARGET。"
fi

#!/system/bin/sh

info() {
    echo "  ____            __    _      _ "
    echo " |  _ \  ___ _ __/ _|  / \    (_)"
    echo " | |_) |/ _ \ '__| |_  / _ \   | |"
    echo " |  __/|  __/ |  |  _|/ ___ \  | |"
    echo " |_|    \___|_|  |_| /_/   \_\ |_|"
    echo
    echo "   Perf-Ai 需要在 WebUI 中进行配置"
    echo "   点击插件菜单或模块菜单中的 WebUI 图标进行配置"
    echo
}

send_notification() {
    cmd notification post -S bigtext -t '性能优化 AI' 'tag' '移动 API 文件完成' >/dev/null 2>&1
}

unzip_performance_ai() {
    unzip -o "$MODPATH/performance-ai.zip" -d "/storage/emulated/0/"
}

unzip_performance_ai
info
send_notification
return 0

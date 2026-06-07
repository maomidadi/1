#!/system/bin/sh

ram_free() {
    local total_ram available_ram used_ram
    
    total_ram=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    available_ram=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    used_ram=$((total_ram - available_ram))
    
    total_gb=$(echo "scale=2; $total_ram/1024/1024" | bc)
    used_gb=$(echo "scale=2; $used_ram/1024/1024" | bc)
    usage_percent=$(echo "scale=1; $used_ram*100/$total_ram" | bc)
    
    echo "总内存    : $total_gb GB"
    echo "已用内存  : $used_gb GB"
    echo "使用率    : $usage_percent%"
}

get_system_cpu_usage_percentage() {
    read_cpu_stats() {
        read -r _ user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
        echo $((user+nice+system+idle+iowait+irq+softirq+steal+guest+guest_nice)) "$idle"
    }
    
    initial_stats=$(read_cpu_stats)
    sleep 0.2
    final_stats=$(read_cpu_stats)
    
    initial_total_time=$(echo "$initial_stats" | cut -d' ' -f1)
    initial_idle_time=$(echo "$initial_stats" | cut -d' ' -f2)
    final_total_time=$(echo "$final_stats" | cut -d' ' -f1)
    final_idle_time=$(echo "$final_stats" | cut -d' ' -f2)
    
    delta_total=$((final_total_time - initial_total_time))
    delta_idle=$((final_idle_time - initial_idle_time))
    
    if [ "$delta_total" -eq 0 ]; then 
        echo "0.0"
    else 
        echo "$delta_total $delta_idle" | awk '{printf "%.1f", (100.0 * ($1 - $2) / $1)}'
    fi
}

proc_stat_and_usage() {
    pid=$(pgrep -f "/data/local/tmp/perf_service_@api" | head -n 1)
    
    if [ -z "$pid" ]; then
        echo "性能服务状态: 已停止"
        echo ""
        echo "服务详情:"
        echo "  状态: 未找到服务"
        echo "  操作: 运行 'start.sh' 以激活"
        return 1
    fi
    
    echo "性能服务状态: 运行中"
    echo ""
    
    if [ -f "/proc/$pid/stat" ]; then
        stats=$(cat "/proc/$pid/stat")
        starttime=$(echo "$stats" | awk '{print $22}')
        uptime_seconds=$(awk '{print $1}' /proc/uptime)
        hz=$(getconf CLK_TCK 2>/dev/null || echo 100)
        
        runtime_seconds=$(echo "$uptime_seconds $starttime $hz" | awk '{printf "%.0f", $1 - ($2 / $3)}')
        
        if [ "$runtime_seconds" -lt 0 ]; then
            runtime_seconds=0
        fi
        
        days=$((runtime_seconds / 86400))
        hours=$(( (runtime_seconds % 86400) / 3600 ))
        minutes=$(( (runtime_seconds % 3600) / 60 ))
        seconds=$((runtime_seconds % 60))
        
        read_process_and_system_stats() {
            process_stats=$(cat "/proc/$pid/stat")
            process_utime=$(echo "$process_stats" | awk '{print $14}')
            process_stime=$(echo "$process_stats" | awk '{print $15}')
            read -r _ user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
            system_total_time=$((user+nice+system+idle+iowait+irq+softirq+steal+guest+guest_nice))
            echo "$process_utime $process_stime $system_total_time"
        }
        
        initial_cpu_stats=$(read_process_and_system_stats)
        initial_utime=$(echo "$initial_cpu_stats" | cut -d' ' -f1)
        initial_stime=$(echo "$initial_cpu_stats" | cut -d' ' -f2)
        initial_process_time=$((initial_utime + initial_stime))
        initial_system_total_time=$(echo "$initial_cpu_stats" | cut -d' ' -f3)
        
        sleep 0.1
        
        final_cpu_stats=$(read_process_and_system_stats)
        final_utime=$(echo "$final_cpu_stats" | cut -d' ' -f1)
        final_stime=$(echo "$final_cpu_stats" | cut -d' ' -f2)
        final_process_time=$((final_utime + final_stime))
        final_system_total_time=$(echo "$final_cpu_stats" | cut -d' ' -f3)
        
        delta_process_time=$((final_process_time - initial_process_time))
        delta_system_total_time=$((final_system_total_time - initial_system_total_time))
        
        if [ "$delta_system_total_time" -eq 0 ]; then 
            process_cpu_percent="0.0"
        else 
            process_cpu_percent=$(echo "$delta_process_time $delta_system_total_time" | awk '{printf "%.1f", (100.0 * $1 / $2)}')
        fi
        
        echo "服务详情:"
        echo "  PID          : $pid"
        echo "  运行时长     : ${days}天 ${hours}小时 ${minutes}分钟 ${seconds}秒"
        echo "  CPU 使用率  : ${process_cpu_percent}%"
        
        # I/O 详情
        if [ -f "/proc/$pid/io" ]; then
            read_bytes=$(grep "read_bytes:" "/proc/$pid/io" | awk '{print $2}' | tr -d '[:space:]')
            write_bytes=$(grep "write_bytes:" "/proc/$pid/io" | awk '{print $2}' | tr -d '[:space:]')
            
            format_bytes() {
                echo "$1" | awk -v bytes="${1:-0}" 'BEGIN { 
                    if (bytes >= 1073741824) printf "%.2f GB", bytes/1073741824
                    else if (bytes >= 1048576) printf "%.2f MB", bytes/1048576
                    else if (bytes >= 1024) printf "%.2f KB", bytes/1024
                    else printf "%d B", bytes
                }'
            }
            
            echo "  I/O 统计:"
            echo "    读取  : $(format_bytes "$read_bytes")"
            echo "    写入  : $(format_bytes "$write_bytes")"
            total_io=$((read_bytes + write_bytes))
            echo "    总计  : $(format_bytes "$total_io")"
        fi
        
    else
        echo "性能服务状态: 错误"
        echo ""
        echo "服务详情:"
        echo "  错误: 无法访问 /proc/$pid"
        echo "  服务可能已意外终止"
        return 1
    fi
}

echo "  ____            __    _      _ "
echo " |  _ \  ___ _ __/ _|  / \    (_)"
echo " | |_) |/ _ \ '__| |_  / _ \   | |"
echo " |  __/|  __/ |  |  _|/ ___ \  | |"
echo " |_|    \___|_|  |_| /_/   \_\ |_|"
echo
echo " "
echo "性能优化 AI 监控器"
echo "======================"
echo ""

# 服务状态部分
echo "服务状态"
echo "-------------"
proc_stat_and_usage
echo ""

# 系统资源部分
echo "系统资源"
echo "---------------"

# CPU 使用率
cpu_usage=$(get_system_cpu_usage_percentage)
echo "CPU 使用率    : ${cpu_usage}%"

# 内存使用率
ram_info=$(ram_free)
echo "$ram_info"
echo ""
echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================="
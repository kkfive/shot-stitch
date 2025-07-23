#!/bin/bash
# scene_detect.sh - 场景检测功能

# 场景检测函数
detect_scene_changes() {
    local video_file="$1"
    local threshold="$2"
    local scene_times=()
    
    echo -e "${YELLOW}正在分析视频场景变化...${NC}"
    
    # 创建临时文件用于存储场景检测结果
    local temp_scene_file="$TEMP_DIR/scene_detection.txt"
    local temp_progress_file="$TEMP_DIR/scene_progress.txt"
    
    # 启动场景检测进程（后台运行）
    ffmpeg -i "$video_file" \
        -vf "select='gt(scene,$threshold)',showinfo" \
        -f null - \
        -progress "$temp_progress_file" \
        2>"$temp_scene_file" &
    
    local ffmpeg_pid=$!
    
    # 显示进度
    echo -n "场景检测进度: 0%"
    while kill -0 $ffmpeg_pid 2>/dev/null; do
        if [ -f "$temp_progress_file" ]; then
            # 从进度文件中读取当前时间
            local current_time=$(tail -n 20 "$temp_progress_file" 2>/dev/null | grep "out_time_ms=" | tail -n 1 | cut -d= -f2)
            if [ -n "$current_time" ] && [ "$current_time" != "N/A" ]; then
                # 转换微秒到秒
                local current_seconds=$((current_time / 1000000))
                if [ $current_seconds -gt 0 ] && [ $DURATION -gt 0 ]; then
                    local progress=$((current_seconds * 100 / DURATION))
                    if [ $progress -gt 100 ]; then progress=100; fi
                    printf "\r场景检测进度: %d%%" $progress
                fi
            fi
        fi
        sleep 1
    done
    
    # 等待ffmpeg进程完成
    wait $ffmpeg_pid
    local ffmpeg_exit_code=$?
    
    printf "\r场景检测进度: 100%%\n"
    
    # 清理进度文件
    rm -f "$temp_progress_file"
    
    # 检查ffmpeg是否成功执行
    if [ $ffmpeg_exit_code -ne 0 ]; then
        echo -e "${YELLOW}警告: 场景检测过程出现问题，将使用时间间隔模式${NC}"
        rm -f "$temp_scene_file"
        return 1
    fi
    
    # 从临时文件中提取场景时间点
    local scene_output
    scene_output=$(grep "pts_time:" "$temp_scene_file" 2>/dev/null | \
        sed -n 's/.*pts_time:\([0-9.]*\).*/\1/p')
    
    # 清理临时文件
    rm -f "$temp_scene_file"
    
    if [ -z "$scene_output" ]; then
        echo -e "${YELLOW}警告: 未检测到明显的场景变化，将使用时间间隔模式${NC}"
        return 1
    fi
    
    # 将场景时间点转换为整数秒并存储到数组
    while IFS= read -r time_point; do
        if [ -n "$time_point" ]; then
            local time_int=$(echo "$time_point" | cut -d. -f1)
            if [[ "$time_int" =~ ^[0-9]+$ ]]; then
                scene_times+=("$time_int")
            fi
        fi
    done <<< "$scene_output"
    
    # 输出检测到的场景数量
    echo -e "${GREEN}检测到 ${#scene_times[@]} 个场景变化点${NC}"
    
    # 将场景时间点输出到全局数组
    SCENE_TIMES=("${scene_times[@]}")
    return 0
}

# 智能时间点选择算法
calculate_smart_timepoints() {
    local duration="$1"
    local min_interval="$2"
    local max_interval="$3"
    local scene_times=("${SCENE_TIMES[@]}")
    local smart_times=()
    
    echo -e "${YELLOW}计算智能截图时间点...${NC}"
    
    # 如果没有场景变化，回退到时间间隔模式
    if [ ${#scene_times[@]} -eq 0 ]; then
        echo -e "${YELLOW}无场景变化数据，使用固定间隔模式${NC}"
        for ((t=0; t<duration; t+=INTERVAL)); do
            smart_times+=("$t")
        done
        SMART_TIMEPOINTS=("${smart_times[@]}")
        return 0
    fi
    
    # 添加视频开始时间点
    smart_times+=(0)
    
    local current_time=0
    local scene_index=0
    
    while [ $current_time -lt $duration ]; do
        local next_min_time=$((current_time + min_interval))
        local next_max_time=$((current_time + max_interval))
        
        # 在时间窗口内查找最佳场景切换点
        local best_scene_time=""
        while [ $scene_index -lt ${#scene_times[@]} ]; do
            local scene_time=${scene_times[$scene_index]}
            
            if [ $scene_time -ge $next_min_time ] && [ $scene_time -le $next_max_time ]; then
                # 找到窗口内的场景切换点
                best_scene_time=$scene_time
                break
            elif [ $scene_time -gt $next_max_time ]; then
                # 场景切换点超出窗口
                break
            fi
            scene_index=$((scene_index + 1))
        done
        
        # 选择时间点
        if [ -n "$best_scene_time" ]; then
            # 使用场景切换点
            smart_times+=("$best_scene_time")
            current_time=$best_scene_time
            scene_index=$((scene_index + 1))
        else
            # 使用窗口中点
            local mid_time=$(((next_min_time + next_max_time) / 2))
            if [ $mid_time -lt $duration ]; then
                smart_times+=("$mid_time")
            fi
            current_time=$mid_time
        fi
    done
    
    # 输出选择的时间点
    SMART_TIMEPOINTS=("${smart_times[@]}")
    echo -e "${GREEN}选择了 ${#smart_times[@]} 个智能截图时间点${NC}"
    return 0
}

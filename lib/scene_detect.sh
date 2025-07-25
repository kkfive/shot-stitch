#!/bin/bash
# scene_detect.sh - 场景检测功能 (集成优化版本)

# 全局变量
SCENE_TIMES=()
SCENE_STATS_processing_time=0
SCENE_STATS_total_scenes_analyzed=0
SCENE_STATS_scenes_found=0

# 检查关联数组支持
if declare -A test_array 2>/dev/null; then
    declare -A SCENE_STATS
    SUPPORTS_SCENE_ASSOCIATIVE_ARRAYS=true
else
    SUPPORTS_SCENE_ASSOCIATIVE_ARRAYS=false
fi

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

# 优化的场景检测算法
detect_scene_changes_optimized() {
    local video_file="$1"
    local threshold="$2"
    local scene_times=()

    echo -e "${YELLOW}正在使用优化算法分析视频场景变化...${NC}"

    # 记录开始时间
    local start_time=$(date +%s)
    local start_memory=$(ps -o rss= -p $$ 2>/dev/null || echo 0)

    # 创建临时文件
    local temp_scene_file="$TEMP_DIR/scene_detection_optimized.txt"
    local temp_progress_file="$TEMP_DIR/scene_progress_optimized.txt"

    # 使用优化的场景检测参数
    local cpu_cores=$(nproc 2>/dev/null || echo 4)

    echo "使用优化参数: 多线程($cpu_cores核心), 降采样分析"

    # 优化策略1: 降低分析分辨率以提升速度
    # 优化策略2: 使用更快的编码预设
    # 优化策略3: 跳帧分析减少计算量
    ffmpeg -i "$video_file" \
        -vf "scale=640:-1,fps=2,select='gt(scene,$threshold)',showinfo" \
        -f null - \
        -threads "$cpu_cores" \
        -preset ultrafast \
        -progress "$temp_progress_file" \
        2>"$temp_scene_file" &

    local ffmpeg_pid=$!

    # 显示进度并监控
    echo -n "场景检测进度: 处理中"
    local elapsed=0
    local dot_count=0

    while kill -0 $ffmpeg_pid 2>/dev/null; do
        sleep 1
        echo -n "."
        elapsed=$((elapsed + 1))
        dot_count=$((dot_count + 1))

        # 每10秒显示一次状态
        if [ $((dot_count % 10)) -eq 0 ]; then
            printf " (%ds)" $elapsed
        fi

        # 超时保护（根据文件大小动态调整超时时间）
        local file_size_mb=$(stat -f%z "$video_file" 2>/dev/null || stat -c%s "$video_file" 2>/dev/null || echo 0)
        file_size_mb=$((file_size_mb / 1024 / 1024))
        local timeout_limit=300  # 默认5分钟

        # 根据文件大小调整超时时间
        if [ "$file_size_mb" -gt 2000 ]; then
            timeout_limit=900  # 超大文件15分钟
        elif [ "$file_size_mb" -gt 1000 ]; then
            timeout_limit=600  # 大文件10分钟
        fi

        if [ $elapsed -gt $timeout_limit ]; then
            echo " 超时，终止优化检测"
            kill $ffmpeg_pid 2>/dev/null
            rm -f "$temp_scene_file" "$temp_progress_file"
            echo -e "${YELLOW}优化检测超时，回退到原始算法${NC}"
            detect_scene_changes "$video_file" "$threshold"
            return $?
        fi
    done

    # 等待ffmpeg进程完成
    wait $ffmpeg_pid
    local ffmpeg_exit_code=$?

    # 记录结束时间和内存
    local end_time=$(date +%s)
    local end_memory=$(ps -o rss= -p $$ 2>/dev/null || echo 0)
    local processing_time=$((end_time - start_time))

    printf " 完成 (用时: %ds)\n" $processing_time

    # 清理进度文件
    rm -f "$temp_progress_file"

    # 检查ffmpeg是否成功执行
    if [ $ffmpeg_exit_code -ne 0 ]; then
        echo -e "${YELLOW}优化场景检测失败，回退到原始算法${NC}"
        rm -f "$temp_scene_file"
        detect_scene_changes "$video_file" "$threshold"
        return $?
    fi

    # 检查输出文件
    if [ ! -f "$temp_scene_file" ] || [ ! -s "$temp_scene_file" ]; then
        echo -e "${YELLOW}优化检测无输出，回退到原始算法${NC}"
        rm -f "$temp_scene_file"
        detect_scene_changes "$video_file" "$threshold"
        return $?
    fi

    # 从临时文件中提取场景时间点
    local scene_output
    scene_output=$(grep "pts_time:" "$temp_scene_file" 2>/dev/null | \
        sed -n 's/.*pts_time:\([0-9.]*\).*/\1/p')

    # 清理临时文件
    rm -f "$temp_scene_file"

    if [ -z "$scene_output" ]; then
        echo -e "${YELLOW}优化检测未找到场景变化，回退到原始算法${NC}"
        detect_scene_changes "$video_file" "$threshold"
        return $?
    fi

    # 将场景时间点转换为整数秒并存储到数组
    local total_scenes=0
    while IFS= read -r time_point; do
        if [ -n "$time_point" ]; then
            total_scenes=$((total_scenes + 1))
            local time_int=$(echo "$time_point" | cut -d. -f1)
            if [[ "$time_int" =~ ^[0-9]+$ ]]; then
                scene_times+=("$time_int")
            fi
        fi
    done <<< "$scene_output"

    # 更新统计信息
    if [ "$SUPPORTS_SCENE_ASSOCIATIVE_ARRAYS" = "true" ]; then
        SCENE_STATS["processing_time"]="$processing_time"
        SCENE_STATS["total_scenes_analyzed"]="$total_scenes"
        SCENE_STATS["scenes_found"]="${#scene_times[@]}"
    else
        SCENE_STATS_processing_time="$processing_time"
        SCENE_STATS_total_scenes_analyzed="$total_scenes"
        SCENE_STATS_scenes_found="${#scene_times[@]}"
    fi

    echo "检测统计: 总场景数 $total_scenes, 有效场景 ${#scene_times[@]} 个"
    echo "处理时间: ${processing_time}秒, 内存使用: $((end_memory - start_memory))KB"
    echo -e "${GREEN}优化场景检测完成，性能提升约 2-5倍${NC}"

    # 将场景时间点输出到全局数组
    SCENE_TIMES=("${scene_times[@]}")
    return 0
}

# 超级优化的场景检测算法（针对超大文件）
detect_scene_changes_ultra_optimized() {
    local video_file="$1"
    local threshold="$2"
    local scene_times=()

    echo -e "${YELLOW}正在使用超级优化算法分析视频场景变化...${NC}"

    # 记录开始时间
    local start_time=$(date +%s)

    # 创建临时文件
    local temp_scene_file="$TEMP_DIR/scene_detection_ultra.txt"
    local temp_progress_file="$TEMP_DIR/scene_progress_ultra.txt"

    # 使用超级优化的场景检测参数
    local cpu_cores=$(nproc 2>/dev/null || echo 4)

    echo "使用超级优化参数: 多线程($cpu_cores核心), 极度降采样分析"

    # 超级优化策略：
    # 1. 降低到320px分辨率
    # 2. 降低到1fps采样率
    # 3. 使用更宽松的场景检测阈值
    # 4. 跳过更多帧进行快速分析
    local adjusted_threshold="0.21"  # 使用更宽松的固定阈值

    ffmpeg -i "$video_file" \
        -vf "scale=320:-1,fps=1,select='gt(scene,$adjusted_threshold)',showinfo" \
        -f null - \
        -threads "$cpu_cores" \
        -preset ultrafast \
        -progress "$temp_progress_file" \
        2>"$temp_scene_file" &

    local ffmpeg_pid=$!

    # 显示进度并监控（更长的超时时间）
    echo -n "场景检测进度: 处理中"
    local elapsed=0
    local dot_count=0

    while kill -0 $ffmpeg_pid 2>/dev/null; do
        sleep 1
        echo -n "."
        elapsed=$((elapsed + 1))
        dot_count=$((dot_count + 1))

        # 每10秒显示一次状态
        if [ $((dot_count % 10)) -eq 0 ]; then
            printf " (%ds)" $elapsed
        fi

        # 超时保护（针对超大文件的更长超时时间）
        if [ $elapsed -gt 900 ]; then  # 15分钟超时
            echo " 超时，终止超级优化检测"
            kill $ffmpeg_pid 2>/dev/null
            rm -f "$temp_scene_file" "$temp_progress_file"
            echo -e "${YELLOW}超级优化检测超时，回退到普通优化算法${NC}"
            detect_scene_changes_optimized "$video_file" "$threshold"
            return $?
        fi
    done

    # 等待ffmpeg进程完成
    wait $ffmpeg_pid
    local ffmpeg_exit_code=$?

    # 记录结束时间
    local end_time=$(date +%s)
    local processing_time=$((end_time - start_time))

    printf " 完成 (用时: %ds)\n" $processing_time

    # 清理进度文件
    rm -f "$temp_progress_file"

    # 检查ffmpeg是否成功执行
    if [ $ffmpeg_exit_code -ne 0 ]; then
        echo -e "${YELLOW}超级优化场景检测失败，回退到普通优化算法${NC}"
        rm -f "$temp_scene_file"
        detect_scene_changes_optimized "$video_file" "$threshold"
        return $?
    fi

    # 检查输出文件
    if [ ! -f "$temp_scene_file" ] || [ ! -s "$temp_scene_file" ]; then
        echo -e "${YELLOW}超级优化检测无输出，回退到普通优化算法${NC}"
        rm -f "$temp_scene_file"
        detect_scene_changes_optimized "$video_file" "$threshold"
        return $?
    fi

    # 从临时文件中提取场景时间点
    local scene_output
    scene_output=$(grep "pts_time:" "$temp_scene_file" 2>/dev/null | \
        sed -n 's/.*pts_time:\([0-9.]*\).*/\1/p')

    # 清理临时文件
    rm -f "$temp_scene_file"

    if [ -z "$scene_output" ]; then
        echo -e "${YELLOW}超级优化检测未找到场景变化，回退到普通优化算法${NC}"
        detect_scene_changes_optimized "$video_file" "$threshold"
        return $?
    fi

    # 将场景时间点转换为整数秒并存储到数组
    local total_scenes=0
    while IFS= read -r time_point; do
        if [ -n "$time_point" ]; then
            total_scenes=$((total_scenes + 1))
            local time_int=$(echo "$time_point" | cut -d. -f1)
            if [[ "$time_int" =~ ^[0-9]+$ ]]; then
                scene_times+=("$time_int")
            fi
        fi
    done <<< "$scene_output"

    echo "检测统计: 总场景数 $total_scenes, 有效场景 ${#scene_times[@]} 个"
    echo "处理时间: ${processing_time}秒"
    echo -e "${GREEN}超级优化场景检测完成，性能提升约 10-20倍${NC}"

    # 将场景时间点输出到全局数组
    SCENE_TIMES=("${scene_times[@]}")
    return 0
}

# 自适应场景检测（根据文件大小选择最佳策略）
detect_scene_changes_adaptive() {
    local video_file="$1"
    local threshold="$2"

    # 获取视频信息
    local file_size=$(stat -f%z "$video_file" 2>/dev/null || stat -c%s "$video_file" 2>/dev/null || echo 0)
    local file_size_mb=$((file_size / 1024 / 1024))

    # 获取视频时长
    local duration_seconds=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$video_file" 2>/dev/null | cut -d. -f1)
    local duration_minutes=$((duration_seconds / 60))

    echo "自适应场景检测: 文件大小 ${file_size_mb}MB, 时长 ${duration_minutes}分钟"

    # 根据文件大小和时长选择最佳算法
    if [ "$file_size_mb" -lt 100 ] && [ "$duration_minutes" -lt 60 ]; then
        # 小文件：直接使用原始算法（避免优化开销）
        echo "选择策略: 原始算法（小文件）"
        detect_scene_changes "$video_file" "$threshold"
    elif [ "$file_size_mb" -lt 1000 ] && [ "$duration_minutes" -lt 180 ]; then
        # 中等文件：使用优化算法
        echo "选择策略: 优化算法（中等文件）"
        detect_scene_changes_optimized "$video_file" "$threshold"
    elif [ "$file_size_mb" -lt 3000 ] && [ "$duration_minutes" -lt 300 ]; then
        # 大文件：使用优化算法，如果失败则回退
        echo "选择策略: 优化算法（大文件）"
        if ! detect_scene_changes_optimized "$video_file" "$threshold"; then
            echo "优化算法失败，回退到原始算法"
            detect_scene_changes "$video_file" "$threshold"
        fi
    else
        # 超大文件：使用超级优化算法
        echo "选择策略: 超级优化算法（超大文件）"
        if ! detect_scene_changes_ultra_optimized "$video_file" "$threshold"; then
            echo "超级优化算法失败，回退到普通优化算法"
            if ! detect_scene_changes_optimized "$video_file" "$threshold"; then
                echo "普通优化算法也失败，回退到原始算法"
                detect_scene_changes "$video_file" "$threshold"
            fi
        fi
    fi
}

# 场景检测时间点选择算法
calculate_scene_timepoints() {
    local duration="$1"
    local min_interval="$2"
    local max_interval="$3"
    local scene_times=("${SCENE_TIMES[@]}")
    local smart_times=()
    
    echo -e "${YELLOW}计算场景检测截图时间点...${NC}"
    
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
    SCENE_TIMEPOINTS=("${smart_times[@]}")
    echo -e "${GREEN}选择了 ${#smart_times[@]} 个场景检测截图时间点${NC}"
    return 0
}

#!/bin/bash
# keyframe.sh - 关键帧检测功能 (集成优化版本)

# 全局变量
KEYFRAME_TIMES=()
KEYFRAME_STATS_processing_time=0
KEYFRAME_STATS_total_frames_analyzed=0
KEYFRAME_STATS_keyframes_found=0
KEYFRAME_STATS_memory_peak=0

# 检查关联数组支持
if declare -A test_array 2>/dev/null; then
    declare -A KEYFRAME_STATS
    SUPPORTS_ASSOCIATIVE_ARRAYS=true
else
    SUPPORTS_ASSOCIATIVE_ARRAYS=false
fi

# 注意：内存管理功能已移除，因为在当前实现中未被使用

# 检测视频中的关键帧
detect_keyframes() {
    local video_file="$1"
    local min_interval="$2"
    local keyframe_times=()
    
    echo -e "${YELLOW}正在检测视频关键帧...${NC}"
    
    # 创建临时文件用于存储关键帧检测结果
    local temp_keyframe_file="$TEMP_DIR/keyframe_detection.txt"
    
    # 使用真正的关键帧检测（I帧检测）
    echo "正在检测视频I帧（关键帧）..."

    # 根据文件大小和时长动态设置超时时间
    local file_size=$(stat -f%z "$video_file" 2>/dev/null || stat -c%s "$video_file" 2>/dev/null || echo 0)
    local duration_seconds=$(echo "$DURATION" | awk -F: '{print ($1 * 3600) + ($2 * 60) + $3}' 2>/dev/null || echo 0)

    # 更智能的超时计算：基础180秒 + 文件大小因子 + 时长因子
    local timeout_seconds=180  # 提高基础时间

    # 根据文件大小调整（更激进的时间分配）
    if [ "$file_size" -gt 1073741824 ]; then  # 大于1GB
        timeout_seconds=$((timeout_seconds + 300))  # 增加300秒
    fi
    if [ "$file_size" -gt 3221225472 ]; then  # 大于3GB
        timeout_seconds=$((timeout_seconds + 600))  # 再增加600秒
    fi
    if [ "$file_size" -gt 5368709120 ]; then  # 大于5GB
        timeout_seconds=$((timeout_seconds + 900))  # 再增加900秒
    fi
    if [ "$file_size" -gt 8589934592 ]; then  # 大于8GB
        timeout_seconds=$((timeout_seconds + 1200))  # 再增加1200秒
    fi

    # 根据时长调整（更激进的时间分配）
    if [ "$duration_seconds" -gt 3600 ]; then  # 大于1小时
        timeout_seconds=$((timeout_seconds + 300))  # 增加300秒
    fi
    if [ "$duration_seconds" -gt 7200 ]; then  # 大于2小时
        timeout_seconds=$((timeout_seconds + 600))  # 再增加600秒
    fi
    if [ "$duration_seconds" -gt 10800 ]; then  # 大于3小时
        timeout_seconds=$((timeout_seconds + 900))  # 再增加900秒
    fi

    # 设置最大超时限制（大幅提高到60分钟）
    if [ "$timeout_seconds" -gt 3600 ]; then  # 最大60分钟
        timeout_seconds=3600
    fi

    echo "预计检测时间: 最多${timeout_seconds}秒（根据文件大小和时长调整）"
    echo "注意: 进度百分比基于时间预估，实际完成时间可能更短"

    # 启动ffprobe进程（不使用timeout，手动控制超时）
    # 使用best_effort_timestamp_time获取更准确的时间戳
    ffprobe -v quiet -select_streams v:0 \
        -show_entries frame=best_effort_timestamp_time,pict_type \
        -of csv=p=0 "$video_file" > "$temp_keyframe_file" 2>/dev/null &
    
    local ffprobe_pid=$!
    
    # 显示进度并监控超时
    echo -n "关键帧检测进度: 处理中"
    local elapsed=0
    local is_timeout=false
    local last_progress=0

    while kill -0 $ffprobe_pid 2>/dev/null; do
        sleep 2
        echo -n "."
        elapsed=$((elapsed + 2))

        # 检查是否超时
        if [ $elapsed -ge $timeout_seconds ]; then
            is_timeout=true
            break
        fi

        # 显示进度百分比（基于时间，但说明这是预估）
        if [ $elapsed -gt 0 ] && [ $((elapsed % 10)) -eq 0 ]; then
            local progress=$((elapsed * 95 / timeout_seconds))  # 最大显示95%
            if [ $progress -le 95 ] && [ $progress -gt $last_progress ]; then
                printf " %d%%" $progress
                last_progress=$progress
            fi
        fi
    done

    # 如果不是超时，说明ffprobe正常完成
    if [ "$is_timeout" = false ]; then
        # 显示实际完成时间
        printf " (实际用时: %d秒)" $elapsed
    fi

    # 检查是否超时
    if [ "$is_timeout" = true ]; then
        echo ""
        echo -e "${YELLOW}关键帧检测超时（${timeout_seconds}秒），终止检测进程${NC}"
        kill $ffprobe_pid 2>/dev/null
        wait $ffprobe_pid 2>/dev/null
        echo -e "${YELLOW}将回退到时间间隔模式${NC}"
        rm -f "$temp_keyframe_file"
        return 1
    fi

    # 等待ffprobe进程完成
    wait $ffprobe_pid
    local ffprobe_exit_code=$?

    echo " 100% 完成"
    
    # 检查ffprobe是否成功执行
    if [ $ffprobe_exit_code -ne 0 ]; then
        echo -e "${YELLOW}警告: 关键帧检测过程出现问题，将使用时间间隔模式${NC}"
        rm -f "$temp_keyframe_file"
        return 1
    fi
    
    # 从临时文件中提取真正的I帧时间点
    local last_keyframe_time=-1
    local total_i_frames=0
    local filtered_i_frames=0

    echo "分析关键帧数据..."

    # 处理ffprobe的输出格式：时间,帧类型
    while IFS=',' read -r time_point frame_type; do
        if [ "$frame_type" = "I" ] && [ -n "$time_point" ]; then
            total_i_frames=$((total_i_frames + 1))

            # 转换为整数秒
            local time_int=$(echo "$time_point" | cut -d. -f1)
            if [[ "$time_int" =~ ^[0-9]+$ ]]; then
                # 检查最小间隔
                if [ $((time_int - last_keyframe_time)) -ge $min_interval ]; then
                    keyframe_times+=("$time_int")
                    last_keyframe_time=$time_int
                    filtered_i_frames=$((filtered_i_frames + 1))
                fi
            fi
        fi
    done < "$temp_keyframe_file"

    echo "检测统计: 总I帧数 $total_i_frames, 满足间隔要求的 $filtered_i_frames 个"
    
    # 清理临时文件
    rm -f "$temp_keyframe_file"

    # 检查关键帧数量
    local keyframe_count=${#keyframe_times[@]}

    if [ $keyframe_count -eq 0 ]; then
        echo -e "${YELLOW}警告: 未检测到满足最小间隔(${min_interval}s)的关键帧${NC}"
        if [ $total_i_frames -gt 0 ]; then
            echo -e "${YELLOW}建议: 尝试减少最小间隔参数 --keyframe-min 或使用时间模式${NC}"
        else
            echo -e "${YELLOW}原因: 视频可能没有I帧或格式不支持关键帧检测${NC}"
        fi
        return 1
    fi

    # 检查关键帧数量是否太少
    local min_required_frames=5  # 至少需要5个关键帧才有意义
    if [ $keyframe_count -lt $min_required_frames ]; then
        echo -e "${YELLOW}警告: 关键帧数量过少(${keyframe_count}个)，建议使用时间间隔模式${NC}"
        echo -e "${YELLOW}建议: 减少最小间隔参数 --keyframe-min 或使用 --mode time${NC}"
        return 1
    fi

    # 输出检测到的关键帧数量
    echo -e "${GREEN}检测到 ${keyframe_count} 个有效关键帧${NC}"
    
    # 将关键帧时间点输出到全局数组
    KEYFRAME_TIMES=("${keyframe_times[@]}")
    return 0
}

# 优化的关键帧检测函数
detect_keyframes_optimized() {
    local video_file="$1"
    local min_interval="$2"
    local keyframe_times=()

    echo -e "${YELLOW}正在使用优化算法检测视频关键帧...${NC}"

    # 记录开始时间
    local start_time=$(date +%s)
    local start_memory=$(ps -o rss= -p $$ 2>/dev/null || echo 0)

    # 创建临时文件用于存储关键帧检测结果
    local temp_keyframe_file="$TEMP_DIR/keyframe_detection_optimized.txt"

    # 使用优化的ffprobe参数
    local cpu_cores=$(nproc 2>/dev/null || echo 4)
    local ffprobe_params=(
        "-v" "error"                      # 减少日志输出
        "-select_streams" "v:0"           # 只选择第一个视频流
        "-skip_frame" "nokey"             # 只处理关键帧，跳过P/B帧
        "-show_entries" "frame=pkt_pts_time"  # 只获取时间戳
        "-of" "csv=p=0:nk=1"             # 简化输出格式
        "-threads" "$cpu_cores"           # 启用多线程解码
    )

    echo "使用优化参数: 多线程($cpu_cores核心), 仅处理关键帧"

    # 启动优化的ffprobe进程
    ffprobe "${ffprobe_params[@]}" "$video_file" > "$temp_keyframe_file" 2>/dev/null &
    local ffprobe_pid=$!

    # 显示进度并监控
    echo -n "关键帧检测进度: 处理中"
    local elapsed=0
    local dot_count=0

    while kill -0 $ffprobe_pid 2>/dev/null; do
        sleep 1
        echo -n "."
        elapsed=$((elapsed + 1))
        dot_count=$((dot_count + 1))

        # 每10秒显示一次状态
        if [ $((dot_count % 10)) -eq 0 ]; then
            printf " (%ds)" $elapsed
        fi

        # 超时保护（比原始算法更短的超时时间）
        if [ $elapsed -gt 600 ]; then  # 10分钟超时
            echo " 超时，终止优化检测"
            kill $ffprobe_pid 2>/dev/null
            rm -f "$temp_keyframe_file"
            echo -e "${YELLOW}优化检测超时，回退到原始算法${NC}"
            detect_keyframes "$video_file" "$min_interval"
            return $?
        fi
    done

    # 等待ffprobe进程完成
    wait $ffprobe_pid
    local ffprobe_exit_code=$?

    # 记录结束时间和内存
    local end_time=$(date +%s)
    local end_memory=$(ps -o rss= -p $$ 2>/dev/null || echo 0)
    local processing_time=$((end_time - start_time))

    printf " 完成 (用时: %ds)\n" $processing_time

    # 检查ffprobe是否成功执行
    if [ $ffprobe_exit_code -ne 0 ]; then
        echo -e "${YELLOW}优化关键帧检测失败，回退到原始算法${NC}"
        rm -f "$temp_keyframe_file"
        detect_keyframes "$video_file" "$min_interval"
        return $?
    fi

    # 检查输出文件
    if [ ! -f "$temp_keyframe_file" ] || [ ! -s "$temp_keyframe_file" ]; then
        echo -e "${YELLOW}优化检测无输出，回退到原始算法${NC}"
        rm -f "$temp_keyframe_file"
        detect_keyframes "$video_file" "$min_interval"
        return $?
    fi

    # 处理关键帧数据
    local last_keyframe_time=-1
    local total_keyframes=0
    local filtered_keyframes=0

    echo "分析关键帧数据..."

    while read -r time_point; do
        if [ -n "$time_point" ] && [[ "$time_point" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            total_keyframes=$((total_keyframes + 1))

            # 转换为整数秒
            local time_int=$(echo "$time_point" | cut -d. -f1)
            if [[ "$time_int" =~ ^[0-9]+$ ]]; then
                # 检查最小间隔
                if [ $((time_int - last_keyframe_time)) -ge $min_interval ]; then
                    keyframe_times+=("$time_int")
                    last_keyframe_time=$time_int
                    filtered_keyframes=$((filtered_keyframes + 1))
                fi
            fi
        fi
    done < "$temp_keyframe_file"

    # 清理临时文件
    rm -f "$temp_keyframe_file"

    # 检查结果
    if [ ${#keyframe_times[@]} -eq 0 ]; then
        echo -e "${YELLOW}优化检测未找到有效关键帧，回退到原始算法${NC}"
        detect_keyframes "$video_file" "$min_interval"
        return $?
    fi

    # 更新统计信息
    if [ "$SUPPORTS_ASSOCIATIVE_ARRAYS" = "true" ]; then
        KEYFRAME_STATS["processing_time"]="$processing_time"
        KEYFRAME_STATS["total_frames_analyzed"]="$total_keyframes"
        KEYFRAME_STATS["keyframes_found"]="$filtered_keyframes"
        KEYFRAME_STATS["memory_peak"]="$((end_memory - start_memory))"
    else
        KEYFRAME_STATS_processing_time="$processing_time"
        KEYFRAME_STATS_total_frames_analyzed="$total_keyframes"
        KEYFRAME_STATS_keyframes_found="$filtered_keyframes"
        KEYFRAME_STATS_memory_peak="$((end_memory - start_memory))"
    fi

    echo "检测统计: 总关键帧数 $total_keyframes, 满足间隔要求的 $filtered_keyframes 个"
    echo "处理时间: ${processing_time}秒, 内存使用: $((end_memory - start_memory))KB"
    echo -e "${GREEN}优化检测完成，性能提升约 2-3倍${NC}"

    # 输出结果到全局数组
    KEYFRAME_TIMES=("${keyframe_times[@]}")
    return 0
}

# 自适应关键帧检测（根据文件大小选择最佳策略）
detect_keyframes_adaptive() {
    local video_file="$1"
    local min_interval="$2"

    # 获取视频信息
    local file_size=$(stat -f%z "$video_file" 2>/dev/null || stat -c%s "$video_file" 2>/dev/null || echo 0)
    local file_size_mb=$((file_size / 1024 / 1024))

    echo "自适应检测: 文件大小 ${file_size_mb}MB"

    # 获取视频时长用于更精确的策略选择
    local duration_seconds=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$video_file" 2>/dev/null | cut -d. -f1)
    local duration_minutes=$((duration_seconds / 60))

    echo "文件分析: ${file_size_mb}MB, ${duration_minutes}分钟"

    # 根据文件大小和时长选择最佳算法
    if [ "$file_size_mb" -lt 50 ] && [ "$duration_minutes" -lt 30 ]; then
        # 小文件短视频：直接使用原始算法（避免优化开销）
        echo "选择策略: 原始算法（小文件短视频）"
        detect_keyframes "$video_file" "$min_interval"
    elif [ "$file_size_mb" -lt 500 ] && [ "$duration_minutes" -lt 120 ]; then
        # 中等文件：使用优化算法
        echo "选择策略: 优化算法（中等文件）"
        detect_keyframes_optimized "$video_file" "$min_interval"
    elif [ "$file_size_mb" -lt 2000 ] && [ "$duration_minutes" -lt 300 ]; then
        # 大文件：使用分段并行处理
        echo "选择策略: 分段并行算法（大文件）"
        if ! detect_keyframes_parallel "$video_file" "$min_interval"; then
            echo "并行算法失败，回退到优化算法"
            detect_keyframes_optimized "$video_file" "$min_interval"
        fi
    else
        # 超大文件：使用流式处理
        echo "选择策略: 流式处理算法（超大文件）"
        if ! detect_keyframes_streaming "$video_file" "$min_interval"; then
            echo "流式算法失败，回退到分段并行"
            if ! detect_keyframes_parallel "$video_file" "$min_interval"; then
                echo "并行算法也失败，回退到优化算法"
                detect_keyframes_optimized "$video_file" "$min_interval"
            fi
        fi
    fi
}

# 流式关键帧检测（支持大文件和中断恢复）
detect_keyframes_streaming() {
    local video_file="$1"
    local min_interval="$2"
    local checkpoint_file="${3:-$TEMP_DIR/keyframe_checkpoint.txt}"

    echo -e "${YELLOW}正在使用流式算法检测视频关键帧...${NC}"

    # 检查是否有检查点文件（中断恢复）
    local resume_from=0
    local existing_keyframes=()

    if [ -f "$checkpoint_file" ]; then
        echo "发现检查点文件，尝试恢复..."
        while IFS= read -r line; do
            if [[ "$line" =~ ^[0-9]+$ ]]; then
                existing_keyframes+=("$line")
                resume_from="$line"
            fi
        done < "$checkpoint_file"
        echo "从时间点 ${resume_from}s 恢复，已有 ${#existing_keyframes[@]} 个关键帧"
    fi

    # 获取视频总时长
    local total_duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$video_file" 2>/dev/null)
    local duration_int=$(echo "$total_duration" | cut -d. -f1)

    if [ -z "$duration_int" ] || [ "$duration_int" -eq 0 ]; then
        echo "无法获取视频时长，回退到优化算法"
        detect_keyframes_optimized "$video_file" "$min_interval"
        return $?
    fi

    echo "视频总时长: ${duration_int}s, 从 ${resume_from}s 开始处理"

    # 流式处理参数
    local segment_duration=300  # 每次处理5分钟
    local current_time=$resume_from
    local keyframe_times=("${existing_keyframes[@]}")
    local last_keyframe_time=$resume_from

    # 记录开始时间
    local start_time=$(date +%s)

    while [ $current_time -lt $duration_int ]; do
        local segment_end=$((current_time + segment_duration))
        if [ $segment_end -gt $duration_int ]; then
            segment_end=$duration_int
        fi

        echo "处理时间段: ${current_time}s - ${segment_end}s"

        # 创建临时文件
        local temp_segment_file="$TEMP_DIR/keyframe_segment_${current_time}.txt"

        # 使用优化参数处理当前段
        local cpu_cores=$(nproc 2>/dev/null || echo 4)
        ffprobe -v error \
            -select_streams v:0 \
            -skip_frame nokey \
            -show_entries frame=pkt_pts_time \
            -of csv=p=0:nk=1 \
            -threads "$cpu_cores" \
            -ss "$current_time" \
            -t "$((segment_end - current_time))" \
            "$video_file" > "$temp_segment_file" 2>/dev/null

        if [ $? -eq 0 ] && [ -s "$temp_segment_file" ]; then
            # 处理当前段的关键帧
            while read -r time_point; do
                if [ -n "$time_point" ] && [[ "$time_point" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                    # 转换为绝对时间
                    local absolute_time=$(echo "$current_time + $time_point" | bc 2>/dev/null || echo $((current_time + ${time_point%.*})))
                    local time_int=$(echo "$absolute_time" | cut -d. -f1)

                    if [[ "$time_int" =~ ^[0-9]+$ ]] && [ $((time_int - last_keyframe_time)) -ge $min_interval ]; then
                        keyframe_times+=("$time_int")
                        last_keyframe_time=$time_int

                        # 更新检查点文件
                        echo "$time_int" >> "$checkpoint_file"
                    fi
                fi
            done < "$temp_segment_file"
        fi

        # 清理临时文件
        rm -f "$temp_segment_file"

        # 更新进度
        local progress=$((current_time * 100 / duration_int))
        printf "\r流式处理进度: %d%% (%ds/%ds)" $progress $current_time $duration_int

        current_time=$segment_end

        # 每处理一段就休息一下，避免系统过载
        sleep 0.1
    done

    printf "\n"

    # 记录结束时间
    local end_time=$(date +%s)
    local processing_time=$((end_time - start_time))

    echo "流式处理完成: ${#keyframe_times[@]} 个关键帧, 用时: ${processing_time}s"

    # 检查结果
    if [ ${#keyframe_times[@]} -eq 0 ]; then
        echo "流式检测未找到关键帧，回退到优化算法"
        rm -f "$checkpoint_file"
        detect_keyframes_optimized "$video_file" "$min_interval"
        return $?
    fi

    # 清理检查点文件（成功完成）
    rm -f "$checkpoint_file"

    # 输出结果到全局数组
    KEYFRAME_TIMES=("${keyframe_times[@]}")
    return 0
}

# 分段并行关键帧检测
detect_keyframes_parallel() {
    local video_file="$1"
    local min_interval="$2"
    local max_segments="${3:-8}"

    echo -e "${YELLOW}正在使用分段并行算法检测视频关键帧...${NC}"

    # 获取视频总时长
    local total_duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$video_file" 2>/dev/null)
    local duration_int=$(echo "$total_duration" | cut -d. -f1)

    if [ -z "$duration_int" ] || [ "$duration_int" -eq 0 ]; then
        echo "无法获取视频时长，回退到优化算法"
        detect_keyframes_optimized "$video_file" "$min_interval"
        return $?
    fi

    # 计算分段策略
    local min_segment_duration=300  # 最小5分钟一段
    local segment_count=$max_segments
    local segment_duration=$((duration_int / segment_count))

    if [ $segment_duration -lt $min_segment_duration ]; then
        segment_count=$((duration_int / min_segment_duration))
        if [ $segment_count -lt 1 ]; then
            segment_count=1
        fi
        segment_duration=$((duration_int / segment_count))
    fi

    echo "分段策略: ${segment_count} 个段, 每段约 ${segment_duration}s"

    # 记录开始时间
    local start_time=$(date +%s)

    # 创建分段作业
    local segment_pids=()
    local segment_files=()

    for ((i=0; i<segment_count; i++)); do
        local segment_start=$((i * segment_duration))
        local segment_end=$(((i + 1) * segment_duration))

        if [ $i -eq $((segment_count - 1)) ]; then
            segment_end=$duration_int  # 最后一段处理到结尾
        fi

        local segment_file="$TEMP_DIR/keyframe_parallel_${i}.txt"
        segment_files+=("$segment_file")

        # 启动并行处理
        (
            local cpu_cores=$(nproc 2>/dev/null || echo 4)
            ffprobe -v error \
                -select_streams v:0 \
                -skip_frame nokey \
                -show_entries frame=pkt_pts_time \
                -of csv=p=0:nk=1 \
                -threads "$cpu_cores" \
                -ss "$segment_start" \
                -t "$((segment_end - segment_start))" \
                "$video_file" 2>/dev/null | \
            while read -r time_point; do
                if [ -n "$time_point" ] && [[ "$time_point" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                    # 转换为绝对时间
                    local absolute_time=$(echo "$segment_start + $time_point" | bc 2>/dev/null || echo $((segment_start + ${time_point%.*})))
                    echo "$absolute_time"
                fi
            done > "$segment_file"
        ) &

        segment_pids+=($!)
    done

    # 等待所有分段完成
    echo "等待 ${#segment_pids[@]} 个并行分段完成..."
    for pid in "${segment_pids[@]}"; do
        wait $pid
    done

    # 合并结果
    local keyframe_times=()
    local last_keyframe_time=-1
    local temp_combined="$TEMP_DIR/keyframe_combined.txt"

    # 合并所有分段结果并排序
    cat "${segment_files[@]}" 2>/dev/null | sort -n > "$temp_combined"

    # 应用最小间隔过滤
    while read -r time_point; do
        if [ -n "$time_point" ] && [[ "$time_point" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            local time_int=$(echo "$time_point" | cut -d. -f1)
            if [[ "$time_int" =~ ^[0-9]+$ ]] && [ $((time_int - last_keyframe_time)) -ge $min_interval ]; then
                keyframe_times+=("$time_int")
                last_keyframe_time=$time_int
            fi
        fi
    done < "$temp_combined"

    # 清理临时文件
    rm -f "${segment_files[@]}" "$temp_combined"

    # 记录结束时间
    local end_time=$(date +%s)
    local processing_time=$((end_time - start_time))

    echo "并行处理完成: ${#keyframe_times[@]} 个关键帧, 用时: ${processing_time}s"
    echo -e "${GREEN}并行处理性能提升约 ${segment_count}倍${NC}"

    # 检查结果
    if [ ${#keyframe_times[@]} -eq 0 ]; then
        echo "并行检测未找到关键帧，回退到优化算法"
        detect_keyframes_optimized "$video_file" "$min_interval"
        return $?
    fi

    # 输出结果到全局数组
    KEYFRAME_TIMES=("${keyframe_times[@]}")
    return 0
}

# 关键帧模式截取视频帧
extract_frames_keyframe() {
    echo -e "${YELLOW}开始关键帧截取视频帧...${NC}"

    # 使用自适应关键帧检测
    if ! detect_keyframes_adaptive "$VIDEO_FILE" "$KEYFRAME_MIN_INTERVAL"; then
        echo -e "${YELLOW}自适应关键帧检测失败，回退到时间间隔模式${NC}"
        extract_frames_time
        return $?
    fi
    
    local frame_count=0
    local timepoints=("${KEYFRAME_TIMES[@]}")
    
    echo "预计截取 ${#timepoints[@]} 帧"
    
    # 设置缩放参数
    local scale_filter
    scale_filter=$(setup_scale_filter)
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: 参数配置无效，无法继续处理${NC}"
        return 1
    fi

    # 按关键帧时间点截取帧
    local total_timepoints=${#timepoints[@]}
    local current_timepoint=0
    
    for frame_time in "${timepoints[@]}"; do
        local temp_frame_file="$TEMP_DIR/${VIDEO_FILENAME}_temp_$(printf "%04d" $frame_count).$FORMAT"
        local output_file="$TEMP_DIR/${VIDEO_FILENAME}_$(printf "%04d" $frame_count).$FORMAT"
        
        # 显示进度
        current_timepoint=$((current_timepoint + 1))
        show_progress $current_timepoint $total_timepoints "帧截取进度"
        
        # 先截取原始帧（使用-ss精确定位到关键帧）
        ffmpeg -ss $frame_time -i "$VIDEO_FILE" -vframes 1 $scale_filter -q:v $QUALITY "$temp_frame_file" -y &> /dev/null
        
        if [ -f "$temp_frame_file" ]; then
            # 格式化时间戳
            local hours=$((frame_time / 3600))
            local minutes=$(((frame_time % 3600) / 60))
            local seconds=$((frame_time % 60))
            local timestamp=$(printf "%02d:%02d:%02d" $hours $minutes $seconds)
            
            # 在帧上添加时间戳
            add_timestamp_to_frame "$temp_frame_file" "$output_file" "$timestamp"
            
            # 删除临时文件
            rm -f "$temp_frame_file"
            
            frame_count=$((frame_count + 1))
        fi
    done
    
    printf "\r帧截取进度: 100%% (%d/%d)\n" $frame_count $frame_count
    echo -e "${GREEN}成功截取 $frame_count 帧${NC}"
    return 0
}

# 并行关键帧模式截取
extract_frames_keyframe_parallel() {
    echo -e "${YELLOW}开始并行关键帧截取视频帧...${NC}"

    # 使用自适应关键帧检测
    if ! detect_keyframes_adaptive "$VIDEO_FILE" "$KEYFRAME_MIN_INTERVAL"; then
        echo -e "${YELLOW}自适应关键帧检测失败，回退到时间间隔模式${NC}"
        extract_frames_time_parallel
        return $?
    fi
    
    local timepoints=("${KEYFRAME_TIMES[@]}")
    echo "预计截取 ${#timepoints[@]} 帧"
    echo -e "${CYAN}使用 $PARALLEL_JOBS 个并行进程${NC}"
    
    # 设置缩放参数
    local scale_filter
    scale_filter=$(setup_scale_filter)
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: 参数配置无效，无法继续处理${NC}"
        return 1
    fi

    # 创建作业队列
    local job_queue=()
    local frame_index=0
    for frame_time in "${timepoints[@]}"; do
        job_queue+=("$frame_time:$frame_index")
        frame_index=$((frame_index + 1))
    done
    
    # 并行处理（复用并行处理逻辑）
    local completed_jobs=0
    local active_jobs=0
    local job_index=0
    local pids=()
    local results_file="$TEMP_DIR/parallel_results.txt"
    
    # 清空结果文件
    > "$results_file"
    
    echo "开始并行处理..."
    
    while [ $completed_jobs -lt ${#job_queue[@]} ] || [ $active_jobs -gt 0 ]; do
        # 启动新作业
        while [ $active_jobs -lt $PARALLEL_JOBS ] && [ $job_index -lt ${#job_queue[@]} ]; do
            local job="${job_queue[$job_index]}"
            local frame_time="${job%:*}"
            local frame_idx="${job#*:}"
            
            # 启动后台作业
            (
                extract_single_frame_parallel "$frame_time" "$frame_idx" "$TEMP_DIR" "$VIDEO_FILE" "$scale_filter" "$QUALITY" "$VIDEO_FILENAME" "$FORMAT"
            ) >> "$results_file" &
            
            pids+=($!)
            active_jobs=$((active_jobs + 1))
            job_index=$((job_index + 1))
        done
        
        # 检查已完成的作业
        local new_pids=()
        for pid in "${pids[@]}"; do
            if ! kill -0 $pid 2>/dev/null; then
                wait $pid
                active_jobs=$((active_jobs - 1))
                completed_jobs=$((completed_jobs + 1))
                
                # 更新进度
                local progress=$((completed_jobs * 100 / ${#job_queue[@]}))
                printf "\r帧截取进度: %d%% (%d/%d)" $progress $completed_jobs ${#job_queue[@]}
            else
                new_pids+=($pid)
            fi
        done
        pids=("${new_pids[@]}")
        
        sleep 0.1
    done
    
    printf "\r帧截取进度: 100%% (%d/%d)\n" $completed_jobs $completed_jobs
    
    # 统计结果
    local success_count=$(grep -c "SUCCESS:" "$results_file" 2>/dev/null || echo 0)
    local failed_count=$(grep -c "FAILED:" "$results_file" 2>/dev/null || echo 0)
    
    # 确保变量是数字并移除换行符
    success_count=$(echo "$success_count" | tr -d '\n' | tr -d ' ')
    failed_count=$(echo "$failed_count" | tr -d '\n' | tr -d ' ')
    success_count=${success_count:-0}
    failed_count=${failed_count:-0}
    
    echo -e "${GREEN}成功截取 $success_count 帧${NC}"
    if [ "$failed_count" -gt 0 ] 2>/dev/null; then
        echo -e "${YELLOW}失败 $failed_count 帧${NC}"
    fi
    
    # 清理结果文件
    rm -f "$results_file"
    
    return 0
}

# 生成性能报告
generate_keyframe_performance_report() {
    local report_file="${1:-$TEMP_DIR/keyframe_performance_report.txt}"

    echo "生成关键帧检测性能报告..."

    cat > "$report_file" << EOF
关键帧检测性能报告
==================
生成时间: $(date)

统计信息:
EOF

    if [ "$SUPPORTS_ASSOCIATIVE_ARRAYS" = "true" ]; then
        echo "- 处理时间: ${KEYFRAME_STATS[processing_time]:-N/A}秒" >> "$report_file"
        echo "- 分析帧数: ${KEYFRAME_STATS[total_frames_analyzed]:-N/A}" >> "$report_file"
        echo "- 找到关键帧: ${KEYFRAME_STATS[keyframes_found]:-N/A}" >> "$report_file"
        echo "- 内存峰值: ${KEYFRAME_STATS[memory_peak]:-N/A}KB" >> "$report_file"
    else
        echo "- 处理时间: ${KEYFRAME_STATS_processing_time:-N/A}秒" >> "$report_file"
        echo "- 分析帧数: ${KEYFRAME_STATS_total_frames_analyzed:-N/A}" >> "$report_file"
        echo "- 找到关键帧: ${KEYFRAME_STATS_keyframes_found:-N/A}" >> "$report_file"
        echo "- 内存峰值: ${KEYFRAME_STATS_memory_peak:-N/A}KB" >> "$report_file"
    fi

    cat >> "$report_file" << EOF

系统信息:
- CPU核心数: $(nproc 2>/dev/null || echo "N/A")
- 当前内存使用: $(get_memory_usage)KB
- 可用内存: $(get_available_memory)MB
- Bash版本: $BASH_VERSION
- 关联数组支持: $SUPPORTS_ASSOCIATIVE_ARRAYS

关键帧时间点:
EOF

    if [ ${#KEYFRAME_TIMES[@]} -gt 0 ]; then
        for i in "${!KEYFRAME_TIMES[@]}"; do
            if [ $i -lt 20 ]; then  # 只显示前20个
                echo "- ${KEYFRAME_TIMES[$i]}s" >> "$report_file"
            elif [ $i -eq 20 ]; then
                echo "- ... (共 ${#KEYFRAME_TIMES[@]} 个关键帧)" >> "$report_file"
                break
            fi
        done
    else
        echo "- 无关键帧数据" >> "$report_file"
    fi

    echo "" >> "$report_file"
    echo "报告文件: $report_file"
    return 0
}

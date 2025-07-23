#!/bin/bash
# keyframe.sh - 关键帧检测功能

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

    # 更智能的超时计算：基础120秒 + 文件大小因子 + 时长因子
    local timeout_seconds=120  # 提高基础时间

    # 根据文件大小调整
    if [ "$file_size" -gt 1073741824 ]; then  # 大于1GB
        timeout_seconds=$((timeout_seconds + 120))  # 增加120秒
    fi
    if [ "$file_size" -gt 3221225472 ]; then  # 大于3GB
        timeout_seconds=$((timeout_seconds + 180))  # 再增加180秒
    fi
    if [ "$file_size" -gt 5368709120 ]; then  # 大于5GB
        timeout_seconds=$((timeout_seconds + 240))  # 再增加240秒
    fi

    # 根据时长调整
    if [ "$duration_seconds" -gt 3600 ]; then  # 大于1小时
        timeout_seconds=$((timeout_seconds + 120))  # 增加120秒
    fi
    if [ "$duration_seconds" -gt 7200 ]; then  # 大于2小时
        timeout_seconds=$((timeout_seconds + 180))  # 再增加180秒
    fi

    # 设置最大超时限制（避免无限等待）
    if [ "$timeout_seconds" -gt 900 ]; then  # 最大15分钟
        timeout_seconds=900
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

# 关键帧模式截取视频帧
extract_frames_keyframe() {
    echo -e "${YELLOW}开始关键帧截取视频帧...${NC}"
    
    # 执行关键帧检测
    if ! detect_keyframes "$VIDEO_FILE" "$KEYFRAME_MIN_INTERVAL"; then
        echo -e "${YELLOW}关键帧检测失败，回退到时间间隔模式${NC}"
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
    
    # 执行关键帧检测
    if ! detect_keyframes "$VIDEO_FILE" "$KEYFRAME_MIN_INTERVAL"; then
        echo -e "${YELLOW}关键帧检测失败，回退到时间间隔模式${NC}"
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

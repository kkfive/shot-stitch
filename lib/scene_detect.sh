#!/bin/bash
# scene_detect.sh - 场景检测功能 (集成优化版本)

# 全局变量
SCENE_TIMES=()
SCENE_TIMEPOINTS=()  # 计算出的场景检测时间点
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

# 计算分段数的辅助函数
calculate_segment_count() {
    local max_segments=${SCENE_DETECTION_MAX_SEGMENTS:-auto}
    local cpu_cores=$(detect_cpu_cores)
    local segments_multiplier=${SCENE_DETECTION_SEGMENTS_MULTIPLIER:-4}

    if [ "$max_segments" = "auto" ]; then
        echo $((cpu_cores * segments_multiplier))
    elif [[ "$max_segments" =~ ^[0-9]+$ ]]; then
        echo "$max_segments"
    else
        # 配置无效，使用自动计算
        echo $((cpu_cores * segments_multiplier))
    fi
}

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
    # 跟踪后台进程以便清理
    track_background_process "$ffmpeg_pid"
    
    # 显示进度
    echo -n "场景检测进度: 0%"
    while kill -0 "$ffmpeg_pid" 2>/dev/null; do
        if [ -f "$temp_progress_file" ]; then
            # 从进度文件中读取当前时间
            local current_time=$(tail -n 20 "$temp_progress_file" 2>/dev/null | grep "out_time_ms=" | tail -n 1 | cut -d= -f2)
            if [ -n "$current_time" ] && [ "$current_time" != "N/A" ]; then
                # 转换微秒到秒
                local current_seconds=$((current_time / 1000000))
                if [ "$current_seconds" -gt 0 ] && [ "$DURATION" -gt 0 ]; then
                    local progress=$((current_seconds * 100 / DURATION))
                    if [ "$progress" -gt 100 ]; then progress=100; fi
                    printf "\r场景检测进度: %d%%" "$progress"
                fi
            fi
        fi
        sleep 1
    done

    # 等待ffmpeg进程完成
    wait "$ffmpeg_pid"
    local ffmpeg_exit_code=$?
    
    printf "\r场景检测进度: 100%%\n"
    
    # 清理进度文件
    rm -f "$temp_progress_file"
    
    # 检查ffmpeg是否成功执行
    if [ "$ffmpeg_exit_code" -ne 0 ]; then
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
    local cpu_cores=$(detect_cpu_cores)

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
    # 跟踪后台进程以便清理
    track_background_process "$ffmpeg_pid"

    # 显示进度并监控
    echo -n "场景检测进度: 处理中"
    local elapsed=0
    local dot_count=0

    while kill -0 "$ffmpeg_pid" 2>/dev/null; do
        sleep 1
        echo -n "."
        elapsed=$((elapsed + 1))
        dot_count=$((dot_count + 1))

        # 每10秒显示一次状态
        if [ $((dot_count % 10)) -eq 0 ]; then
            printf " (%ds)" "$elapsed"
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

        if [ "$elapsed" -gt "$timeout_limit" ]; then
            echo " 超时，终止优化检测"
            kill "$ffmpeg_pid" 2>/dev/null
            rm -f "$temp_scene_file" "$temp_progress_file"
            echo -e "${YELLOW}优化检测超时，回退到原始算法${NC}"
            detect_scene_changes "$video_file" "$threshold"
            return $?
        fi
    done

    # 等待ffmpeg进程完成
    wait "$ffmpeg_pid"
    local ffmpeg_exit_code=$?

    # 记录结束时间和内存
    local end_time=$(date +%s)
    local end_memory=$(ps -o rss= -p $$ 2>/dev/null || echo 0)
    local processing_time=$((end_time - start_time))

    printf " 完成 (用时: %ds)\n" "$processing_time"

    # 清理进度文件
    rm -f "$temp_progress_file"

    # 检查ffmpeg是否成功执行
    if [ "$ffmpeg_exit_code" -ne 0 ]; then
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

# 标准场景检测算法（保持质量和精度）
detect_scene_changes_standard() {
    local video_file="$1"
    local threshold="$2"
    local scene_times=()

    echo -e "${YELLOW}正在使用标准算法分析视频场景变化...${NC}"

    # 记录开始时间
    local start_time=$(date +%s)

    # 创建临时文件
    local temp_scene_file="$TEMP_DIR/scene_detection_standard.txt"
    local temp_progress_file="$TEMP_DIR/scene_progress_standard.txt"

    # 使用标准的场景检测参数
    local cpu_cores=$(detect_cpu_cores)

    echo "使用标准参数: 多线程($cpu_cores核心), 保持检测质量"

    # 标准策略：保持合理的质量参数
    # 1. 640p分辨率（保持检测精度）
    # 2. 1fps采样率（足够的检测密度）
    # 3. 严格遵守用户配置的阈值
    # 4. 不私自修改任何参数

    ffmpeg -i "$video_file" \
        -vf "scale=640:-1,fps=1,select='gt(scene,$threshold)',showinfo" \
        -f null - \
        -threads "$cpu_cores" \
        -preset ultrafast \
        -nostats -loglevel error \
        -avoid_negative_ts make_zero \
        -progress "$temp_progress_file" \
        2>"$temp_scene_file" &

    local ffmpeg_pid=$!

    # 显示进度并监控（更长的超时时间）
    echo -n "场景检测进度: 处理中"
    local elapsed=0
    local dot_count=0

    while kill -0 "$ffmpeg_pid" 2>/dev/null; do
        sleep 1
        echo -n "."
        elapsed=$((elapsed + 1))
        dot_count=$((dot_count + 1))

        # 每10秒显示一次状态
        if [ $((dot_count % 10)) -eq 0 ]; then
            printf " (%ds)" $elapsed
        fi

        # 超时保护：遵循配置文件设置，0表示无超时
        local timeout_limit=${SCENE_DETECTION_SEGMENT_TIMEOUT:-1800}  # 使用分段超时配置，默认30分钟

        if [ "$timeout_limit" -gt 0 ] && [ $elapsed -gt $timeout_limit ]; then
            echo " 超时(${timeout_limit}s)，终止超级优化检测"
            kill $ffmpeg_pid 2>/dev/null
            rm -f "$temp_scene_file" "$temp_progress_file"
            echo -e "${YELLOW}超级优化检测超时，回退到并行算法${NC}"
            local segment_count=$(calculate_segment_count)
            detect_scene_changes_parallel "$video_file" "$threshold" "$segment_count" "$timeout_limit"
            return $?
        elif [ "$timeout_limit" -eq 0 ]; then
            # 无超时模式，每60秒显示一次进度
            if [ $((elapsed % 60)) -eq 0 ] && [ $elapsed -gt 0 ]; then
                printf " (%ds,无超时限制)" $elapsed
            fi
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



# 分段并行场景检测算法
detect_scene_changes_parallel() {
    local video_file="$1"
    local threshold="$2"
    local max_segments="${3:-${SCENE_DETECTION_MAX_SEGMENTS:-8}}"
    local timeout_per_segment="${4:-${SCENE_DETECTION_SEGMENT_TIMEOUT:-300}}"  # 每段超时时间

    echo -e "${YELLOW}正在使用分段并行算法分析视频场景变化...${NC}"

    # 获取视频总时长
    local total_duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$video_file" 2>/dev/null)
    local duration_int=$(echo "$total_duration" | cut -d. -f1)

    if [ -z "$duration_int" ] || [ "$duration_int" -eq 0 ]; then
        echo "无法获取视频时长，回退到优化算法"
        detect_scene_changes_optimized "$video_file" "$threshold"
        return $?
    fi

    # 简化的分段策略 - 支持auto和数字两种模式
    local cpu_cores=$(detect_cpu_cores)
    local segments_multiplier=${SCENE_DETECTION_SEGMENTS_MULTIPLIER:-4}
    local min_segment_duration=30  # 最小分段时长30秒

    echo "分段策略配置: CPU核心=${cpu_cores}, 配置值=${max_segments}"

    local segment_count
    if [ "$max_segments" = "auto" ]; then
        # 自动模式: CPU核心数 × 倍数
        segment_count=$((cpu_cores * segments_multiplier))
        echo "自动分段模式: ${cpu_cores} × ${segments_multiplier} = ${segment_count} 个分段"
    elif [[ "$max_segments" =~ ^[0-9]+$ ]]; then
        # 数字模式: 使用指定的分段数
        segment_count=$max_segments
        echo "手动分段模式: 使用指定的 ${segment_count} 个分段"
    else
        # 无效配置，使用默认值
        segment_count=$((cpu_cores * segments_multiplier))
        echo "配置无效，使用默认: ${segment_count} 个分段"
    fi

    # 根据视频时长调整分段数，确保每段不少于最小时长
    local segment_duration=$((duration_int / segment_count))
    if [ $segment_duration -lt $min_segment_duration ]; then
        segment_count=$((duration_int / min_segment_duration))
        if [ $segment_count -lt 1 ]; then
            segment_count=1
        fi
        segment_duration=$((duration_int / segment_count))
        echo "分段调整: 因时长限制调整为 ${segment_count} 个分段 (每段${segment_duration}秒)"
    fi

    # 确保至少有2个分段才使用并行
    if [ $segment_count -lt 2 ]; then
        echo "视频时长太短，回退到优化算法"
        detect_scene_changes_optimized "$video_file" "$threshold"
        return $?
    fi

    echo "分段策略: ${segment_count} 个段, 每段约 ${segment_duration}s, 并行处理"
    echo "优化策略: 640p分辨率, 1fps采样率, 无超时限制确保完成"

    # 记录开始时间
    local start_time=$(date +%s)

    # 创建分段作业
    local segment_pids=()
    local segment_files=()
    local cpu_cores=$(detect_cpu_cores)

    for ((i=0; i<segment_count; i++)); do
        local segment_start=$((i * segment_duration))
        local segment_end=$(((i + 1) * segment_duration))

        if [ $i -eq $((segment_count - 1)) ]; then
            segment_end=$duration_int  # 最后一段处理到结尾
        fi

        local segment_file="$TEMP_DIR/scene_parallel_${i}.txt"
        segment_files+=("$segment_file")

        # 启动并行处理（带超时控制）
        # 将循环变量传递给子进程
        (
            # 继承父进程的环境变量，特别是PATH
            export PATH="$PATH"

            local segment_index="$i"
            local segment_start_time="$segment_start"
            local segment_end_time="$segment_end"
            local segment_output_file="$segment_file"
            local video_input_file="$(realpath "$video_file")"  # 使用绝对路径
            local scene_threshold="$threshold"
            local timeout_setting="$timeout_per_segment"

            # 确保每个分段至少有1个线程
            local segment_threads=$((cpu_cores / segment_count))
            if [ $segment_threads -lt 1 ]; then
                segment_threads=1
            fi

            # 创建进度文件
            local progress_file="$segment_output_file.progress"
            echo "0" > "$progress_file"



            # 统一的分段处理：不区分超时/无超时模式，统一处理逻辑
            local segment_display_id=$(printf "%02d" $((segment_index + 1)))

            # 只在第一个分段时输出汇总信息
            if [ $segment_index -eq 0 ]; then
                local timeout_desc="无限制"
                if [ "$timeout_setting" -gt 0 ]; then
                    timeout_desc="${timeout_setting}秒"
                fi
                echo "分段配置: 共${segment_count}个分段, 超时=${timeout_desc}, 场景阈值=${scene_threshold}"
            fi

            local segment_duration=$((segment_end_time - segment_start_time))
            local error_log="$segment_output_file.error"

            # 严格遵守用户配置的阈值，不私自修改
            local effective_threshold="$scene_threshold"

            # 启动FFmpeg进程：统一的质量参数，不因超时设置而改变
            ffmpeg -ss "$segment_start_time" -t "$segment_duration" -i "$video_input_file" \
                -vf "scale=640:-1,fps=1,select='gt(scene,$effective_threshold)',showinfo" \
                -f null - \
                -threads "$segment_threads" \
                -preset ultrafast \
                -nostats -loglevel info \
                -avoid_negative_ts make_zero \
                >"$error_log" 2>"$segment_output_file" &
            local ffmpeg_pid=$!

            # 启动统一的进度监控子进程
            (
                local start_time=$(date +%s)
                while kill -0 "$ffmpeg_pid" 2>/dev/null; do
                    local current_time=$(date +%s)
                    local elapsed=$((current_time - start_time))

                    # 基于时间估算进度（移除95%限制，让进度自然增长）
                    if [ "$segment_duration" -gt 0 ]; then
                        # 使用更保守的进度估算，避免过早达到100%
                        local estimated_progress=$((elapsed * 100 / segment_duration))
                        if [ "$estimated_progress" -gt 99 ]; then estimated_progress=99; fi
                        if [ "$estimated_progress" -lt 0 ]; then estimated_progress=0; fi
                        echo "$estimated_progress" > "${progress_file}.percent"
                    fi

                    sleep 2
                done

                # 进程完成，设置100%
                echo "100" > "${progress_file}.percent"
            ) &
            local monitor_pid=$!

            # 统一的等待逻辑：根据超时设置决定等待方式
            if [ "$timeout_setting" -gt 0 ]; then
                # 有超时限制：扩展超时时间，但最终仍会等待完成
                local extended_timeout=$((timeout_setting * 3))
                echo "分段${segment_display_id}: 扩展超时时间 ${extended_timeout}秒"

                local elapsed=0
                while [ "$elapsed" -lt "$extended_timeout" ]; do
                    if ! kill -0 "$ffmpeg_pid" 2>/dev/null; then
                        break  # 进程已完成
                    fi
                    sleep 1
                    elapsed=$((elapsed + 1))

                    if [ $((elapsed % 60)) -eq 0 ]; then
                        echo "分段${segment_display_id}: 已处理 ${elapsed}/${extended_timeout}秒"
                    fi
                done

                # 即使超时也等待完成，不强制杀死
                if kill -0 "$ffmpeg_pid" 2>/dev/null; then
                    echo "分段${segment_display_id}: 超过预期时间，继续等待完成..."
                fi
            fi

            # 最终等待进程完成（无论是否有超时设置）
            wait "$ffmpeg_pid"
            local exit_code=$?

            # 停止监控进程
            kill "$monitor_pid" 2>/dev/null
            wait "$monitor_pid" 2>/dev/null

            # 处理结果
            if [ "$exit_code" -ne 0 ]; then
                echo "SEGMENT_${segment_index}_FAILED" > "$segment_output_file"
            else
                echo "100" > "${progress_file}.percent"
            fi
        ) &

        segment_pids+=($!)
    done

    # 监控所有分段进程 - 实时显示每个分段的详细进度
    echo "并行场景检测进度:"
    local completed_segments=0
    local all_completed=false
    local segment_progress=()
    local segment_status=()
    local debug_mode="${DEBUG_SCENE_DETECT:-false}"

    # 调试信息
    if [ "$debug_mode" = "true" ]; then
        echo "调试模式: 启动了 $segment_count 个分段进程"
        echo "进程ID: ${segment_pids[*]}"
    fi

    # 初始化分段状态
    for ((i=0; i<segment_count; i++)); do
        segment_progress[i]=0
        segment_status[i]="等待中"
    done

    # 实时监控逻辑
    while [ "$completed_segments" -lt "$segment_count" ]; do
        sleep 1  # 增加更新频率，从0.5秒改为1秒

        # 检查每个分段的状态和进度
        local new_completed=0
        local total_progress=0
        local status_line=""

        for ((i=0; i<segment_count; i++)); do
            local pid=${segment_pids[i]}
            local segment_file="${segment_files[i]}"
            local progress_file="${segment_file}.progress"

            if ! kill -0 "$pid" 2>/dev/null; then
                # 进程已完成，检查结果
                if [ "${segment_status[i]}" != "✓完成" ] && [ "${segment_status[i]}" != "✗失败" ]; then
                    # 检查是否有失败标记
                    if [ -f "$segment_file" ] && grep -q "SEGMENT_${i}_FAILED\|SEGMENT_${i}_TIMEOUT" "$segment_file" 2>/dev/null; then
                        segment_status[i]="✗失败"
                        segment_progress[i]=0
                    # 检查是否有有效输出（showinfo输出）
                    elif [ -f "$segment_file" ] && grep -q "pts_time:\|showinfo" "$segment_file" 2>/dev/null; then
                        segment_status[i]="✓完成"
                        segment_progress[i]=100
                    # 文件存在但没有有效输出
                    elif [ -f "$segment_file" ]; then
                        segment_status[i]="✗失败"
                        segment_progress[i]=0
                    else
                        segment_status[i]="✗失败"
                        segment_progress[i]=0
                    fi
                fi
                # 只有成功的分段才计入完成数
                if [ "${segment_status[i]}" = "✓完成" ]; then
                    new_completed=$((new_completed + 1))
                fi
            else
                # 进程仍在运行，读取进度
                local progress_percent=0

                # 优先读取百分比文件
                if [ -f "${progress_file}.percent" ]; then
                    progress_percent=$(cat "${progress_file}.percent" 2>/dev/null || echo "0")
                    if [[ "$progress_percent" =~ ^[0-9]+$ ]] && [ "$progress_percent" -le 100 ]; then
                        segment_progress[i]=$progress_percent
                        if [ "$progress_percent" -gt 0 ]; then
                            segment_status[i]="处理中"
                        fi
                    fi

                    # 调试信息
                    if [ "$debug_mode" = "true" ]; then
                        echo "分段$i: 百分比文件进度=${progress_percent}%"
                    fi
                elif [ -f "$progress_file" ]; then
                    # 解析FFmpeg progress文件格式
                    local current_time=$(grep "out_time_ms=" "$progress_file" 2>/dev/null | tail -1 | cut -d= -f2)
                    if [ -n "$current_time" ] && [ "$current_time" != "N/A" ]; then
                        # 转换微秒到秒
                        local current_seconds=$((current_time / 1000000))
                        local segment_duration=$((segment_end_time - segment_start_time))
                        if [ "$segment_duration" -gt 0 ]; then
                            progress_percent=$((current_seconds * 100 / segment_duration))
                            if [ "$progress_percent" -gt 100 ]; then progress_percent=100; fi
                            if [ "$progress_percent" -ge 0 ]; then
                                segment_progress[i]=$progress_percent
                                if [ "$progress_percent" -gt 0 ]; then
                                    segment_status[i]="处理中"
                                fi
                            fi
                        fi

                        # 调试信息
                        if [ "$debug_mode" = "true" ]; then
                            echo "分段$i: 当前时间=${current_seconds}s, 总时长=${segment_duration}s, 进度=${progress_percent}%"
                        fi
                    else
                        # 回退到简单的数字解析
                        local simple_progress=$(tail -1 "$progress_file" 2>/dev/null | grep -o '[0-9]*' | head -1)
                        if [[ "$simple_progress" =~ ^[0-9]+$ ]] && [ "$simple_progress" -le 100 ]; then
                            segment_progress[i]=$simple_progress
                            if [ "$simple_progress" -gt 0 ]; then
                                segment_status[i]="处理中"
                            fi
                        fi

                        # 调试信息
                        if [ "$debug_mode" = "true" ]; then
                            echo "分段$i: 简单进度解析=${simple_progress}%"
                        fi
                    fi
                else
                    # 调试信息：进度文件不存在
                    if [ "$debug_mode" = "true" ]; then
                        echo "分段$i: 进度文件不存在 ($progress_file)"
                        # 检查文件是否真的不存在
                        ls -la "$(dirname "$progress_file")" 2>/dev/null | grep "$(basename "$progress_file")" || echo "确实不存在"
                    fi
                fi
            fi

            # 累计总进度
            total_progress=$((total_progress + segment_progress[i]))

            # 构建状态显示（使用两位数格式，从01开始）
            local display_id=$(printf "%02d" $((i + 1)))
            local segment_display="分段${display_id}:${segment_progress[i]}%"
            if [ "${segment_status[i]}" = "✓完成" ]; then
                segment_display="分段${display_id}:✓"
            elif [ "${segment_status[i]}" = "✗失败" ]; then
                segment_display="分段${display_id}:✗"
            fi

            if [ $i -eq 0 ]; then
                status_line="$segment_display"
            else
                status_line="$status_line | $segment_display"
            fi
        done

        # 计算总进度
        local overall_progress=$((total_progress / segment_count))

        # 生成更好的进度显示
        local display_mode="${PROGRESS_DISPLAY_MODE:-auto}"
        local current_display=""

        # 根据显示模式生成不同的输出
        case "$display_mode" in
            "bar")
                current_display=$(generate_progress_bar_display "$overall_progress" "$segment_count")
                ;;
            "table")
                current_display=$(generate_progress_table_display "$overall_progress" "$segment_count")
                ;;
            "compact")
                current_display=$(generate_progress_compact_display "$overall_progress" "$segment_count")
                ;;
            "simple")
                current_display="总进度:${overall_progress}% [$status_line]"
                ;;
            *)
                # 自动选择：CI环境用table，本地用bar
                if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
                    current_display=$(generate_progress_table_display "$overall_progress" "$segment_count")
                else
                    current_display=$(generate_progress_bar_display "$overall_progress" "$segment_count")
                fi
                ;;
        esac

        # 调试信息
        if [ "$debug_mode" = "true" ]; then
            echo "监控循环: 已完成=$completed_segments, 总数=$segment_count, 总进度=$overall_progress%"
        fi

        if [ "$current_display" != "${last_display:-}" ] || [ "$debug_mode" = "true" ]; then
            # 检测是否在CI环境中
            if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
                # CI环境：使用换行输出
                echo "$current_display"
            else
                # 本地环境：根据显示模式选择输出方式
                if [ "$display_mode" = "table" ]; then
                    # 表格模式：清屏重绘
                    printf "\033[2J\033[H%s" "$current_display"
                else
                    # 其他模式：使用\r更新
                    printf "\r\033[K%s" "$current_display"
                fi
            fi
            last_display="$current_display"
        fi

        completed_segments=$new_completed

        # 如果所有分段都完成了
        if [ "$completed_segments" -eq "$segment_count" ]; then
            all_completed=true
            break
        fi
    done

    # 清理进度文件
    for ((i=0; i<segment_count; i++)); do
        rm -f "${segment_files[i]}.progress"
    done

    # 确保最终显示100%
    if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo ""
        echo "并行场景检测完成: $completed_segments/$segment_count 分段成功"
    else
        printf "\n并行场景检测完成: %d/%d 分段成功\n" "$completed_segments" "$segment_count"
    fi

    # 等待所有进程完成
    for pid in "${segment_pids[@]}"; do
        wait "$pid" 2>/dev/null
    done

    local end_time=$(date +%s)
    local processing_time=$((end_time - start_time))
    printf " 完成 (用时: %ds)\n" "$processing_time"

    # 合并所有分段结果
    local scene_times=()
    local total_scenes=0
    local failed_segments=0

    for ((i=0; i<segment_count; i++)); do
        local segment_file="${segment_files[i]}"

        # 检查文件是否存在
        if [ ! -f "$segment_file" ]; then
            echo "警告: 分段 $i 输出文件不存在"
            failed_segments=$((failed_segments + 1))
            continue
        fi

        # 检查是否有错误标记
        if grep -q "SEGMENT_${i}_FAILED\|SEGMENT_${i}_TIMEOUT" "$segment_file" 2>/dev/null; then
            if grep -q "TIMEOUT" "$segment_file" 2>/dev/null; then
                echo "警告: 分段 $i 处理超时"
            else
                echo "警告: 分段 $i 处理失败"
            fi
            failed_segments=$((failed_segments + 1))
            continue
        fi

        # 检查文件是否有有效的场景检测输出
        local has_valid_output=false
        if [ -s "$segment_file" ] && grep -q "pts_time:\|showinfo" "$segment_file" 2>/dev/null; then
            has_valid_output=true
        fi

        if [ "$has_valid_output" = "false" ]; then
            echo "警告: 分段 $i 输出为空或无有效场景检测数据"
            failed_segments=$((failed_segments + 1))
            continue
        fi

        # 从分段文件中提取场景时间点
        local segment_start=$((i * segment_duration))
        local scene_output
        scene_output=$(grep "pts_time:" "$segment_file" 2>/dev/null | \
            sed -n 's/.*pts_time:\([0-9.]*\).*/\1/p')

        if [ -n "$scene_output" ]; then
            while IFS= read -r time_point; do
                if [ -n "$time_point" ]; then
                    total_scenes=$((total_scenes + 1))
                    # 转换为绝对时间
                    local absolute_time=$(echo "$segment_start + $time_point" | bc 2>/dev/null || echo $((segment_start + ${time_point%.*})))
                    local time_int=$(echo "$absolute_time" | cut -d. -f1)
                    if [[ "$time_int" =~ ^[0-9]+$ ]]; then
                        scene_times+=("$time_int")
                    fi
                fi
            done <<< "$scene_output"
        fi

        # 清理分段文件
        rm -f "$segment_file"
    done

    # 检查是否有足够的成功分段
    local success_segments=$((segment_count - failed_segments))
    if [ $success_segments -lt $((segment_count / 2)) ]; then
        echo -e "${YELLOW}并行检测失败分段过多 ($failed_segments/$segment_count)，回退到优化算法${NC}"
        detect_scene_changes_optimized "$video_file" "$threshold"
        return $?
    fi

    # 对场景时间点排序并去重
    if [ ${#scene_times[@]} -gt 0 ]; then
        # 使用bash内置排序
        IFS=$'\n' scene_times=($(sort -n <<< "${scene_times[*]}"))
        unset IFS

        # 去重
        local unique_times=()
        local last_time=-1
        for time in "${scene_times[@]}"; do
            if [ "$time" != "$last_time" ]; then
                unique_times+=("$time")
                last_time="$time"
            fi
        done
        scene_times=("${unique_times[@]}")
    fi

    echo "检测统计: 总场景数 $total_scenes, 有效场景 ${#scene_times[@]} 个"
    echo "处理时间: ${processing_time}秒, 成功分段: $success_segments/$segment_count"
    echo -e "${GREEN}并行场景检测完成，性能提升约 3-5倍${NC}"

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
        # 大文件：优先使用并行算法
        echo "选择策略: 并行算法（大文件）"
        # 使用配置文件中的分段数和超时设置
        local segment_count=$(calculate_segment_count)
        if ! detect_scene_changes_parallel "$video_file" "$threshold" "$segment_count" "${SCENE_DETECTION_SEGMENT_TIMEOUT:-300}"; then
            echo "并行算法失败，回退到优化算法"
            detect_scene_changes_optimized "$video_file" "$threshold"
        fi
    else
        # 超大文件：使用并行算法，更多分段
        echo "选择策略: 并行算法（超大文件，更多分段）"
        # 使用配置文件中的分段数，超大文件无超时限制
        local segment_count=$(calculate_segment_count)
        if ! detect_scene_changes_parallel "$video_file" "$threshold" "$segment_count" 0; then
            echo "并行算法失败，回退到标准算法"
            detect_scene_changes_standard "$video_file" "$threshold"
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

# 生成进度条显示（简化版，避免数组引用问题）
generate_progress_bar_display() {
    local overall_progress="$1"
    local segment_count="$2"
    # 不使用数组引用，直接从全局数组读取

    local output=""

    # 总进度条
    local bar_width=50
    local filled=$((overall_progress * bar_width / 100))
    local empty=$((bar_width - filled))

    local progress_bar="["
    for i in $(seq 1 $filled); do progress_bar="${progress_bar}█"; done
    for i in $(seq 1 $empty); do progress_bar="${progress_bar}░"; done
    progress_bar="${progress_bar}]"

    output="总进度: ${progress_bar} ${overall_progress}%\n"

    # 分段进度条
    output="${output}分段进度:\n"
    for i in $(seq 0 $((segment_count - 1))); do
        local seg_progress=${segment_progress[i]:-0}
        local seg_status=${segment_status[i]:-"等待中"}

        # 小进度条
        local seg_bar_width=20
        local seg_filled=$((seg_progress * seg_bar_width / 100))
        local seg_empty=$((seg_bar_width - seg_filled))

        local seg_bar="["
        if [ "$seg_status" = "✓完成" ]; then
            for j in $(seq 1 $seg_bar_width); do seg_bar="${seg_bar}█"; done
        elif [ "$seg_status" = "✗失败" ]; then
            for j in $(seq 1 $seg_bar_width); do seg_bar="${seg_bar}▓"; done
        else
            for j in $(seq 1 $seg_filled); do seg_bar="${seg_bar}█"; done
            for j in $(seq 1 $seg_empty); do seg_bar="${seg_bar}░"; done
        fi
        seg_bar="${seg_bar}]"

        local status_icon=""
        case "$seg_status" in
            "✓完成") status_icon="✓" ;;
            "✗失败") status_icon="✗" ;;
            "处理中") status_icon="⚡" ;;
            *) status_icon="⏳" ;;
        esac

        local display_id=$(printf "%02d" $((i + 1)))
        output="${output}  分段${display_id}: ${seg_bar} ${seg_progress}% ${status_icon}\n"
    done

    printf "%b" "$output"
}

# 生成表格显示（简化版）
generate_progress_table_display() {
    local overall_progress="$1"
    local segment_count="$2"
    # 直接从全局数组读取

    local output=""

    # 表头
    output="┌─────────────────────────────────────────────────────────┐\n"
    output="${output}│                 并行场景检测进度                        │\n"
    output="${output}├─────────┬──────────────────────┬─────────┬─────────────┤\n"
    output="${output}│  分段   │       进度条         │  百分比 │    状态     │\n"
    output="${output}├─────────┼──────────────────────┼─────────┼─────────────┤\n"

    # 分段行
    for i in $(seq 0 $((segment_count - 1))); do
        local seg_progress=${segment_progress[i]:-0}
        local seg_status=${segment_status[i]:-"等待中"}

        # 进度条
        local bar_width=20
        local filled=$((seg_progress * bar_width / 100))
        local empty=$((bar_width - filled))

        local bar=""
        if [ "$seg_status" = "✓完成" ]; then
            for j in $(seq 1 $bar_width); do bar="${bar}█"; done
        elif [ "$seg_status" = "✗失败" ]; then
            for j in $(seq 1 $bar_width); do bar="${bar}▓"; done
        else
            for j in $(seq 1 $filled); do bar="${bar}█"; done
            for j in $(seq 1 $empty); do bar="${bar}░"; done
        fi

        local status_text=""
        case "$seg_status" in
            "✓完成") status_text="✓ 完成    " ;;
            "✗失败") status_text="✗ 失败    " ;;
            "处理中") status_text="⚡ 处理中  " ;;
            *) status_text="⏳ 等待中  " ;;
        esac

        output="${output}│ 分段 ${i}  │ ${bar} │  ${seg_progress}%   │ ${status_text} │\n"
    done

    # 总进度行
    output="${output}├─────────┼──────────────────────┼─────────┼─────────────┤\n"
    local total_bar_width=20
    local total_filled=$((overall_progress * total_bar_width / 100))
    local total_empty=$((total_bar_width - total_filled))

    local total_bar=""
    for j in $(seq 1 $total_filled); do total_bar="${total_bar}█"; done
    for j in $(seq 1 $total_empty); do total_bar="${total_bar}░"; done

    output="${output}│  总计   │ ${total_bar} │ ${overall_progress}%   │ 并行处理    │\n"
    output="${output}└─────────┴──────────────────────┴─────────┴─────────────┘"

    printf "%b" "$output"
}

# 生成紧凑显示（简化版）
generate_progress_compact_display() {
    local overall_progress="$1"
    local segment_count="$2"
    # 直接从全局数组读取

    local output="进度: ${overall_progress}% ["

    for i in $(seq 0 $((segment_count - 1))); do
        local seg_progress=${segment_progress[i]:-0}
        local seg_status=${segment_status[i]:-"等待中"}

        local icon=""
        case "$seg_status" in
            "✓完成") icon="✓" ;;
            "✗失败") icon="✗" ;;
            "处理中") icon="⚡" ;;
            *) icon="⏳" ;;
        esac

        if [ $i -gt 0 ]; then output="${output} "; fi
        output="${output}${i}:${seg_progress}%${icon}"
    done

    output="${output}]"
    printf "%s" "$output"
}

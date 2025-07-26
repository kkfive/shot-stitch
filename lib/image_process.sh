#!/bin/bash
# image_process.sh - 图片处理和拼接

# 创建信息头部图片
create_info_header() {
    local header_file="$1"
    local grid_width="$2"
    local part_info="$3"  # 可选的分割信息，格式："第1部分 (共2部分)"
    
    # 使用全局字体文件路径
    local font_file="$FONT_FILE"
    
    # 检查字体文件是否存在
    if [ ! -f "$font_file" ]; then
        echo -e "${YELLOW}警告: 字体文件不存在 ($font_file)，使用系统默认字体${NC}" >&2
        font_file=""
    fi
    
    # 根据图片宽度动态调整字体大小和布局
    local bg_color="#f8f9fa"
    local text_color="#2c3e50"
    local margin=12  # 增加顶部边距
    local left_margin=20
    local bottom_margin=20  # 增加底部边距，让布局更舒适

    # 根据图片宽度调整字体大小，防止文字截断
    local font_size=18
    local title_font_size=22
    if [ "$grid_width" -lt 1200 ]; then
        font_size=16
        title_font_size=20
        left_margin=15
    elif [ "$grid_width" -lt 800 ]; then
        font_size=14
        title_font_size=18
        left_margin=12
    fi

    # 第一行：标题、文件名和分割信息
    local title_line=""
    if [ -n "$VIDEO_TITLE" ] && [ "$VIDEO_TITLE" != "N/A" ]; then
        title_line="标题：$VIDEO_TITLE    文件名：$VIDEO_FULL_FILENAME"
    else
        title_line="文件名：$VIDEO_FULL_FILENAME"
    fi

    # 如果有分割信息，添加到标题行
    if [ -n "$part_info" ]; then
        title_line="$title_line    $part_info"
    fi

    # 视频信息行
    local info_line1="分辨率：${VIDEO_WIDTH}x${VIDEO_HEIGHT}    时长：$DURATION_FORMATTED    文件大小：$FILE_SIZE_FORMATTED    码率：$BITRATE_FORMATTED"

    # 生成参数信息
    local mode_desc=""
    case "$MODE" in
        "scene")
            mode_desc="场景检测模式(${MIN_INTERVAL}-${MAX_INTERVAL}s, 敏感度${SCENE_THRESHOLD})"
            ;;
        "keyframe")
            mode_desc="关键帧模式(最小间隔${KEYFRAME_MIN_INTERVAL}s)"
            ;;
        *)
            mode_desc="时间模式(间隔${INTERVAL}s)"
            ;;
    esac

    local parallel_info=""
    if [ "$ENABLE_PARALLEL_PROCESSING" = true ] && [ "$PARALLEL_JOBS" -gt 1 ]; then
        parallel_info="并行处理(${PARALLEL_JOBS}进程)"
    else
        parallel_info="串行处理"
    fi

    local info_line2="截图模式：$mode_desc    列数：${COLUMN}列    间距：${GAP}px"
    local info_line3="图片质量：${QUALITY}    格式：$(echo "$FORMAT" | tr '[:lower:]' '[:upper:]')    处理方式：$parallel_info    生成时间：$GENERATION_TIME"

    # 执行命令行处理（智能截断和换行）
    local full_command="./preview.sh"
    if [ -n "$ORIGINAL_ARGS" ]; then
        full_command="$full_command $ORIGINAL_ARGS"
    else
        # 重构基本命令
        full_command="$full_command \"$VIDEO_FILE\""
        if [ "$MODE" != "time" ]; then
            full_command="$full_command --mode $MODE"
        fi
        if [ "$COLUMN" != "4" ]; then
            full_command="$full_command --column $COLUMN"
        fi
        if [ "$QUALITY" != "85" ]; then
            full_command="$full_command --quality $QUALITY"
        fi
        if [ "$GAP" != "5" ]; then
            full_command="$full_command --gap $GAP"
        fi
        if [ "$FORMAT" != "jpg" ]; then
            full_command="$full_command --format $FORMAT"
        fi
    fi

    # 智能处理命令行长度
    local max_chars_per_line=$((grid_width / 12))  # 估算每行最大字符数
    local command_line1="执行命令：$full_command"
    local command_line2=""

    # 如果命令太长，进行智能分割
    if [ ${#command_line1} -gt $max_chars_per_line ]; then
        # 尝试在合适的位置分割（空格、--参数等）
        local split_pos=$max_chars_per_line

        # 向前查找最近的空格或--参数位置
        while [ $split_pos -gt $((max_chars_per_line / 2)) ]; do
            local char="${command_line1:$split_pos:1}"
            if [ "$char" = " " ]; then
                # 检查是否是--参数的开始
                local next_chars="${command_line1:$((split_pos+1)):2}"
                if [ "$next_chars" = "--" ]; then
                    break
                fi
            fi
            split_pos=$((split_pos - 1))
        done

        # 如果找到合适的分割点
        if [ $split_pos -gt $((max_chars_per_line / 2)) ]; then
            command_line1="${command_line1:0:$split_pos}"
            command_line2="    ${command_line1:$split_pos}"  # 第二行缩进
        else
            # 如果找不到合适分割点，使用省略号
            command_line1="${command_line1:0:$((max_chars_per_line-3))}..."
        fi
    fi
    
    # 构建字体参数
    local font_option=""
    if [ -n "$font_file" ]; then
        font_option="-font $font_file"
    fi
    
    # 构建文本注释参数并动态计算高度
    local annotations=""
    local line_height=$((font_size + 6))  # 根据字体大小动态调整行间距
    local current_y=$margin

    # 第一行：标题/文件名/分割信息
    annotations="-pointsize $title_font_size -annotate +${left_margin}+$current_y \"$title_line\""
    current_y=$((current_y + title_font_size + 6))  # 标题后的间距

    # 第二行：视频信息
    annotations="$annotations -pointsize $font_size -annotate +${left_margin}+$current_y \"$info_line1\""
    current_y=$((current_y + line_height))

    # 第三行：生成参数
    annotations="$annotations -pointsize $font_size -annotate +${left_margin}+$current_y \"$info_line2\""
    current_y=$((current_y + line_height))

    # 第四行：处理信息
    annotations="$annotations -pointsize $font_size -annotate +${left_margin}+$current_y \"$info_line3\""
    current_y=$((current_y + line_height))

    # 第五行：执行命令（第一行）
    annotations="$annotations -pointsize $font_size -annotate +${left_margin}+$current_y \"$command_line1\""

    # 如果有第二行命令，添加它
    if [ -n "$command_line2" ]; then
        current_y=$((current_y + line_height))
        annotations="$annotations -pointsize $font_size -annotate +${left_margin}+$current_y \"$command_line2\""
    fi

    # 动态计算实际需要的头部高度
    local header_height=$((current_y + bottom_margin + 10))  # 当前位置 + 底部边距 + 足够缓冲
    
    # 创建头部图片（统一命令）
    eval "magick -size ${grid_width}x${header_height} xc:\"$bg_color\" \
        $font_option \
        -fill \"$text_color\" \
        -gravity NorthWest \
        $annotations \
        \"$header_file\""
    
    return $?
}

# 生成预览拼接图
generate_preview_grid() {
    echo -e "${YELLOW}生成预览拼接图...${NC}"

    local frame_files=("$TEMP_DIR"/${VIDEO_FILENAME}_*.$FORMAT)
    
    if [ ${#frame_files[@]} -eq 0 ] || [ ! -f "${frame_files[0]}" ]; then
        echo -e "${RED}错误: 未找到截取的帧文件${NC}"
        return 1
    fi
    
    # 预估最终图片尺寸并检查是否需要预缩放
    local total_frames=${#frame_files[@]}
    local rows=$(((total_frames + COLUMN - 1) / COLUMN))
    
    # 获取单帧尺寸
    local FRAME_WIDTH=$(magick identify -format "%w" "${frame_files[0]}" 2>/dev/null)
    local FRAME_HEIGHT=$(magick identify -format "%h" "${frame_files[0]}" 2>/dev/null)
    
    if [ -z "$FRAME_WIDTH" ] || [ -z "$FRAME_HEIGHT" ]; then
        echo -e "${RED}错误: 无法获取帧图片尺寸${NC}"
        return 1
    fi
    
    local estimated_width=$((FRAME_WIDTH * COLUMN + GAP * (COLUMN - 1)))
    local estimated_height=$((FRAME_HEIGHT * rows + GAP * (rows - 1)))

    # 根据格式设置不同的尺寸限制
    # 格式对比：
    # WebP: 16383x16383 (268M像素) - 最佳压缩，现代浏览器支持
    # JPEG: 65535x65535 (4.3B像素) - 最大尺寸，通用兼容性
    # PNG:  65535x65535 (4.3B像素) - 无损压缩，文件较大
    local max_dimension=16000
    local max_pixels=268435456

    case "$FORMAT" in
        "webp")
            max_dimension=16383  # WebP限制较小但压缩最佳
            max_pixels=268435456
            ;;
        "jpg"|"jpeg")
            max_dimension=65535  # JPEG限制最大，兼容性最好
            max_pixels=4294836225  # 65535 * 65535
            ;;
        "png")
            max_dimension=65535  # PNG限制大，但文件体积大
            max_pixels=4294836225
            ;;
    esac

    local estimated_pixels=$((estimated_width * estimated_height))
    local prescale_factor=1

    echo "预估最终尺寸: ${estimated_width}x${estimated_height} (${estimated_pixels} 像素)"
    echo "格式限制: ${FORMAT} - 最大尺寸 ${max_dimension}px, 最大像素 ${max_pixels}"
    
    # 检查是否需要预缩放
    local need_rescale=false
    local scale_reason=""

    # 检查尺寸限制
    if [ "$estimated_width" -gt "$max_dimension" ]; then
        need_rescale=true
        scale_reason="宽度超出限制($estimated_width > $max_dimension)"
        local width_scale=$(echo "scale=3; $max_dimension / $estimated_width" | bc)
        prescale_factor=$width_scale
    fi

    if [ "$estimated_height" -gt "$max_dimension" ]; then
        need_rescale=true
        if [ -n "$scale_reason" ]; then
            scale_reason="$scale_reason, 高度超出限制($estimated_height > $max_dimension)"
        else
            scale_reason="高度超出限制($estimated_height > $max_dimension)"
        fi
        local height_scale=$(echo "scale=3; $max_dimension / $estimated_height" | bc)
        if [ "$need_rescale" = true ] && [ -n "$prescale_factor" ]; then
            # 取更小的缩放因子
            if (( $(echo "$height_scale < $prescale_factor" | bc -l) )); then
                prescale_factor=$height_scale
            fi
        else
            prescale_factor=$height_scale
        fi
    fi

    # 检查像素总数限制
    if [ "$estimated_pixels" -gt "$max_pixels" ]; then
        need_rescale=true
        if [ -n "$scale_reason" ]; then
            scale_reason="$scale_reason, 像素总数超出限制($estimated_pixels > $max_pixels)"
        else
            scale_reason="像素总数超出限制($estimated_pixels > $max_pixels)"
        fi
        local pixel_scale=$(echo "scale=3; sqrt($max_pixels / $estimated_pixels)" | bc -l)
        if [ "$need_rescale" = true ] && [ -n "$prescale_factor" ]; then
            # 取更小的缩放因子
            if (( $(echo "$pixel_scale < $prescale_factor" | bc -l) )); then
                prescale_factor=$pixel_scale
            fi
        else
            prescale_factor=$pixel_scale
        fi
    fi

    if [ "$need_rescale" = true ]; then
        local new_frame_width=$(echo "scale=0; $FRAME_WIDTH * $prescale_factor" | bc)
        local new_frame_height=$(echo "scale=0; $FRAME_HEIGHT * $prescale_factor" | bc)
        local scale_percent=$(echo "scale=1; $prescale_factor * 100" | bc)

        echo -e "${YELLOW}检测到图片尺寸问题: $scale_reason${NC}"
        echo -e "${YELLOW}预缩放帧到 ${new_frame_width}x${new_frame_height} (${scale_percent}%)${NC}"

        # 预缩放所有帧文件
        for frame_file in "${frame_files[@]}"; do
            magick "$frame_file" -resize "${new_frame_width}x${new_frame_height}" "$frame_file"
        done

        # 重新计算预估尺寸（确保使用整数）
        local new_width_int=$(echo "$new_frame_width" | cut -d. -f1)
        local new_height_int=$(echo "$new_frame_height" | cut -d. -f1)
        estimated_width=$((new_width_int * COLUMN + GAP * (COLUMN - 1)))
        estimated_height=$((new_height_int * rows + GAP * (rows - 1)))
        echo "缩放后预估尺寸: ${estimated_width}x${estimated_height}"

        # 检查缩放后是否仍然超出限制，如果是则启用分割模式
        if [ "$estimated_height" -gt "$max_dimension" ]; then
            echo -e "${YELLOW}预缩放后仍超出限制，启用多图片分割模式${NC}"
            return 2  # 返回特殊代码表示需要分割
        fi
    fi

    # 检查是否需要分批生成
    local should_split=false
    local split_reason=""

    # 1. 用户强制分批（命令行参数）
    if [ "$FORCE_SPLIT" = true ]; then
        should_split=true
        split_reason="用户强制启用分批模式"
    # 2. 用户设置了每部分最大帧数且超出限制
    elif [ "$MAX_FRAMES_PER_PART" -gt 0 ] && [ "$total_frames" -gt "$MAX_FRAMES_PER_PART" ]; then
        should_split=true
        split_reason="帧数超出设置限制($total_frames > $MAX_FRAMES_PER_PART)"
    fi

    # 如果需要分批，调用分批生成函数
    if [ "$should_split" = true ]; then
        echo -e "${YELLOW}启用分批生成模式: $split_reason${NC}"
        return 2  # 返回特殊代码表示需要分批
    fi
    
    # 创建临时文件（使用当前格式的扩展名）
    local row_files=()
    local temp_row_files=()
    local temp_grid_file="$TEMP_DIR/grid_temp.$FORMAT"
    local temp_header_file="$TEMP_DIR/header_temp.$FORMAT"
    
    # 根据格式和质量设置决定压缩选项
    local compression_options=""
    local show_progress_flag=false

    case "$FORMAT" in
        "webp")
            if [ "$QUALITY" -eq 100 ]; then
                echo "使用WebP无损压缩模式"
                compression_options="-compress lossless -define webp:lossless=true"
                show_progress_flag=true
            else
                echo "使用WebP有损压缩模式"
            fi
            ;;
        "jpg")
            echo "使用JPG格式"
            compression_options="-compress JPEG"
            ;;
        "png")
            echo "使用PNG格式"
            if [ "$QUALITY" -eq 100 ]; then
                compression_options="-compress lossless"
                show_progress_flag=true
            fi
            ;;
    esac
    
    # 无损模式提示
    if [ "$show_progress_flag" = true ]; then
        echo "使用无损压缩，处理时间较长..."
    fi

    # 分行处理
    echo "开始图片拼接..."
    for ((row=0; row<rows; row++)); do
        local start_idx=$((row * COLUMN))
        local end_idx=$((start_idx + COLUMN - 1))
        if [ $end_idx -ge $total_frames ]; then
            end_idx=$((total_frames - 1))
        fi

        # 显示行拼接进度
        local row_progress=$(((row + 1) * 50 / rows))
        printf "\r图片拼接进度: %d%% (行拼接 %d/%d)" $row_progress $((row + 1)) $rows

        local row_frames=()
        for ((idx=start_idx; idx<=end_idx; idx++)); do
            row_frames+=("${frame_files[idx]}")
        done

        local row_file="$TEMP_DIR/row_$row.$FORMAT"
        temp_row_files+=("$row_file")

        # 水平拼接当前行（添加间距）
        if [ "$GAP" -gt 0 ]; then
            # 创建带间距的拼接
            local temp_frames=()
            for ((i=0; i<${#row_frames[@]}; i++)); do
                temp_frames+=("${row_frames[i]}")
                # 除了最后一个，都添加间距
                if [ $i -lt $((${#row_frames[@]} - 1)) ]; then
                    local spacer_file="$TEMP_DIR/spacer_h_${row}.$FORMAT"
                    # 获取帧的高度来创建间距
                    local frame_height=$(magick identify -format "%h" "${row_frames[i]}" 2>/dev/null)
                    magick -size ${GAP}x${frame_height} xc:"#ffffff" "$spacer_file" 2>/dev/null
                    temp_frames+=("$spacer_file")
                fi
            done
            # 执行行拼接
            magick "${temp_frames[@]}" +append "$row_file" 2>/dev/null
            if [ ! -f "$row_file" ]; then
                echo -e "${RED}错误: 行 $row 拼接失败${NC}"
                return 1
            fi

            # 清理间距文件
            rm -f "$TEMP_DIR"/spacer_h_${row}.$FORMAT
        else
            # 无间距拼接
            magick "${row_frames[@]}" +append "$row_file" 2>/dev/null
            if [ ! -f "$row_file" ]; then
                echo -e "${RED}错误: 行 $row 拼接失败${NC}"
                return 1
            fi
        fi

        # 检查行文件是否成功生成
        if [ ! -f "$row_file" ]; then
            echo -e "${RED}错误: 行文件 $row_file 未生成${NC}"
            return 1
        fi

        row_files+=("$row_file")
    done

    # 垂直拼接所有行生成网格图（添加间距）
    printf "\r图片拼接进度: 60%% (垂直拼接)"
    if [ "$GAP" -gt 0 ] && [ ${#row_files[@]} -gt 1 ]; then
        # 创建带间距的垂直拼接
        local temp_rows=()
        for ((i=0; i<${#row_files[@]}; i++)); do
            temp_rows+=("${row_files[i]}")
            # 除了最后一个，都添加间距
            if [ $i -lt $((${#row_files[@]} - 1)) ]; then
                local spacer_file="$TEMP_DIR/spacer_v_${i}.$FORMAT"
                # 获取行的宽度来创建间距
                local row_width=$(magick identify -format "%w" "${row_files[i]}" 2>/dev/null)
                magick -size ${row_width}x${GAP} xc:"#ffffff" "$spacer_file" 2>/dev/null
                temp_rows+=("$spacer_file")
            fi
        done
        local magick_error_file="$TEMP_DIR/magick_error.log"
        magick "${temp_rows[@]}" -append "$temp_grid_file" 2>"$magick_error_file"
        local magick_exit_code=$?

        # 清理间距文件
        rm -f "$TEMP_DIR"/spacer_v_*.$FORMAT

        if [ $magick_exit_code -ne 0 ]; then
            echo -e "${RED}错误: 垂直拼接失败${NC}"
            if [ -f "$magick_error_file" ]; then
                echo "ImageMagick错误信息:"
                cat "$magick_error_file"
            fi
            rm -f "$magick_error_file"
            return 1
        fi
    else
        # 无间距拼接
        local magick_error_file="$TEMP_DIR/magick_error.log"
        magick "${row_files[@]}" -append "$temp_grid_file" 2>"$magick_error_file"
        local magick_exit_code=$?

        if [ $magick_exit_code -ne 0 ]; then
            echo -e "${RED}错误: 垂直拼接失败${NC}"
            if [ -f "$magick_error_file" ]; then
                echo "ImageMagick错误信息:"
                cat "$magick_error_file"
            fi
            rm -f "$magick_error_file"
            return 1
        fi
    fi

    # 检查生成的网格图是否成功
    if [ ! -f "$temp_grid_file" ]; then
        echo -e "${RED}错误: 网格图文件不存在${NC}"
        return 1
    fi

    # 获取网格图宽度用于创建头部
    printf "\r图片拼接进度: 70%% (获取图片信息)"
    local grid_width=$(magick identify -format "%w" "$temp_grid_file" 2>/dev/null)

    if [ -z "$grid_width" ]; then
        echo -e "${RED}错误: 无法获取网格图尺寸${NC}"
        return 1
    fi

    # 创建信息头部
    printf "\r图片拼接进度: 80%% (创建信息头部)"
    create_info_header "$temp_header_file" "$grid_width" ""

    # 最终拼接
    printf "\r图片拼接进度: 90%% (最终拼接)"
    if [ -n "$compression_options" ]; then
        magick "$temp_header_file" \
            -size ${grid_width}x8 xc:"#ffffff" \
            "$temp_grid_file" \
            -append \
            -quality $QUALITY \
            $compression_options \
            "$FINAL_OUTPUT" 2>/dev/null
    else
        magick "$temp_header_file" \
            -size ${grid_width}x8 xc:"#ffffff" \
            "$temp_grid_file" \
            -append \
            -quality $QUALITY \
            "$FINAL_OUTPUT"
    fi

    printf "\r图片拼接进度: 100%% (完成)\n"

    # 清理临时文件
    rm -f "${temp_row_files[@]}" "$temp_grid_file" "$temp_header_file"

    echo -e "${GREEN}预览图生成完成${NC}"
    return 0
}

# 多图片分割生成函数
generate_split_preview() {
    local output_file="$1"

    echo -e "${YELLOW}开始多图片分割生成...${NC}"

    # 检查是否有截取的帧
    local frame_files=("$TEMP_DIR"/${VIDEO_FILENAME}_*.$FORMAT)
    if [ ${#frame_files[@]} -eq 0 ] || [ ! -f "${frame_files[0]}" ]; then
        echo -e "${RED}错误: 未找到截取的帧文件${NC}"
        return 1
    fi

    local total_frames=${#frame_files[@]}
    echo "总帧数: $total_frames"

    # 获取单帧尺寸
    local FRAME_WIDTH=$(magick identify -format "%w" "${frame_files[0]}" 2>/dev/null)
    local FRAME_HEIGHT=$(magick identify -format "%h" "${frame_files[0]}" 2>/dev/null)

    # 根据格式设置限制
    local max_dimension=65535
    case "$FORMAT" in
        "webp") max_dimension=16383 ;;
        *) max_dimension=65535 ;;
    esac

    # 计算分割策略
    local max_frames_per_split
    local max_rows_per_split

    # 如果用户设置了每部分最大帧数，优先使用用户设置
    if [ "$MAX_FRAMES_PER_PART" -gt 0 ]; then
        max_frames_per_split="$MAX_FRAMES_PER_PART"
        max_rows_per_split=$(((max_frames_per_split + COLUMN - 1) / COLUMN))
        echo "使用用户设置: 每部分最多 $max_frames_per_split 帧 ($max_rows_per_split 行)"
    else
        # 使用原有的尺寸限制逻辑
        local header_height=310  # 预留头部空间
        local available_height=$((max_dimension - header_height))
        max_rows_per_split=$((available_height / (FRAME_HEIGHT + GAP)))

        # 确保每个分割图至少有一行
        if [ "$max_rows_per_split" -lt 1 ]; then
            max_rows_per_split=1
        fi

        max_frames_per_split=$((max_rows_per_split * COLUMN))
        echo "使用尺寸限制: 每部分最多 $max_frames_per_split 帧 ($max_rows_per_split 行)"
    fi

    # 计算总行数
    local total_rows=$(((total_frames + COLUMN - 1) / COLUMN))

    # 计算需要的分割图数量
    local total_splits=$(((total_frames + max_frames_per_split - 1) / max_frames_per_split))

    echo "总帧数: $total_frames"
    echo "每个分割图最大帧数: $max_frames_per_split"
    echo "将生成 $total_splits 个分割图"
    echo "分割策略: 前 $((total_splits - 1)) 个分割图各包含 $max_frames_per_split 帧，最后一个分割图包含剩余帧"

    # 暂时禁用并行分割图生成，因为ImageMagick在并行环境中有资源竞争问题
    # 场景检测的并行优化已经提供了主要的性能提升
    echo -e "${CYAN}使用串行分割图生成 (避免ImageMagick资源竞争)${NC}"
    generate_split_preview_serial "$output_file" "$total_splits" "$max_frames_per_split" "${frame_files[@]}"
}

# 串行分割图生成
generate_split_preview_serial() {
    local output_file="$1"
    local total_splits="$2"
    local max_frames_per_split="$3"
    shift 3
    local frame_files=("$@")
    local total_frames=${#frame_files[@]}

    # 生成每个分割图
    local split_files=()
    local frame_index=0

    for ((split=1; split<=total_splits; split++)); do
        local split_output_file="${output_file%.*}_part${split}.${FORMAT}"
        echo -e "${CYAN}生成分割图 $split/$total_splits: $(basename "$split_output_file")${NC}"

        # 计算当前分割图的帧数
        local current_frames_count
        if [ $split -lt $total_splits ]; then
            # 前面的分割图都使用最大帧数
            current_frames_count=$max_frames_per_split
        else
            # 最后一个分割图包含剩余的所有帧
            current_frames_count=$((total_frames - frame_index))
        fi

        local end_frame_index=$((frame_index + current_frames_count - 1))

        # 确保不超出总帧数
        if [ $end_frame_index -ge $total_frames ]; then
            end_frame_index=$((total_frames - 1))
            current_frames_count=$((end_frame_index - frame_index + 1))
        fi

        # 计算当前分割图的行数
        local current_rows=$(((current_frames_count + COLUMN - 1) / COLUMN))

        local current_frames=()
        for ((i=frame_index; i<=end_frame_index; i++)); do
            current_frames+=("${frame_files[i]}")
        done

        echo "处理帧 $((frame_index + 1)) 到 $((end_frame_index + 1)) (共 ${#current_frames[@]} 帧，${current_rows}行)"

        # 生成分割信息
        local part_info="第${split}部分 (共${total_splits}部分)"

        # 生成当前分割图
        if generate_single_grid_with_part "${current_frames[@]}" "$split_output_file" "$part_info"; then
            split_files+=("$split_output_file")
            echo -e "${GREEN}分割图 $split 生成完成 (${current_rows}行)${NC}"
        else
            echo -e "${RED}分割图 $split 生成失败${NC}"
            return 1
        fi

        frame_index=$((end_frame_index + 1))
    done

    echo -e "${GREEN}多图片分割完成，共生成 ${#split_files[@]} 个文件:${NC}"
    for split_file in "${split_files[@]}"; do
        echo "  - $(basename "$split_file")"
    done

    # 不生成重复的主预览图，分割图已经包含了所有内容
    echo -e "${GREEN}分割模式：主预览图为 $(basename "${split_files[0]}")${NC}"
    echo -e "${YELLOW}提示：所有内容已分割到 ${#split_files[@]} 个文件中，无需额外的主预览图${NC}"

    return 0
}

# 注意：原有的并行分割图生成函数已移除，因为存在ImageMagick资源竞争问题

# 生成单个网格图（带分割信息）
generate_single_grid_with_part() {
    local output_file="${@: -1}"  # 最后一个参数是输出文件
    local part_info="${@: -2:1}"  # 倒数第二个参数是分割信息
    local frames=("${@:1:$#-2}")  # 前面的参数是帧文件数组

    generate_single_grid_internal "${frames[@]}" "$output_file" "$part_info"
}

# 生成单个网格图（从帧数组）
generate_single_grid() {
    local output_file="${@: -1}"  # 最后一个参数是输出文件
    local frames=("${@:1:$#-1}")  # 前面的参数是帧文件数组

    generate_single_grid_internal "${frames[@]}" "$output_file" ""
}

# 内部网格生成函数
generate_single_grid_internal() {
    local output_file="${@: -1}"  # 最后一个参数是输出文件
    local part_info="${@: -2:1}"  # 倒数第二个参数是分割信息（可能为空）
    local frames=("${@:1:$#-2}")  # 前面的参数是帧文件数组

    local total_frames=${#frames[@]}
    local rows=$(((total_frames + COLUMN - 1) / COLUMN))

    echo "生成 ${COLUMN}列 x ${rows}行 网格图"

    # 创建临时文件
    local row_files=()
    local temp_grid_file="$TEMP_DIR/split_grid_temp.$FORMAT"
    local temp_header_file="$TEMP_DIR/split_header_temp.$FORMAT"

    # 逐行处理
    for ((row=0; row<rows; row++)); do
        local row_file="$TEMP_DIR/split_row_$row.$FORMAT"
        local start_idx=$((row * COLUMN))
        local row_frames=()

        # 收集当前行的帧
        for ((col=0; col<COLUMN; col++)); do
            local frame_idx=$((start_idx + col))
            if [ $frame_idx -lt $total_frames ]; then
                row_frames+=("${frames[frame_idx]}")
            fi
        done

        # 生成行图片
        if [ ${#row_frames[@]} -gt 0 ]; then
            if [ "$GAP" -gt 0 ] && [ ${#row_frames[@]} -gt 1 ]; then
                # 有间距的拼接
                local temp_frames=()
                for ((i=0; i<${#row_frames[@]}; i++)); do
                    temp_frames+=("${row_frames[i]}")
                    if [ $i -lt $((${#row_frames[@]} - 1)) ]; then
                        local spacer_file="$TEMP_DIR/split_spacer_h_${row}.$FORMAT"
                        local frame_height=$(magick identify -format "%h" "${row_frames[i]}" 2>/dev/null)
                        magick -size ${GAP}x${frame_height} xc:"#ffffff" "$spacer_file" 2>/dev/null
                        temp_frames+=("$spacer_file")
                    fi
                done

                magick "${temp_frames[@]}" +append "$row_file" 2>/dev/null
                rm -f "$TEMP_DIR"/split_spacer_h_${row}.$FORMAT
            else
                # 无间距拼接
                magick "${row_frames[@]}" +append "$row_file" 2>/dev/null
            fi

            if [ ! -f "$row_file" ]; then
                echo -e "${RED}错误: 行 $row 拼接失败${NC}"
                return 1
            fi

            row_files+=("$row_file")
        fi
    done

    # 垂直拼接所有行
    if [ "$GAP" -gt 0 ] && [ ${#row_files[@]} -gt 1 ]; then
        # 有间距的垂直拼接
        local temp_rows=()
        for ((i=0; i<${#row_files[@]}; i++)); do
            temp_rows+=("${row_files[i]}")
            if [ $i -lt $((${#row_files[@]} - 1)) ]; then
                local spacer_file="$TEMP_DIR/split_spacer_v_${i}.$FORMAT"
                local row_width=$(magick identify -format "%w" "${row_files[i]}" 2>/dev/null)
                magick -size ${row_width}x${GAP} xc:"#ffffff" "$spacer_file" 2>/dev/null
                temp_rows+=("$spacer_file")
            fi
        done

        magick "${temp_rows[@]}" -append "$temp_grid_file" 2>/dev/null
        rm -f "$TEMP_DIR"/split_spacer_v_*.$FORMAT
    else
        # 无间距拼接
        magick "${row_files[@]}" -append "$temp_grid_file" 2>/dev/null
    fi

    # 检查生成的网格图是否成功
    if [ ! -f "$temp_grid_file" ]; then
        echo -e "${RED}错误: 网格图生成失败${NC}"
        return 1
    fi

    # 获取网格图宽度用于创建头部
    local grid_width=$(magick identify -format "%w" "$temp_grid_file" 2>/dev/null)

    # 创建信息头部
    create_info_header "$temp_header_file" "$grid_width" "$part_info"

    # 最终拼接
    magick "$temp_header_file" \
        -size ${grid_width}x8 xc:"#ffffff" \
        "$temp_grid_file" \
        -append \
        -quality $QUALITY \
        "$output_file" 2>/dev/null

    # 清理临时文件
    rm -f "${row_files[@]}" "$temp_grid_file" "$temp_header_file"

    return 0
}

# 注意：并行分割图生成功能已移除，因为ImageMagick在并行环境中存在资源竞争问题
# 场景检测的并行优化已经提供了主要的性能提升

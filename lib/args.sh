#!/bin/bash
# args.sh - 参数解析和验证

# 默认参数（将从配置文件覆盖）
DEFAULT_INTERVAL=10
DEFAULT_QUALITY=100
DEFAULT_COLUMN=5
DEFAULT_MODE="time"
DEFAULT_MIN_INTERVAL=30
DEFAULT_MAX_INTERVAL=300
DEFAULT_SCENE_THRESHOLD=0.3
DEFAULT_FONT_FILE="./font/LXGWWenKai-Medium.ttf"
DEFAULT_GAP=5
DEFAULT_FORMAT="webp"
DEFAULT_GENERATE_HTML_REPORT=false
DEFAULT_HTML_TITLE="视频预览图报告"
DEFAULT_HTML_THEME="modern"
ENABLE_PARALLEL_PROCESSING=true
DEFAULT_PARALLEL_JOBS="auto"
ENABLE_KEYFRAME_DETECTION=true
DEFAULT_KEYFRAME_MIN_INTERVAL=5
# 分批生成默认参数
DEFAULT_MAX_FRAMES_PER_PART=0  # 0表示使用尺寸限制逻辑，>0表示按帧数分批

# 运行时参数
INTERVAL=""
OUTPUT=""
WIDTH=""
QUALITY=""
COLUMN=""
FONT_FILE=""
MODE=""
MIN_INTERVAL=""
MAX_INTERVAL=""
SCENE_THRESHOLD=""
GAP=""
FORMAT=""
GENERATE_HTML_REPORT=false
HTML_TITLE=""
HTML_THEME=""
PARALLEL_JOBS=""
KEYFRAME_MIN_INTERVAL=""
FORCE_OVERWRITE=false
USE_PARAMETER_SUFFIX=false
# 分批生成运行时参数
MAX_FRAMES_PER_PART=""
FORCE_SPLIT=false  # 保留用于命令行强制分批

# 应用默认配置
apply_defaults() {
    # 如果参数未设置，使用配置文件中的默认值
    [ -z "$INTERVAL" ] && INTERVAL="$DEFAULT_INTERVAL"
    [ -z "$QUALITY" ] && QUALITY="$DEFAULT_QUALITY"
    [ -z "$COLUMN" ] && COLUMN="$DEFAULT_COLUMN"
    [ -z "$MODE" ] && MODE="$DEFAULT_MODE"
    [ -z "$MIN_INTERVAL" ] && MIN_INTERVAL="$DEFAULT_MIN_INTERVAL"
    [ -z "$MAX_INTERVAL" ] && MAX_INTERVAL="$DEFAULT_MAX_INTERVAL"
    [ -z "$SCENE_THRESHOLD" ] && SCENE_THRESHOLD="$DEFAULT_SCENE_THRESHOLD"
    [ -z "$FONT_FILE" ] && FONT_FILE="$DEFAULT_FONT_FILE"
    [ -z "$GAP" ] && GAP="$DEFAULT_GAP"
    [ -z "$FORMAT" ] && FORMAT="$DEFAULT_FORMAT"

    # 应用HTML报告默认值
    [ -z "$HTML_TITLE" ] && HTML_TITLE="$DEFAULT_HTML_TITLE"
    [ -z "$HTML_THEME" ] && HTML_THEME="${DEFAULT_HTML_THEME:-modern}"

    # 应用时间跳过默认值
    [ -z "$SKIP_START" ] && SKIP_START="${DEFAULT_SKIP_START:-0}"
    [ -z "$SKIP_END" ] && SKIP_END="${DEFAULT_SKIP_END:-0}"

    # 应用并行处理默认值
    if [ -z "$PARALLEL_JOBS" ]; then
        PARALLEL_JOBS="$DEFAULT_PARALLEL_JOBS"
    fi

    # 处理auto值
    if [ "$PARALLEL_JOBS" = "auto" ]; then
        PARALLEL_JOBS=$(detect_cpu_cores)
    fi

    # 应用关键帧检测默认值
    [ -z "$KEYFRAME_MIN_INTERVAL" ] && KEYFRAME_MIN_INTERVAL="$DEFAULT_KEYFRAME_MIN_INTERVAL"

    # 应用分批生成默认值
    [ -z "$MAX_FRAMES_PER_PART" ] && MAX_FRAMES_PER_PART="$DEFAULT_MAX_FRAMES_PER_PART"
}

# 显示帮助信息
print_help() {
    echo "视频预览图生成工具"
    echo ""
    echo "用法:"
    echo "  $0 <video_file_or_directory> [选项]"
    echo ""
    echo "可选参数:"
    echo "  --mode <time|scene|keyframe>  截图模式 (默认: time)"
    echo "    time                  固定时间间隔截图"
    echo "    scene                 场景检测模式（基于视觉内容变化的智能截图）"
    echo "    keyframe              关键帧检测模式（基于I帧的智能截图）"
    echo "  --interval <seconds>    时间模式的截图间隔，单位秒 (默认: 10)"
    echo "  --min-interval <sec>    智能模式最小间隔，单位秒 (默认: 30)"
    echo "  --max-interval <sec>    智能模式最大间隔，单位秒 (默认: 300)"
    echo "  --scene-threshold <0.1-1.0>  场景切换敏感度 (默认: 0.3)"
    echo "  --keyframe-min <seconds>     关键帧模式最小间隔，单位秒 (默认: 5)"
    echo "  --output <directory>    输出目录 (默认: 视频同目录)"
    echo "  --width <pixels>        输出图片宽度 (默认: 视频原始宽度)"
    echo "  --quality <1-100>       图片质量，数值越大质量越高 (默认: 100)"
    echo "  --column <number>       预览图列数 (默认: 5)"
    echo "  --gap <pixels>          网格图之间的间距，单位像素 (默认: 5)"
    echo "  --format <webp|jpg|png> 输出格式 (默认: webp)"
    echo "  --font <path>           字体文件路径 (默认: ./font/LXGWWenKai-Medium.ttf)"
    echo "  --config <path>         指定配置文件路径"
    echo "  --preset <name>         使用预设配置 (movie|lecture|quick|dynamic|batch)"
    echo "  --html                  生成HTML报告"
    echo "  --html-title <title>    HTML报告标题"
    echo "  --html-theme <theme>    HTML报告主题 (modern|classic|dark)"
    echo "  --jobs <number>         并行处理作业数 (默认: auto)"
    echo "  --no-parallel           禁用并行处理"
    echo "  --skip-start <seconds>  跳过开头n秒 (默认: 0)"
    echo "  --skip-end <seconds>    跳过结尾n秒 (默认: 0)"
    echo "  --output-dir <path>     指定输出目录"
    echo "  --wizard                交互式配置向导"
    echo "  --force                 强制覆盖已存在的文件"
    echo "  --suffix                文件名包含参数后缀"
    echo "  --max-frames-per-part <n>  每个部分最大帧数，用于分批生成 (默认: 0，使用尺寸限制)"
    echo "  --force-split           强制启用分批生成模式（忽略帧数限制）"
    echo "  --help                  显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 ./video.mp4"
    echo "  $0 ./videos/"
    echo "  $0 ./video.mp4 --interval 5 --column 4 --quality 85"
    echo "  $0 ./video.mp4 --mode smart --min-interval 60 --max-interval 300"
    echo "  $0 ./video.mp4 --skip-start 30 --skip-end 60  # 跳过开头30秒和结尾60秒"
    echo "  $0 ./video.mp4 --output-dir ./results/        # 输出到指定目录"
    echo "  $0 --wizard                                   # 交互式配置向导"
    echo "  $0 ./video.mp4 --font /path/to/font.ttf --quality 95"
    echo "  $0 ./video.mp4 --preset movie    # 使用电影截图预设"
    echo "  $0 ./video.mp4 --force --suffix  # 强制覆盖并使用参数后缀命名"
    echo "  $0 ./video.mp4 --max-frames-per-part 50  # 每个部分最多50张图"
    echo "  $0 ./video.mp4 --force-split      # 强制分批生成多个文件"
}

# 解析命令行参数
parse_arguments() {
    # 记录原始参数用于显示
    ORIGINAL_ARGS="$*"

    if [ $# -eq 0 ]; then
        print_help
        exit 1
    fi

    # 先检查是否是帮助命令
    if [ "$1" = "--help" ]; then
        print_help
        exit 0
    fi

    # 检查是否是向导模式
    if [ "$1" = "--wizard" ]; then
        WIZARD_MODE=true
        shift
    else
        INPUT_PATH="$1"
        shift
    fi

    while [ $# -gt 0 ]; do
        case $1 in
            --help)
                print_help
                exit 0
                ;;
            --interval)
                INTERVAL="$2"
                shift 2
                ;;
            --output)
                OUTPUT="$2"
                shift 2
                ;;
            --width)
                WIDTH="$2"
                shift 2
                ;;
            --quality)
                QUALITY="$2"
                shift 2
                ;;
            --column)
                COLUMN="$2"
                shift 2
                ;;
            --gap)
                GAP="$2"
                shift 2
                ;;
            --format)
                FORMAT="$2"
                shift 2
                ;;
            --font)
                FONT_FILE="$2"
                shift 2
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --preset)
                PRESET_NAME="$2"
                shift 2
                ;;
            --mode)
                MODE="$2"
                shift 2
                ;;
            --min-interval)
                MIN_INTERVAL="$2"
                shift 2
                ;;
            --max-interval)
                MAX_INTERVAL="$2"
                shift 2
                ;;
            --scene-threshold)
                SCENE_THRESHOLD="$2"
                shift 2
                ;;
            --keyframe-min)
                KEYFRAME_MIN_INTERVAL="$2"
                shift 2
                ;;
            --html)
                GENERATE_HTML_REPORT=true
                HTML_REPORT_ENABLED_BY_USER=true
                shift 1
                ;;
            --html-title)
                HTML_TITLE="$2"
                shift 2
                ;;
            --html-theme)
                HTML_THEME="$2"
                shift 2
                ;;
            --jobs)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            --no-parallel)
                ENABLE_PARALLEL_PROCESSING=false
                PARALLEL_DISABLED_BY_USER=true
                shift 1
                ;;
            --force)
                FORCE_OVERWRITE=true
                FORCE_ENABLED_BY_USER=true
                shift 1
                ;;
            --suffix)
                USE_PARAMETER_SUFFIX=true
                SUFFIX_ENABLED_BY_USER=true
                shift 1
                ;;
            --skip-start)
                SKIP_START="$2"
                shift 2
                ;;
            --skip-end)
                SKIP_END="$2"
                shift 2
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --wizard)
                WIZARD_MODE=true
                shift 1
                ;;
            --max-frames-per-part)
                MAX_FRAMES_PER_PART="$2"
                shift 2
                ;;
            --force-split)
                FORCE_SPLIT=true
                shift 1
                ;;
            *)
                echo -e "${RED}错误: 未知参数 $1${NC}"
                print_help
                exit 1
                ;;
        esac
    done

    # 加载配置文件（优先级：预设 > 自定义配置 > 默认配置）
    if [ -n "$PRESET_NAME" ]; then
        # 直接使用预设名称
        local preset_config="$SCRIPT_DIR/presets/${PRESET_NAME}.conf"

        if ! load_and_validate_config "$preset_config" "preset"; then
            echo -e "${RED}错误: 预设配置加载失败: $PRESET_NAME${NC}"
            echo -e "${YELLOW}可用预设:${NC}"
            echo -e "${YELLOW}  movie, lecture, quick, dynamic, batch${NC}"
            exit 1
        fi
    elif [ -n "$CONFIG_FILE" ]; then
        if ! load_and_validate_config "$CONFIG_FILE" "custom"; then
            echo -e "${RED}错误: 自定义配置加载失败: $CONFIG_FILE${NC}"
            exit 1
        fi
    fi
    # 注意：默认配置已内置到preview.sh中，无需加载外部配置文件

    # 应用默认值
    apply_defaults

    # 验证配置逻辑
    if ! validate_config_logic; then
        exit 1
    fi
}

# 验证参数
validate_args() {
    # 验证输入路径
    # 向导模式不需要验证输入路径
    if [ "$WIZARD_MODE" != true ] && [ ! -e "$INPUT_PATH" ]; then
        error_exit "输入路径不存在: $INPUT_PATH"
    fi
    
    # 验证模式参数
    if [[ "$MODE" != "time" && "$MODE" != "scene" && "$MODE" != "keyframe" ]]; then
        error_exit "mode必须是 'time', 'scene' 或 'keyframe'"
    fi
    
    # 验证数值参数
    if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [ "$INTERVAL" -le 0 ]; then
        error_exit "interval必须是正整数"
    fi
    
    if ! [[ "$MIN_INTERVAL" =~ ^[0-9]+$ ]] || [ "$MIN_INTERVAL" -le 0 ]; then
        error_exit "min-interval必须是正整数"
    fi
    
    if ! [[ "$MAX_INTERVAL" =~ ^[0-9]+$ ]] || [ "$MAX_INTERVAL" -le 0 ]; then
        error_exit "max-interval必须是正整数"
    fi
    
    if [ "$MIN_INTERVAL" -ge "$MAX_INTERVAL" ]; then
        error_exit "min-interval必须小于max-interval"
    fi
    
    # 验证场景检测阈值
    if ! [[ "$SCENE_THRESHOLD" =~ ^0\.[0-9]+$|^1\.0*$ ]] || \
       (( $(echo "$SCENE_THRESHOLD < 0.1" | bc -l) )) || \
       (( $(echo "$SCENE_THRESHOLD > 1.0" | bc -l) )); then
        error_exit "scene-threshold必须是0.1-1.0之间的小数"
    fi
    
    if [ -n "$WIDTH" ] && (! [[ "$WIDTH" =~ ^[0-9]+$ ]] || [ "$WIDTH" -le 0 ]); then
        error_exit "width必须是正整数"
    fi
    
    if ! [[ "$QUALITY" =~ ^[0-9]+$ ]] || [ "$QUALITY" -lt 1 ] || [ "$QUALITY" -gt 100 ]; then
        error_exit "quality必须是1-100之间的整数"
    fi
    
    if ! [[ "$COLUMN" =~ ^[0-9]+$ ]] || [ "$COLUMN" -le 0 ]; then
        error_exit "column必须是正整数"
    fi

    if ! [[ "$GAP" =~ ^[0-9]+$ ]] || [ "$GAP" -lt 0 ]; then
        error_exit "gap必须是非负整数"
    fi

    # 验证输出格式
    if [[ "$FORMAT" != "webp" && "$FORMAT" != "jpg" && "$FORMAT" != "png" ]]; then
        error_exit "format必须是 'webp', 'jpg' 或 'png'"
    fi

    # 验证HTML主题（仅在启用HTML报告时）
    if [ "$GENERATE_HTML_REPORT" = true ]; then
        # 确保HTML_THEME有默认值
        if [ -z "$HTML_THEME" ]; then
            HTML_THEME="modern"
        fi

        if [[ "$HTML_THEME" != "modern" && "$HTML_THEME" != "simple" ]]; then
            error_exit "html-theme必须是 'modern' 或 'simple'，当前值: '$HTML_THEME'"
        fi
    fi

    # 验证跳过时间参数
    if ! [[ "$SKIP_START" =~ ^[0-9]+$ ]] || [ "$SKIP_START" -lt 0 ]; then
        error_exit "skip-start必须是非负整数，当前值: '$SKIP_START'"
    fi

    if ! [[ "$SKIP_END" =~ ^[0-9]+$ ]] || [ "$SKIP_END" -lt 0 ]; then
        error_exit "skip-end必须是非负整数，当前值: '$SKIP_END'"
    fi

    # 验证并行作业数
    if [ "$PARALLEL_JOBS" != "auto" ]; then
        if ! [[ "$PARALLEL_JOBS" =~ ^[0-9]+$ ]] || [ "$PARALLEL_JOBS" -lt 1 ] || [ "$PARALLEL_JOBS" -gt 16 ]; then
            error_exit "jobs必须是1-16之间的整数或'auto'"
        fi
    fi

    # 验证关键帧最小间隔
    if ! [[ "$KEYFRAME_MIN_INTERVAL" =~ ^[0-9]+$ ]] || [ "$KEYFRAME_MIN_INTERVAL" -lt 1 ]; then
        error_exit "keyframe-min必须是正整数"
    fi

    # 验证分批生成参数
    if ! [[ "$MAX_FRAMES_PER_PART" =~ ^[0-9]+$ ]] || [ "$MAX_FRAMES_PER_PART" -lt 0 ]; then
        error_exit "max-frames-per-part必须是非负整数，0表示不限制"
    fi
}

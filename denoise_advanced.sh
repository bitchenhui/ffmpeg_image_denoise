#!/bin/bash

# FFmpeg图像降噪算法高级脚本
# 支持配置文件预设、批量处理、参数优化等功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 检测操作系统并设置FFmpeg路径
detect_os_and_set_ffmpeg_paths() {
    local os_type=$(uname -s)
    local script_dir=$(dirname "$(readlink -f "$0" || echo "$0")")
    
    case "$os_type" in
        "Darwin")
            # macOS环境
            FFMPEG_PATH="$script_dir/ffmpeg/mac/ffmpeg"
            FFPROBE_PATH="$script_dir/ffmpeg/mac/ffprobe"
            echo -e "${BLUE}检测到macOS环境，使用本地FFmpeg: $FFMPEG_PATH${NC}"
            ;;
        "Linux")
            # Linux环境
            FFMPEG_PATH="$script_dir/ffmpeg/linux/ffmpeg"
            FFPROBE_PATH="$script_dir/ffmpeg/linux/ffprobe"
            echo -e "${BLUE}检测到Linux环境，使用本地FFmpeg: $FFMPEG_PATH${NC}"
            ;;
        *)
            # 其他环境，尝试使用系统PATH中的ffmpeg
            FFMPEG_PATH="ffmpeg"
            FFPROBE_PATH="ffprobe"
            echo -e "${YELLOW}检测到未知操作系统: $os_type，尝试使用系统PATH中的FFmpeg${NC}"
            ;;
    esac
    
    # 检查本地FFmpeg是否存在
    if [ -f "$FFMPEG_PATH" ] && [ -x "$FFMPEG_PATH" ]; then
        echo -e "${GREEN}本地FFmpeg可执行文件存在且可执行${NC}"
    elif [ -f "$FFMPEG_PATH" ]; then
        echo -e "${YELLOW}本地FFmpeg文件存在但不可执行，尝试设置执行权限${NC}"
        chmod +x "$FFMPEG_PATH" 2>/dev/null || {
            echo -e "${RED}无法设置执行权限，将使用系统PATH中的FFmpeg${NC}"
            FFMPEG_PATH="ffmpeg"
        }
    else
        echo -e "${YELLOW}本地FFmpeg文件不存在，将使用系统PATH中的FFmpeg${NC}"
        FFMPEG_PATH="ffmpeg"
    fi
    
    # 检查本地ffprobe是否存在
    if [ -f "$FFPROBE_PATH" ] && [ -x "$FFPROBE_PATH" ]; then
        echo -e "${GREEN}本地ffprobe可执行文件存在且可执行${NC}"
    elif [ -f "$FFPROBE_PATH" ]; then
        echo -e "${YELLOW}本地ffprobe文件存在但不可执行，尝试设置执行权限${NC}"
        chmod +x "$FFPROBE_PATH" 2>/dev/null || {
            echo -e "${RED}无法设置执行权限，将使用系统PATH中的ffprobe${NC}"
            FFPROBE_PATH="ffprobe"
        }
    else
        echo -e "${YELLOW}本地ffprobe文件不存在，将使用系统PATH中的ffprobe${NC}"
        FFPROBE_PATH="ffprobe"
    fi
    
    echo ""
}

# 默认参数
INPUT_IMAGE=""
OUTPUT_DIR="denoised_output"
QUALITY=95
FORMAT="auto"
CONFIG_FILE="denoise_presets.conf"
SELECTED_PRESET=""
BATCH_MODE=false
COMPARE_MODE=false
VERBOSE=false

# FFmpeg路径变量
FFMPEG_PATH=""
FFPROBE_PATH=""

# 降噪算法参数 - 使用普通数组以兼容老版本bash
ATADENOISE_PARAMS_0a="0.02"
ATADENOISE_PARAMS_0b="0.04"
ATADENOISE_PARAMS_1a="0.02"
ATADENOISE_PARAMS_1b="0.04"
ATADENOISE_PARAMS_2a="0.02"
ATADENOISE_PARAMS_2b="0.04"
ATADENOISE_PARAMS_s="9"
ATADENOISE_PARAMS_algorithm="p"
ATADENOISE_PARAMS_0s="32767"
ATADENOISE_PARAMS_1s="32767"
ATADENOISE_PARAMS_2s="32767"

VAGUEDENOISER_PARAMS_threshold="2.0"
VAGUEDENOISER_PARAMS_method="garrote"
VAGUEDENOISER_PARAMS_nsteps="6"
VAGUEDENOISER_PARAMS_percent="85"
VAGUEDENOISER_PARAMS_type="universal"

FFTDNOIZ_PARAMS_sigma="1.0"
FFTDNOIZ_PARAMS_amount="1.0"
FFTDNOIZ_PARAMS_block="32"
FFTDNOIZ_PARAMS_overlap="0.5"
FFTDNOIZ_PARAMS_method="0"

OWDENOISE_PARAMS_depth="8"
OWDENOISE_PARAMS_luma_strength="1.0"
OWDENOISE_PARAMS_chroma_strength="1.0"

DCTDNOIZ_PARAMS_sigma="4.5"
DCTDNOIZ_PARAMS_overlap="-1"
DCTDNOIZ_PARAMS_n="3"

# 统计信息
PROCESSING_TIMES_atadenoise=""
PROCESSING_TIMES_vaguedenoiser=""
PROCESSING_TIMES_fftdnoiz=""
PROCESSING_TIMES_owdenoise=""
PROCESSING_TIMES_dctdnoiz=""

OUTPUT_SIZES_atadenoise=""
OUTPUT_SIZES_vaguedenoiser=""
OUTPUT_SIZES_fftdnoiz=""
OUTPUT_SIZES_owdenoise=""
OUTPUT_SIZES_dctdnoiz=""

# 初始化默认参数
init_default_params() {
    # ATADenoise默认参数
    ATADENOISE_PARAMS_0a="0.02"
    ATADENOISE_PARAMS_0b="0.04"
    ATADENOISE_PARAMS_1a="0.02"
    ATADENOISE_PARAMS_1b="0.04"
    ATADENOISE_PARAMS_2a="0.02"
    ATADENOISE_PARAMS_2b="0.04"
    ATADENOISE_PARAMS_s="9"
    ATADENOISE_PARAMS_a="0"
    ATADENOISE_PARAMS_p="7"
    ATADENOISE_PARAMS_0s="32767"
    ATADENOISE_PARAMS_1s="32767"
    ATADENOISE_PARAMS_2s="32767"

    # VagueDenoiser默认参数
    VAGUEDENOISER_PARAMS_threshold="2.0"
    VAGUEDENOISER_PARAMS_method="garrote"
    VAGUEDENOISER_PARAMS_nsteps="6"
    VAGUEDENOISER_PARAMS_percent="85"
    VAGUEDENOISER_PARAMS_type="universal"

    # FFTdnoiz默认参数
    FFTDNOIZ_PARAMS_sigma="1.0"
    FFTDNOIZ_PARAMS_amount="1.0"
    FFTDNOIZ_PARAMS_block="32"
    FFTDNOIZ_PARAMS_overlap="0.5"
    FFTDNOIZ_PARAMS_method="0"

    # OWDenoise默认参数
    OWDENOISE_PARAMS_depth="8"
    OWDENOISE_PARAMS_luma_strength="1.0"
    OWDENOISE_PARAMS_chroma_strength="1.0"

    # DCTdnoiz默认参数
    DCTDNOIZ_PARAMS_sigma="4.5"
    DCTDNOIZ_PARAMS_overlap="-1"
    DCTDNOIZ_PARAMS_n="3"
}

# 显示帮助信息
show_help() {
    echo -e "${BLUE}FFmpeg图像降噪算法高级脚本${NC}"
    echo ""
    echo "用法: $0 [选项] <输入图像>"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  -o, --output <目录>     指定输出目录 (默认: denoised_output)"
    echo "  -q, --quality <质量>    设置输出质量 (默认: 95)"
    echo "  -f, --format <格式>     设置输出格式 (默认: auto，自动检测)"
    echo "  -a, --algorithm <算法>  指定要使用的算法 (默认: all)"
    echo "  -p, --params <参数>     设置算法参数 (格式: 算法:参数名=值)"
    echo "  -c, --config <文件>     指定配置文件 (默认: denoise_presets.conf)"
    echo "  -P, --preset <预设>     使用配置文件中的预设"
    echo "  -b, --batch             批量处理模式"
    echo "  -C, --compare           比较模式，生成对比报告"
    echo "  -v, --verbose           详细输出模式"
    echo "  -l, --list-presets      列出所有可用预设"
    echo ""
    echo "支持的算法:"
    echo "  atadenoise    自适应时间平均降噪器"
    echo "  vaguedenoiser 小波降噪器"
    echo "  fftdnoiz      3D FFT降噪器"
    echo "  owdenoise     过完备小波降噪器"
    echo "  dctdnoiz      DCT域降噪器"
    echo ""
    echo "预设示例:"
    echo "  -P light_denoise       轻度降噪"
    echo "  -P medium_denoise      中度降噪"
    echo "  -P strong_denoise      强度降噪"
    echo "  -P video_denoise       视频降噪"
    echo "  -P fast_denoise        快速降噪"
    echo "  -P high_quality_denoise 高质量降噪"
    echo ""
    echo "参数设置示例:"
    echo "  -p 'atadenoise:0a=0.05:0b=0.08'"
    echo "  -p 'vaguedenoiser:threshold=3.0:method=soft'"
    echo ""
    echo "示例:"
    echo "  $0 input.jpg"
    echo "  $0 -P medium_denoise input.mp4"
    echo "  $0 -a atadenoise -p '0a=0.05:0b=0.08' input.jpg"
    echo "  $0 -C -P all input.jpg  # 比较所有预设"
}

# 列出所有可用预设
list_presets() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}错误: 配置文件不存在: $CONFIG_FILE${NC}"
        return 1
    fi
    
    echo -e "${CYAN}可用预设列表:${NC}"
    echo ""
    
    # 提取预设名称
    grep "^\[.*\]" "$CONFIG_FILE" | sed 's/\[//g' | sed 's/\]//g' | while read preset; do
        case $preset in
            "light_denoise")
                echo -e "  ${GREEN}$preset${NC} - 轻度降噪 (适用于轻微噪声)"
                ;;
            "medium_denoise")
                echo -e "  ${GREEN}$preset${NC} - 中度降噪 (适用于中等噪声)"
                ;;
            "strong_denoise")
                echo -e "  ${GREEN}$preset${NC} - 强度降噪 (适用于严重噪声)"
                ;;
            "video_denoise")
                echo -e "  ${GREEN}$preset${NC} - 视频降噪 (适用于视频序列)"
                ;;
            "fast_denoise")
                echo -e "  ${GREEN}$preset${NC} - 快速降噪 (适用于实时处理)"
                ;;
            "high_quality_denoise")
                echo -e "  ${GREEN}$preset${NC} - 高质量降噪 (适用于高质量输出)"
                ;;
            "gaussian_noise")
                echo -e "  ${GREEN}$preset${NC} - 高斯噪声降噪"
                ;;
            "salt_pepper_noise")
                echo -e "  ${GREEN}$preset${NC} - 椒盐噪声降噪"
                ;;
            "compression_noise")
                echo -e "  ${GREEN}$preset${NC} - 压缩伪影降噪"
                ;;
            *)
                echo -e "  ${GREEN}$preset${NC}"
                ;;
        esac
    done
    echo ""
}

# 从配置文件加载预设
load_preset() {
    local preset_name="$1"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}错误: 配置文件不存在: $CONFIG_FILE${NC}"
        return 1
    fi
    
    echo -e "${BLUE}加载预设: $preset_name${NC}"
    
    # 重置参数到默认值
    init_default_params
    
    # 查找预设部分
    local in_preset=false
    local current_section=""
    
    while IFS= read -r line; do
        # 跳过注释和空行
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
            continue
        fi
        
        # 检查是否是预设开始
        if [[ "$line" =~ ^\[.*\] ]]; then
            current_section=$(echo "$line" | sed 's/\[//g' | sed 's/\]//g')
            if [ "$current_section" = "$preset_name" ]; then
                in_preset=true
                echo -e "${GREEN}找到预设: $preset_name${NC}"
            else
                in_preset=false
            fi
            continue
        fi
        
        # 如果在目标预设中，解析参数
        if [ "$in_preset" = true ]; then
            if [[ "$line" =~ ^[[:space:]]*([^.]+)\.([^[:space:]]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
                local algorithm="${BASH_REMATCH[1]}"
                local param="${BASH_REMATCH[2]}"
                local value="${BASH_REMATCH[3]}"
                
                case $algorithm in
                    "atadenoise")
                        eval "ATADENOISE_PARAMS_$param=\"$value\""
                        ;;
                    "vaguedenoiser")
                        eval "VAGUEDENOISER_PARAMS_$param=\"$value\""
                        ;;
                    "fftdnoiz")
                        eval "FFTDNOIZ_PARAMS_$param=\"$value\""
                        ;;
                    "owdenoise")
                        eval "OWDENOISE_PARAMS_$param=\"$value\""
                        ;;
                    "dctdnoiz")
                        eval "DCTDNOIZ_PARAMS_$param=\"$value\""
                        ;;
                esac
                
                if [ "$VERBOSE" = true ]; then
                    echo "  设置 $algorithm.$param = $value"
                fi
            fi
        fi
    done < "$CONFIG_FILE"
    
    if [ "$in_preset" = false ]; then
        echo -e "${RED}错误: 未找到预设 '$preset_name'${NC}"
        return 1
    fi
    
    echo -e "${GREEN}预设加载完成${NC}"
    echo ""
}

# 解析参数设置
parse_param() {
    local param_str="$1"
    local algorithm=$(echo "$param_str" | cut -d: -f1)
    local params=$(echo "$param_str" | cut -d: -f2-)
    
    case $algorithm in
        "atadenoise")
            IFS=':' read -ra PARAM_ARRAY <<< "$params"
            for param in "${PARAM_ARRAY[@]}"; do
                if [[ $param == *"="* ]]; then
                    local key=$(echo "$param" | cut -d= -f1)
                    local value=$(echo "$param" | cut -d= -f2)
                    eval "ATADENOISE_PARAMS_$key=\"$value\""
                fi
            done
            ;;
        "vaguedenoiser")
            IFS=':' read -ra PARAM_ARRAY <<< "$params"
            for param in "${PARAM_ARRAY[@]}"; do
                if [[ $param == *"="* ]]; then
                    local key=$(echo "$param" | cut -d= -f1)
                    local value=$(echo "$param" | cut -d= -f2)
                    eval "VAGUEDENOISER_PARAMS_$key=\"$value\""
                fi
            done
            ;;
        "fftdnoiz")
            IFS=':' read -ra PARAM_ARRAY <<< "$params"
            for param in "${PARAM_ARRAY[@]}"; do
                if [[ $param == *"="* ]]; then
                    local key=$(echo "$param" | cut -d= -f1)
                    local value=$(echo "$param" | cut -d= -f2)
                    eval "FFTDNOIZ_PARAMS_$key=\"$value\""
                fi
            done
            ;;
        "owdenoise")
            IFS=':' read -ra PARAM_ARRAY <<< "$params"
            for param in "${PARAM_ARRAY[@]}"; do
                if [[ $param == *"="* ]]; then
                    local key=$(echo "$param" | cut -d= -f1)
                    local value=$(echo "$param" | cut -d= -f2)
                    eval "OWDENOISE_PARAMS_$key=\"$value\""
                fi
            done
            ;;
        "dctdnoiz")
            IFS=':' read -ra PARAM_ARRAY <<< "$params"
            for param in "${PARAM_ARRAY[@]}"; do
                if [[ $param == *"="* ]]; then
                    local key=$(echo "$param" | cut -d= -f1)
                    local value=$(echo "$param" | cut -d= -f2)
                    eval "DCTDNOIZ_PARAMS_$key=\"$value\""
                fi
            done
            ;;
        *)
            echo -e "${RED}错误: 不支持的算法 '$algorithm'${NC}"
            exit 1
            ;;
    esac
}

# 构建参数字符串函数
build_atadenoise_params() {
    local params=""
    params="0a=${ATADENOISE_PARAMS_0a}:0b=${ATADENOISE_PARAMS_0b}:1a=${ATADENOISE_PARAMS_1a}:1b=${ATADENOISE_PARAMS_1b}:2a=${ATADENOISE_PARAMS_2a}:2b=${ATADENOISE_PARAMS_2b}:s=${ATADENOISE_PARAMS_s}:a=${ATADENOISE_PARAMS_a}:p=${ATADENOISE_PARAMS_p}:0s=${ATADENOISE_PARAMS_0s}:1s=${ATADENOISE_PARAMS_1s}:2s=${ATADENOISE_PARAMS_2s}"
    echo "$params"
}

build_vaguedenoiser_params() {
    local params=""
    params="threshold=${VAGUEDENOISER_PARAMS_threshold}:method=${VAGUEDENOISER_PARAMS_method}:nsteps=${VAGUEDENOISER_PARAMS_nsteps}:percent=${VAGUEDENOISER_PARAMS_percent}:type=${VAGUEDENOISER_PARAMS_type}"
    echo "$params"
}

build_fftdnoiz_params() {
    local params=""
    params="sigma=${FFTDNOIZ_PARAMS_sigma}:amount=${FFTDNOIZ_PARAMS_amount}:block=${FFTDNOIZ_PARAMS_block}:overlap=${FFTDNOIZ_PARAMS_overlap}:method=${FFTDNOIZ_PARAMS_method}"
    echo "$params"
}

build_owdenoise_params() {
    local params=""
    params="depth=${OWDENOISE_PARAMS_depth}:luma_strength=${OWDENOISE_PARAMS_luma_strength}:chroma_strength=${OWDENOISE_PARAMS_chroma_strength}"
    echo "$params"
}

build_dctdnoiz_params() {
    local params=""
    params="sigma=${DCTDNOIZ_PARAMS_sigma}:overlap=${DCTDNOIZ_PARAMS_overlap}:n=${DCTDNOIZ_PARAMS_n}"
    echo "$params"
}

# 显示当前参数设置
show_current_params() {
    echo -e "${YELLOW}当前参数设置:${NC}"
    echo ""
    
    echo -e "${BLUE}ATADenoise参数:${NC}"
    echo "  0a = ${ATADENOISE_PARAMS_0a}"
    echo "  0b = ${ATADENOISE_PARAMS_0b}"
    echo "  1a = ${ATADENOISE_PARAMS_1a}"
    echo "  1b = ${ATADENOISE_PARAMS_1b}"
    echo "  2a = ${ATADENOISE_PARAMS_2a}"
    echo "  2b = ${ATADENOISE_PARAMS_2b}"
    echo "  s = ${ATADENOISE_PARAMS_s}"
    echo "  a = ${ATADENOISE_PARAMS_a}"
    echo "  p = ${ATADENOISE_PARAMS_p}"
    echo "  0s = ${ATADENOISE_PARAMS_0s}"
    echo "  1s = ${ATADENOISE_PARAMS_1s}"
    echo "  2s = ${ATADENOISE_PARAMS_2s}"
    echo ""
    
    echo -e "${BLUE}VagueDenoiser参数:${NC}"
    echo "  threshold = ${VAGUEDENOISER_PARAMS_threshold}"
    echo "  method = ${VAGUEDENOISER_PARAMS_method}"
    echo "  nsteps = ${VAGUEDENOISER_PARAMS_nsteps}"
    echo "  percent = ${VAGUEDENOISER_PARAMS_percent}"
    echo "  type = ${VAGUEDENOISER_PARAMS_type}"
    echo ""
    
    echo -e "${BLUE}FFTdnoiz参数:${NC}"
    echo "  sigma = ${FFTDNOIZ_PARAMS_sigma}"
    echo "  amount = ${FFTDNOIZ_PARAMS_amount}"
    echo "  block = ${FFTDNOIZ_PARAMS_block}"
    echo "  overlap = ${FFTDNOIZ_PARAMS_overlap}"
    echo "  method = ${FFTDNOIZ_PARAMS_method}"
    echo ""
    
    echo -e "${BLUE}OWDenoise参数:${NC}"
    echo "  depth = ${OWDENOISE_PARAMS_depth}"
    echo "  luma_strength = ${OWDENOISE_PARAMS_luma_strength}"
    echo "  chroma_strength = ${OWDENOISE_PARAMS_chroma_strength}"
    echo ""
    
    echo -e "${BLUE}DCTdnoiz参数:${NC}"
    echo "  sigma = ${DCTDNOIZ_PARAMS_sigma}"
    echo "  overlap = ${DCTDNOIZ_PARAMS_overlap}"
    echo "  n = ${DCTDNOIZ_PARAMS_n}"
    echo ""
}

# 检查FFmpeg是否可用
check_ffmpeg() {
    if ! command -v "$FFMPEG_PATH" &> /dev/null; then
        echo -e "${RED}错误: 未找到$FFMPEG_PATH命令${NC}"
        echo "请先安装FFmpeg: https://ffmpeg.org/download.html"
        exit 1
    fi
    
    local ffmpeg_version=$("$FFMPEG_PATH" -version | head -n1)
    echo -e "${GREEN}FFmpeg版本: $ffmpeg_version${NC}"
}

# 创建输出目录
create_output_dir() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        echo -e "${GREEN}创建输出目录: $OUTPUT_DIR${NC}"
    fi
}

# 获取文件扩展名和基本名称
get_extension() {
    local filename="$1"
    echo "${filename##*.}"
}

get_basename() {
    local filename="$1"
    echo "${filename%.*}"
}

# 自动检测输出格式
detect_output_format() {
    local input_file="$1"
    local input_ext=$(get_extension "$input_file" | tr '[:upper:]' '[:lower:]')
    
    case "$input_ext" in
        # 图像格式
        "jpg"|"jpeg")
            echo "jpg"
            ;;
        "png")
            echo "png"
            ;;
        "bmp")
            echo "bmp"
            ;;
        "tiff"|"tif")
            echo "tiff"
            ;;
        "webp")
            echo "webp"
            ;;
        # 视频格式
        "mp4"|"avi"|"mov"|"mkv"|"wmv"|"flv"|"webm")
            echo "mp4"
            ;;
        # 默认情况
        *)
            echo "mp4"
            ;;
    esac
}

# 获取文件大小（人类可读格式）
get_file_size() {
    local file="$1"
    if [ -f "$file" ]; then
        du -h "$file" | cut -f1
    else
        echo "0B"
    fi
}

# 处理ATADenoise算法
process_atadenoise() {
    local input="$1"
    local output="$2"
    local params=$(build_atadenoise_params)
    
    echo -e "${BLUE}处理ATADenoise算法...${NC}"
    if [ "$VERBOSE" = true ]; then
        echo "参数: $params"
    fi
    
    local start_time=$(date +%s)
    
    if [ "$VERBOSE" = true ]; then
        "$FFMPEG_PATH" -i "$input" -vf "atadenoise=$params" \
               -q:v "$QUALITY" -y "$output"
    else
        "$FFMPEG_PATH" -i "$input" -vf "atadenoise=$params" \
               -q:v "$QUALITY" -y "$output" 2>/dev/null
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    PROCESSING_TIMES_atadenoise=$duration
    OUTPUT_SIZES_atadenoise=$(get_file_size "$output")
    
    echo -e "${GREEN}ATADenoise处理完成，耗时: ${duration}秒${NC}"
    echo ""
}

# 处理VagueDenoiser算法
process_vaguedenoiser() {
    local input="$1"
    local output="$2"
    local params=$(build_vaguedenoiser_params)
    
    echo -e "${BLUE}处理VagueDenoiser算法...${NC}"
    if [ "$VERBOSE" = true ]; then
        echo "参数: $params"
    fi
    
    local start_time=$(date +%s)
    
    if [ "$VERBOSE" = true ]; then
        "$FFMPEG_PATH" -i "$input" -vf "vaguedenoiser=$params" \
               -q:v "$QUALITY" -y "$output"
    else
        "$FFMPEG_PATH" -i "$input" -vf "vaguedenoiser=$params" \
               -q:v "$QUALITY" -y "$output" 2>/dev/null
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    PROCESSING_TIMES_vaguedenoiser=$duration
    OUTPUT_SIZES_vaguedenoiser=$(get_file_size "$output")
    
    echo -e "${GREEN}VagueDenoiser处理完成，耗时: ${duration}秒${NC}"
    echo ""
}

# 处理FFTdnoiz算法
process_fftdnoiz() {
    local input="$1"
    local output="$2"
    local params=$(build_fftdnoiz_params)
    
    echo -e "${BLUE}处理FFTdnoiz算法...${NC}"
    if [ "$VERBOSE" = true ]; then
        echo "参数: $params"
    fi
    
    local start_time=$(date +%s)
    
    if [ "$VERBOSE" = true ]; then
        "$FFMPEG_PATH" -i "$input" -vf "fftdnoiz=$params" \
               -q:v "$QUALITY" -y "$output"
    else
        "$FFMPEG_PATH" -i "$input" -vf "fftdnoiz=$params" \
               -q:v "$QUALITY" -y "$output" 2>/dev/null
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    PROCESSING_TIMES_fftdnoiz=$duration
    OUTPUT_SIZES_fftdnoiz=$(get_file_size "$output")
    
    echo -e "${GREEN}FFTdnoiz处理完成，耗时: ${duration}秒${NC}"
    echo ""
}

# 处理OWDenoise算法
process_owdenoise() {
    local input="$1"
    local output="$2"
    local params=$(build_owdenoise_params)
    
    echo -e "${BLUE}处理OWDenoise算法...${NC}"
    if [ "$VERBOSE" = true ]; then
        echo "参数: $params"
    fi
    
    local start_time=$(date +%s)
    
    if [ "$VERBOSE" = true ]; then
        "$FFMPEG_PATH" -i "$input" -vf "owdenoise=$params" \
               -q:v "$QUALITY" -y "$output"
    else
        "$FFMPEG_PATH" -i "$input" -vf "owdenoise=$params" \
               -q:v "$QUALITY" -y "$output" 2>/dev/null
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    PROCESSING_TIMES_owdenoise=$duration
    OUTPUT_SIZES_owdenoise=$(get_file_size "$output")
    
    echo -e "${GREEN}OWDenoise处理完成，耗时: ${duration}秒${NC}"
    echo ""
}

# 处理DCTdnoiz算法
process_dctdnoiz() {
    local input="$1"
    local output="$2"
    local params=$(build_dctdnoiz_params)
    
    echo -e "${BLUE}处理DCTdnoiz算法...${NC}"
    if [ "$VERBOSE" = true ]; then
        echo "参数: $params"
    fi
    
    local start_time=$(date +%s)
    
    if [ "$VERBOSE" = true ]; then
        "$FFMPEG_PATH" -i "$input" -vf "dctdnoiz=$params" \
               -q:v "$QUALITY" -y "$output"
    else
        "$FFMPEG_PATH" -i "$input" -vf "dctdnoiz=$params" \
               -q:v "$QUALITY" -y "$output" 2>/dev/null
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    PROCESSING_TIMES_dctdnoiz=$duration
    OUTPUT_SIZES_dctdnoiz=$(get_file_size "$output")
    
    echo -e "${GREEN}DCTdnoiz处理完成，耗时: ${duration}秒${NC}"
    echo ""
}

# 生成比较报告
generate_comparison_report() {
    local input="$1"
    local basename=$(get_basename "$(basename "$input")")
    local report_file="$OUTPUT_DIR/${basename}_comparison_report.txt"
    
    echo -e "${CYAN}生成比较报告: $report_file${NC}"
    
    {
        echo "FFmpeg图像降噪算法比较报告"
        echo "================================"
        echo "输入文件: $input"
        echo "生成时间: $(date)"
        echo "输出目录: $OUTPUT_DIR"
        echo ""
        echo "算法性能比较:"
        echo "--------------------------------"
        printf "%-20s %-15s %-15s\n" "算法" "处理时间(秒)" "输出文件大小"
        echo "--------------------------------"
        
        # 检查ATADenoise
        if [ -n "$PROCESSING_TIMES_atadenoise" ]; then
            printf "%-20s %-15s %-15s\n" \
                   "atadenoise" \
                   "$PROCESSING_TIMES_atadenoise" \
                   "$OUTPUT_SIZES_atadenoise"
        fi
        
        # 检查VagueDenoiser
        if [ -n "$PROCESSING_TIMES_vaguedenoiser" ]; then
            printf "%-20s %-15s %-15s\n" \
                   "vaguedenoiser" \
                   "$PROCESSING_TIMES_vaguedenoiser" \
                   "$OUTPUT_SIZES_vaguedenoiser"
        fi
        
        # 检查FFTdnoiz
        if [ -n "$PROCESSING_TIMES_fftdnoiz" ]; then
            printf "%-20s %-15s %-15s\n" \
                   "fftdnoiz" \
                   "$PROCESSING_TIMES_fftdnoiz" \
                   "$OUTPUT_SIZES_fftdnoiz"
        fi
        
        # 检查OWDenoise
        if [ -n "$PROCESSING_TIMES_owdenoise" ]; then
            printf "%-20s %-15s %-15s\n" \
                   "owdenoise" \
                   "$PROCESSING_TIMES_owdenoise" \
                   "$OUTPUT_SIZES_owdenoise"
        fi
        
        # 检查DCTdnoiz
        if [ -n "$PROCESSING_TIMES_dctdnoiz" ]; then
            printf "%-20s %-15s %-15s\n" \
                   "dctdnoiz" \
                   "$PROCESSING_TIMES_dctdnoiz" \
                   "$OUTPUT_SIZES_dctdnoiz"
        fi
        
        echo ""
        echo "参数设置:"
        echo "--------------------------------"
        echo "ATADenoise: $(build_atadenoise_params)"
        echo "VagueDenoiser: $(build_vaguedenoiser_params)"
        echo "FFTdnoiz: $(build_fftdnoiz_params)"
        echo "OWDenoise: $(build_owdenoise_params)"
        echo "DCTdnoiz: $(build_dctdnoiz_params)"
        
        echo ""
        echo "建议:"
        echo "--------------------------------"
        echo "1. 处理时间最短: $(get_fastest_algorithm)"
        echo "2. 输出文件最小: $(get_smallest_output)"
        echo "3. 质量/速度平衡: $(get_balanced_algorithm)"
        
    } > "$report_file"
    
    echo -e "${GREEN}比较报告已生成: $report_file${NC}"
    echo ""
}

# 获取最快的算法
get_fastest_algorithm() {
    local fastest=""
    local min_time=999999
    
    # 检查ATADenoise
    if [ -n "$PROCESSING_TIMES_atadenoise" ] && [ "$PROCESSING_TIMES_atadenoise" -lt $min_time ]; then
        min_time=$PROCESSING_TIMES_atadenoise
        fastest="atadenoise"
    fi
    
    # 检查VagueDenoiser
    if [ -n "$PROCESSING_TIMES_vaguedenoiser" ] && [ "$PROCESSING_TIMES_vaguedenoiser" -lt $min_time ]; then
        min_time=$PROCESSING_TIMES_vaguedenoiser
        fastest="vaguedenoiser"
    fi
    
    # 检查FFTdnoiz
    if [ -n "$PROCESSING_TIMES_fftdnoiz" ] && [ "$PROCESSING_TIMES_fftdnoiz" -lt $min_time ]; then
        min_time=$PROCESSING_TIMES_fftdnoiz
        fastest="fftdnoiz"
    fi
    
    # 检查OWDenoise
    if [ -n "$PROCESSING_TIMES_owdenoise" ] && [ "$PROCESSING_TIMES_owdenoise" -lt $min_time ]; then
        min_time=$PROCESSING_TIMES_owdenoise
        fastest="owdenoise"
    fi
    
    # 检查DCTdnoiz
    if [ -n "$PROCESSING_TIMES_dctdnoiz" ] && [ "$PROCESSING_TIMES_dctdnoiz" -lt $min_time ]; then
        min_time=$PROCESSING_TIMES_dctdnoiz
        fastest="dctdnoiz"
    fi
    
    if [ -n "$fastest" ]; then
        echo "$fastest (${min_time}秒)"
    else
        echo "无数据"
    fi
}

# 获取输出最小的算法
get_smallest_output() {
    local smallest=""
    local min_size="999999B"
    
    # 检查ATADenoise
    if [ -n "$OUTPUT_SIZES_atadenoise" ]; then
        echo "atadenoise: $OUTPUT_SIZES_atadenoise"
        return
    fi
    
    # 检查VagueDenoiser
    if [ -n "$OUTPUT_SIZES_vaguedenoiser" ]; then
        echo "vaguedenoiser: $OUTPUT_SIZES_vaguedenoiser"
        return
    fi
    
    # 检查FFTdnoiz
    if [ -n "$OUTPUT_SIZES_fftdnoiz" ]; then
        echo "fftdnoiz: $OUTPUT_SIZES_fftdnoiz"
        return
    fi
    
    # 检查OWDenoise
    if [ -n "$OUTPUT_SIZES_owdenoise" ]; then
        echo "owdenoise: $OUTPUT_SIZES_owdenoise"
        return
    fi
    
    # 检查DCTdnoiz
    if [ -n "$OUTPUT_SIZES_dctdnoiz" ]; then
        echo "dctdnoiz: $OUTPUT_SIZES_dctdnoiz"
        return
    fi
    
    echo "无数据"
}

# 获取平衡的算法
get_balanced_algorithm() {
    echo "vaguedenoiser (推荐用于一般用途)"
}

# 主处理函数
process_image() {
    local input="$1"
    local basename=$(get_basename "$(basename "$input")")
    
    # 如果格式设置为auto，自动检测输出格式
    if [ "$FORMAT" = "auto" ]; then
        FORMAT=$(detect_output_format "$input")
        echo -e "${BLUE}自动检测输出格式: $FORMAT${NC}"
    fi
    
    echo -e "${GREEN}开始处理图像: $input${NC}"
    echo -e "${GREEN}输出目录: $OUTPUT_DIR${NC}"
    echo -e "${GREEN}输出格式: $FORMAT${NC}"
    echo ""
    
    # 显示当前参数设置
    show_current_params
    
    # 根据选择的算法进行处理
    case "$SELECTED_ALGORITHM" in
        "atadenoise")
            local output="$OUTPUT_DIR/${basename}_atadenoise.$FORMAT"
            process_atadenoise "$input" "$output"
            ;;
        "vaguedenoiser")
            local output="$OUTPUT_DIR/${basename}_vaguedenoiser.$FORMAT"
            process_vaguedenoiser "$input" "$output"
            ;;
        "fftdnoiz")
            local output="$OUTPUT_DIR/${basename}_fftdnoiz.$FORMAT"
            process_fftdnoiz "$input" "$output"
            ;;
        "owdenoise")
            local output="$OUTPUT_DIR/${basename}_owdenoise.$FORMAT"
            process_owdenoise "$input" "$output"
            ;;
        "dctdnoiz")
            local output="$OUTPUT_DIR/${basename}_dctdnoiz.$FORMAT"
            process_dctdnoiz "$input" "$output"
            ;;
        "all")
            # 处理所有算法
            local output1="$OUTPUT_DIR/${basename}_atadenoise.$FORMAT"
            local output2="$OUTPUT_DIR/${basename}_vaguedenoiser.$FORMAT"
            local output3="$OUTPUT_DIR/${basename}_fftdnoiz.$FORMAT"
            local output4="$OUTPUT_DIR/${basename}_owdenoise.$FORMAT"
            local output5="$OUTPUT_DIR/${basename}_dctdnoiz.$FORMAT"
            
            process_atadenoise "$input" "$output1"
            process_vaguedenoiser "$input" "$output2"
            process_fftdnoiz "$input" "$output3"
            process_owdenoise "$input" "$output4"
            process_dctdnoiz "$input" "$output5"
            
            # 如果启用比较模式，生成报告
            if [ "$COMPARE_MODE" = true ]; then
                generate_comparison_report "$input"
            fi
            ;;
        *)
            echo -e "${RED}错误: 不支持的算法 '$SELECTED_ALGORITHM'${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}所有处理完成！输出文件保存在: $OUTPUT_DIR${NC}"
}

# 显示文件信息
show_file_info() {
    local input="$1"
    
    echo -e "${YELLOW}输入文件信息:${NC}"
    if command -v "$FFPROBE_PATH" &> /dev/null; then
        local info=$("$FFPROBE_PATH" -v quiet -print_format json -show_format -show_streams "$input" 2>/dev/null)
        if [ -n "$info" ]; then
            local width=$(echo "$info" | jq -r '.streams[0].width // "N/A"')
            local height=$(echo "$info" | jq -r '.streams[0].height // "N/A"')
            local codec=$(echo "$info" | jq -r '.streams[0].codec_name // "N/A"')
            local duration=$(echo "$info" | jq -r '.format.duration // "N/A"')
            local size=$(get_file_size "$input")
            
            echo "  分辨率: ${width}x${height}"
            echo "  编码: $codec"
            echo "  时长: $duration 秒"
            echo "  文件大小: $size"
        else
            echo "  无法获取详细信息"
        fi
    else
        echo "  ffprobe不可用，无法获取详细信息"
    fi
    echo ""
}

# 主函数
main() {
    # 初始化默认参数
    init_default_params
    
    # 默认算法
    SELECTED_ALGORITHM="all"
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -q|--quality)
                QUALITY="$2"
                shift 2
                ;;
            -f|--format)
                FORMAT="$2"
                shift 2
                ;;
            -a|--algorithm)
                SELECTED_ALGORITHM="$2"
                shift 2
                ;;
            -p|--params)
                parse_param "$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -P|--preset)
                SELECTED_PRESET="$2"
                shift 2
                ;;
            -b|--batch)
                BATCH_MODE=true
                shift
                ;;
            -C|--compare)
                COMPARE_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -l|--list-presets)
                list_presets
                exit 0
                ;;
            -*)
                echo -e "${RED}错误: 未知选项 $1${NC}"
                show_help
                exit 1
                ;;
            *)
                INPUT_IMAGE="$1"
                shift
                ;;
        esac
    done
    
    # 检查必要参数
    if [ -z "$INPUT_IMAGE" ]; then
        echo -e "${RED}错误: 请指定输入图像文件${NC}"
        show_help
        exit 1
    fi
    
    if [ ! -f "$INPUT_IMAGE" ]; then
        echo -e "${RED}错误: 输入文件不存在: $INPUT_IMAGE${NC}"
        exit 1
    fi
    
    # 如果指定了预设，加载预设
    if [ -n "$SELECTED_PRESET" ]; then
        if [ "$SELECTED_PRESET" = "all" ]; then
            echo -e "${YELLOW}将处理所有预设...${NC}"
            # 这里可以实现批量处理所有预设的逻辑
        else
            load_preset "$SELECTED_PRESET"
        fi
    fi
    
    # 检查算法参数
    case "$SELECTED_ALGORITHM" in
        "atadenoise"|"vaguedenoiser"|"fftdnoiz"|"owdenoise"|"dctdnoiz"|"all")
            ;;
        *)
            echo -e "${RED}错误: 不支持的算法 '$SELECTED_ALGORITHM'${NC}"
            echo "支持的算法: atadenoise, vaguedenoiser, fftdnoiz, owdenoise, dctdnoiz, all"
            exit 1
            ;;
    esac
    
    # 检查依赖
    detect_os_and_set_ffmpeg_paths
    check_ffmpeg
    
    # 创建输出目录
    create_output_dir
    
    # 显示文件信息
    show_file_info "$INPUT_IMAGE"
    
    # 处理图像
    process_image "$INPUT_IMAGE"
}

# 运行主函数
main "$@"

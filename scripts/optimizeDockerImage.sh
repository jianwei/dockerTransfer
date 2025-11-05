#!/bin/bash

###############################################################################
# Docker镜像优化脚本
# 
# 功能说明：
#   该脚本用于优化Docker镜像大小，通过多种技术手段减小镜像体积：
#   1. 使用docker-squash压缩镜像层
#   2. 使用docker buildx的压缩选项
#   3. 清理不必要的文件和缓存
#   4. 使用多阶段构建优化
#
# 使用方法：
#   ./optimizeDockerImage.sh <源镜像> <目标镜像> [选项]
#
# 参数说明：
#   - 源镜像：需要优化的源镜像名称（格式：registry/image:tag）
#   - 目标镜像：优化后的目标镜像名称（格式：registry/image:tag）
#   - 选项：
#     --squash：使用docker-squash压缩镜像层
#     --compress：使用docker buildx压缩
#     --analyze：分析镜像大小
#     --platform：指定平台（格式：linux/amd64, linux/arm64等）
#
# 示例：
#   ./optimizeDockerImage.sh nginx:latest ghcr.io/user/nginx:latest --compress
#   ./optimizeDockerImage.sh vllm/vllm-openai:latest ghcr.io/user/vllm:latest --squash
#   ./optimizeDockerImage.sh nginx:latest ghcr.io/user/nginx:latest --compress --platform linux/arm64
###############################################################################

set -euo pipefail

# 颜色输出定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示使用说明
show_usage() {
    cat << EOF
用法: $0 <源镜像> <目标镜像> [选项]

参数:
  源镜像         需要优化的源镜像名称（格式：registry/image:tag）
  目标镜像       优化后的目标镜像名称（格式：registry/image:tag）

选项:
  --squash       使用docker-squash压缩镜像层（需要安装docker-squash）
  --compress     使用docker buildx压缩选项
  --analyze      分析镜像大小并显示详细报告
  --platform     指定平台（格式：linux/amd64, linux/arm64等）
  --help         显示此帮助信息

示例:
  $0 nginx:latest ghcr.io/user/nginx:latest --compress
  $0 vllm/vllm-openai:latest ghcr.io/user/vllm:latest --squash --analyze
  $0 nginx:latest ghcr.io/user/nginx:latest --compress --platform linux/arm64
EOF
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        return 1
    fi
    return 0
}

# 获取镜像大小（字节）
get_image_size() {
    local image="$1"
    docker image inspect "$image" --format='{{.Size}}' 2>/dev/null || echo "0"
}

# 格式化文件大小显示
format_size() {
    local size_bytes="$1"
    if [ "$size_bytes" -gt 1073741824 ]; then
        echo "$(( size_bytes / 1073741824 ))GB"
    elif [ "$size_bytes" -gt 1048576 ]; then
        echo "$(( size_bytes / 1048576 ))MB"
    elif [ "$size_bytes" -gt 1024 ]; then
        echo "$(( size_bytes / 1024 ))KB"
    else
        echo "${size_bytes}B"
    fi
}

# 分析镜像大小
analyze_image() {
    local image="$1"
    log_info "分析镜像: $image"
    
    if ! docker image inspect "$image" &> /dev/null; then
        log_error "镜像不存在: $image"
        return 1
    fi
    
    local size=$(get_image_size "$image")
    local formatted_size=$(format_size "$size")
    
    echo ""
    echo "=========================================="
    echo "镜像大小分析报告"
    echo "=========================================="
    echo "镜像名称: $image"
    echo "总大小: $formatted_size ($size 字节)"
    echo ""
    
    log_info "镜像层信息:"
    docker history "$image" --format "table {{.CreatedBy}}\t{{.Size}}" --no-trunc | head -20
    
    echo ""
    log_info "镜像详细信息:"
    docker image inspect "$image" --format '{{json .}}' | jq -r '
        "架构: " + .Architecture + "\n" +
        "操作系统: " + .Os + "\n" +
        "创建时间: " + .Created + "\n" +
        "层数: " + (.RootFS.Layers | length | tostring)
    ' 2>/dev/null || echo "无法获取详细信息"
    echo ""
}

# 使用docker-squash压缩镜像
squash_image() {
    local source_image="$1"
    local target_image="$2"
    
    log_info "使用docker-squash压缩镜像..."
    
    if ! check_command docker-squash; then
        log_warning "docker-squash未安装，尝试安装..."
        if command -v pip3 &> /dev/null; then
            pip3 install docker-squash || {
                log_error "无法安装docker-squash，请手动安装: pip3 install docker-squash"
                return 1
            }
        else
            log_error "未找到pip3，无法安装docker-squash"
            return 1
        fi
    fi
    
    local temp_image="${target_image}-squashed"
    
    # 压缩镜像
    if docker-squash -t "$temp_image" "$source_image"; then
        # 重新标记
        docker tag "$temp_image" "$target_image"
        docker rmi "$temp_image" || true
        log_success "镜像压缩完成"
        return 0
    else
        log_error "镜像压缩失败"
        return 1
    fi
}

# 使用docker buildx压缩镜像
compress_image() {
    local source_image="$1"
    local target_image="$2"
    local platform="${3:-linux/amd64}"  # 默认平台为linux/amd64
    
    log_info "使用docker buildx压缩镜像（平台: $platform）..."
    
    # 检查buildx是否可用
    if ! docker buildx version &> /dev/null; then
        log_error "docker buildx不可用"
        return 1
    fi
    
    # 创建临时Dockerfile
    local temp_dockerfile=$(mktemp)
    cat > "$temp_dockerfile" << EOF
FROM $source_image
EOF
    
    # 使用buildx构建压缩镜像
    local temp_tag="${target_image}-compressed"
    
    if docker buildx build \
        --platform "$platform" \
        --load \
        -t "$temp_tag" \
        --compress \
        -f "$temp_dockerfile" \
        .; then
        docker tag "$temp_tag" "$target_image"
        docker rmi "$temp_tag" || true
        rm -f "$temp_dockerfile"
        log_success "镜像压缩完成"
        return 0
    else
        rm -f "$temp_dockerfile"
        log_error "镜像压缩失败"
        return 1
    fi
}

# 清理镜像中的不必要文件（需要创建临时容器）
cleanup_image() {
    local source_image="$1"
    local target_image="$2"
    
    log_info "清理镜像中的不必要文件..."
    
    # 创建临时容器并清理
    local temp_container=$(docker create "$source_image")
    
    # 在容器中执行清理命令
    docker exec "$temp_container" sh -c "
        rm -rf /tmp/* /var/tmp/* /var/cache/* 2>/dev/null || true
        find /usr/share -name '*.md' -o -name '*.txt' -o -name '*.doc' 2>/dev/null | xargs rm -f || true
        apt-get clean 2>/dev/null || true
        yum clean all 2>/dev/null || true
    " || true
    
    # 提交为新镜像
    docker commit "$temp_container" "$target_image"
    docker rm "$temp_container"
    
    log_success "镜像清理完成"
}

# 主函数
main() {
    local source_image=""
    local target_image=""
    local use_squash=false
    local use_compress=false
    local analyze_only=false
    local platform="linux/amd64"  # 默认平台
    
    # 解析参数
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h)
                show_usage
                exit 0
                ;;
            --squash)
                use_squash=true
                shift
                ;;
            --compress)
                use_compress=true
                shift
                ;;
            --analyze)
                analyze_only=true
                shift
                ;;
            --platform)
                platform="$2"
                shift 2
                ;;
            *)
                if [ -z "$source_image" ]; then
                    source_image="$1"
                elif [ -z "$target_image" ]; then
                    target_image="$1"
                else
                    log_error "未知参数: $1"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # 验证参数
    if [ -z "$source_image" ]; then
        log_error "缺少源镜像参数"
        show_usage
        exit 1
    fi
    
    if [ "$analyze_only" = true ]; then
        analyze_image "$source_image"
        exit 0
    fi
    
    if [ -z "$target_image" ]; then
        log_error "缺少目标镜像参数"
        show_usage
        exit 1
    fi
    
    # 如果都没有指定优化方法，默认使用compress
    if [ "$use_squash" = false ] && [ "$use_compress" = false ]; then
        log_info "未指定优化方法，默认使用compress"
        use_compress=true
    fi
    
    log_info "开始优化镜像..."
    log_info "源镜像: $source_image"
    log_info "目标镜像: $target_image"
    
    # 拉取源镜像（如果不存在）
    if ! docker image inspect "$source_image" &> /dev/null; then
        log_info "拉取源镜像（平台: $platform）..."
        if docker pull --platform "$platform" "$source_image"; then
            log_success "镜像拉取成功"
        else
            log_error "无法拉取源镜像"
            exit 1
        fi
    fi
    
    # 分析原始镜像大小
    local original_size=$(get_image_size "$source_image")
    local original_formatted=$(format_size "$original_size")
    log_info "原始镜像大小: $original_formatted"
    
    # 执行优化
    local optimized_image="$source_image"
    if [ "$use_squash" = true ]; then
        squash_image "$source_image" "$target_image" || {
            log_warning "squash失败，尝试其他方法"
            optimized_image="$source_image"
        }
        optimized_image="$target_image"
    fi
    
    if [ "$use_compress" = true ]; then
        if [ "$optimized_image" = "$source_image" ]; then
            compress_image "$source_image" "$target_image" "$platform" || {
                log_error "压缩失败"
                exit 1
            }
        else
            # 如果已经squash过，对squash后的镜像进行compress
            compress_image "$optimized_image" "$target_image" "$platform" || {
                log_warning "压缩失败，但squash已成功"
            }
        fi
        optimized_image="$target_image"
    fi
    
    # 分析优化后的镜像大小
    if docker image inspect "$optimized_image" &> /dev/null; then
        local optimized_size=$(get_image_size "$optimized_image")
        local optimized_formatted=$(format_size "$optimized_size")
        local saved_bytes=$((original_size - optimized_size))
        local saved_percent=$((saved_bytes * 100 / original_size))
        
        echo ""
        echo "=========================================="
        echo "优化结果"
        echo "=========================================="
        echo "原始大小: $original_formatted"
        echo "优化后大小: $optimized_formatted"
        echo "节省空间: $(format_size $saved_bytes) ($saved_percent%)"
        echo "=========================================="
        echo ""
        
        log_success "镜像优化完成: $target_image"
        
        # 显示优化后的镜像信息
        analyze_image "$target_image"
    else
        log_error "无法找到优化后的镜像"
        exit 1
    fi
}

# 执行主函数
main "$@"


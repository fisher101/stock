#!/bin/bash
set -e

# 清理旧文件
rm -rf stock cron
echo "已清除旧构建文件"

# 同步项目代码（排除不需要的目录）
rsync -av --delete --exclude-from=<(cat <<EOF
.git
.idea
*.md
*.bat
__pycache__
.gitignore
stock/cron
stock/img
stock/docker
instock/cache
instock/log
instock/test
EOF
) ../../stock .

# 单独复制cron配置
cp -r ../../stock/cron .

# 镜像标签配置
DOCKER_REGISTRY="fisher101"
IMAGE_NAME="instock"
DATE_TAG=$(date "+%Y%m%d")
ARM_TAG="arm64"

# 构建参数
PLATFORM="linux/arm64"
BUILDX_NAME="arm64_builder"

# 初始化构建环境
if ! docker buildx inspect $BUILDX_NAME &> /dev/null; then
    docker buildx create --name $BUILDX_NAME --driver docker-container --platform $PLATFORM
    echo "已创建构建器：$BUILDX_NAME"
fi
docker buildx use $BUILDX_NAME

# 执行构建
echo "开始构建 ARM64 镜像..."
docker buildx build \
    --platform $PLATFORM \
    --tag $DOCKER_REGISTRY/$IMAGE_NAME:$ARM_TAG-$DATE_TAG \
    --tag $DOCKER_REGISTRY/$IMAGE_NAME:$ARM_TAG-latest \
    --push \
    --progress=plain \
    --cache-from type=registry,ref=$DOCKER_REGISTRY/$IMAGE_NAME:$ARM_TAG-latest \
    --cache-to type=registry,ref=$DOCKER_REGISTRY/$IMAGE_NAME:$ARM_TAG-latest,mode=max \
    .

echo "#################################################################"
echo " 镜像构建推送完成"
echo " 最新标签: $DOCKER_REGISTRY/$IMAGE_NAME:$ARM_TAG-latest"
echo " 日期标签: $DOCKER_REGISTRY/$IMAGE_NAME:$ARM_TAG-$DATE_TAG"

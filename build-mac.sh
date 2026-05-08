#!/bin/bash
# RemoteDock macOS 应用构建脚本
# 使用方法: ./build-mac.sh [debug|release]
# 默认构建 release 版本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$PROJECT_ROOT/RemoteDock.xcworkspace"
SCHEME="RemoteDockMac"

# 解析参数
BUILD_CONFIG="${1:-release}"
OUTPUT_NAME="RemoteDockMac"

case "$BUILD_CONFIG" in
debug | Debug | DEBUG)
	BUILD_CONFIG="Debug"
	OUTPUT_NAME="${OUTPUT_NAME}-Debug"
	;;
release | Release | RELEASE)
	BUILD_CONFIG="Release"
	OUTPUT_NAME="${OUTPUT_NAME}-Release"
	;;
*)
	echo -e "${RED}错误: 无效的构建配置 '$1'${NC}"
	echo "使用方法: $0 [debug|release]"
	exit 1
	;;
esac

DERIVED_DATA="$PROJECT_ROOT/build_$(echo "$BUILD_CONFIG" | tr '[:upper:]' '[:lower:]')"
OUTPUT_APP="$PROJECT_ROOT/${OUTPUT_NAME}.app"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  RemoteDock macOS 应用构建${NC}"
echo -e "${GREEN}========================================${NC}"
echo "配置: $BUILD_CONFIG"
echo "输出: $OUTPUT_APP"
echo ""

# 清理旧的构建产物
if [ -d "$OUTPUT_APP" ]; then
	echo -e "${YELLOW}清理旧的构建产物...${NC}"
	rm -rf "$OUTPUT_APP"
fi

# 构建
echo -e "${GREEN}开始构建...${NC}"
xcodebuild -workspace "$WORKSPACE" \
	-scheme "$SCHEME" \
	-configuration "$BUILD_CONFIG" \
	-derivedDataPath "$DERIVED_DATA" \
	build \
	CODE_SIGN_IDENTITY="-" \
	CODE_SIGNING_REQUIRED=YES \
	CODE_SIGNING_ALLOWED=YES \
	ONLY_ACTIVE_ARCH=NO \
	DEVELOPMENT_TEAM="TY92V4UW5Z"

# 检查构建是否成功
if [ $? -ne 0 ]; then
	echo -e "${RED}构建失败！${NC}"
	exit 1
fi

# 查找构建产物
BUILD_APP=$(find "$DERIVED_DATA/Build/Products" -name "${SCHEME}.app" -type d | head -1)

if [ -z "$BUILD_APP" ]; then
	echo -e "${RED}未找到构建产物！${NC}"
	exit 1
fi

# 复制到项目根目录
echo -e "${GREEN}复制构建产物...${NC}"
cp -R "$BUILD_APP" "$OUTPUT_APP"

# 获取版本信息
VERSION=$(defaults read "$OUTPUT_APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "未知")
BUILD_NUM=$(defaults read "$OUTPUT_APP/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "未知")
SIZE=$(du -sh "$OUTPUT_APP" | awk '{print $1}')

# 完成
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  构建完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo "位置: $OUTPUT_APP"
echo "版本: $VERSION ($BUILD_NUM)"
echo "大小: $SIZE"
echo ""
echo -e "${YELLOW}运行应用:${NC}"
echo "  open \"$OUTPUT_APP\""
echo ""
echo -e "${YELLOW}创建分发包:${NC}"
echo "  zip -r \"${OUTPUT_NAME}.zip\" \"${OUTPUT_NAME}.app\""
echo ""

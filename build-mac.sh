#!/bin/bash
# RemoteDock 应用构建脚本
# 使用方法:
#   ./build-mac.sh          # 构建 macOS 应用
#   ./build-mac.sh ios      # 构建 iOS 应用

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="$PROJECT_ROOT/RemoteDock.xcworkspace"
BUILD_CONFIG="Release"

# 解析参数
PLATFORM="${1:-mac}"

# macOS 构建函数
MAC_BUILD() {
	local SCHEME="RemoteDockMac"
	local DERIVED_DATA="$PROJECT_ROOT/build_mac"
	local OUTPUT_APP="$PROJECT_ROOT/RemoteDockMac.app"

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
	local BUILD_APP=$(find "$DERIVED_DATA/Build/Products" -name "${SCHEME}.app" -type d | head -1)

	if [ -z "$BUILD_APP" ]; then
		echo -e "${RED}未找到构建产物！${NC}"
		exit 1
	fi

	# 复制到项目根目录
	echo -e "${GREEN}复制构建产物...${NC}"
	cp -R "$BUILD_APP" "$OUTPUT_APP"

	# 获取版本信息
	local VERSION=$(defaults read "$OUTPUT_APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "未知")
	local BUILD_NUM=$(defaults read "$OUTPUT_APP/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "未知")
	local SIZE=$(du -sh "$OUTPUT_APP" | awk '{print $1}')

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
	echo "  zip -r \"RemoteDockMac.zip\" \"RemoteDockMac.app\""
	echo ""
}

# iOS 构建函数
IOS_BUILD() {
	local SCHEME="RemoteDockiOS"
	local DERIVED_DATA="$PROJECT_ROOT/build_ios"
	local OUTPUT_APP="$PROJECT_ROOT/RemoteDockiOS.app"

	echo -e "${GREEN}========================================${NC}"
	echo -e "${GREEN}  RemoteDock iOS 应用构建${NC}"
	echo -e "${GREEN}========================================${NC}"
	echo "配置: $BUILD_CONFIG"
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
		-sdk iphoneos \
		build \
		CODE_SIGN_IDENTITY="Apple Development" \
		CODE_SIGNING_REQUIRED=YES \
		CODE_SIGNING_ALLOWED=YES \
		ONLY_ACTIVE_ARCH=NO \
		DEVELOPMENT_TEAM="QSZ6C2FCXK" \
		-allowProvisioningUpdates

	# 检查构建是否成功
	if [ $? -ne 0 ]; then
		echo -e "${RED}构建失败！${NC}"
		exit 1
	fi

	# 查找构建产物
	local BUILD_APP=$(find "$DERIVED_DATA/Build/Products" -name "${SCHEME}.app" -type d | head -1)

	if [ -z "$BUILD_APP" ]; then
		echo -e "${RED}未找到构建产物！${NC}"
		exit 1
	fi

	# 复制到项目根目录
	echo -e "${GREEN}复制构建产物...${NC}"
	cp -R "$BUILD_APP" "$OUTPUT_APP"

	# 获取版本信息
	local VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$OUTPUT_APP/Info.plist" 2>/dev/null || echo "未知")
	local BUILD_NUM=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$OUTPUT_APP/Info.plist" 2>/dev/null || echo "未知")
	local SIZE=$(du -sh "$OUTPUT_APP" | awk '{print $1}')

	# 完成
	echo ""
	echo -e "${GREEN}========================================${NC}"
	echo -e "${GREEN}  构建完成！${NC}"
	echo -e "${GREEN}========================================${NC}"
	echo "位置: $OUTPUT_APP"
	echo "版本: $VERSION ($BUILD_NUM)"
	echo "大小: $SIZE"
	echo ""

	# 列出可用设备并安装
	INSTALL_TO_DEVICE "$OUTPUT_APP"
}

# 列出可用设备并安装
INSTALL_TO_DEVICE() {
	local APP_PATH="$1"

	echo -e "${CYAN}正在查找可用设备...${NC}"
	echo ""

	# 获取可用设备列表
	local DEVICES_OUTPUT=$(xcrun devicectl list devices 2>/dev/null || echo "")

	if [ -z "$DEVICES_OUTPUT" ]; then
		echo -e "${YELLOW}未找到可用设备或 devicectl 不可用${NC}"
		echo -e "${YELLOW}请尝试使用 Xcode 直接安装${NC}"
		return
	fi

	# 解析设备列表
	local DEVICE_COUNT=0
	local DEVICE_IDS=()
	local DEVICE_NAMES=()
	local DEVICE_MODELS=()

	# 使用临时文件存储设备信息
	local TEMP_FILE=$(mktemp)
	echo "$DEVICES_OUTPUT" >"$TEMP_FILE"

	# 查找 iOS 设备（解析格式：设备名 hostname deviceid state model）
	while IFS= read -r line; do
		# 跳过空行和标题行
		if [ -z "$line" ] || echo "$line" | grep -qE "^\s*Device"; then
			continue
		fi

		# 检查是否包含 iPhone 或 iPad
		if echo "$line" | grep -qE "iPhone|iPad"; then
			# 解析行：设备名、hostname、deviceid、state、model
			local DEVICE_NAME=$(echo "$line" | awk '{print $1}')
			local DEVICE_ID=$(echo "$line" | awk '{print $3}')
			local DEVICE_MODEL=$(echo "$line" | awk -F'[,()]' '{for(i=1;i<=NF;i++) if($i ~ /iPhone|iPad/) {print $i; break}}' | xargs)

			# 验证设备 ID 格式
			if echo "$DEVICE_ID" | grep -qE '^[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}$'; then
				DEVICE_COUNT=$((DEVICE_COUNT + 1))
				DEVICE_IDS+=("$DEVICE_ID")
				DEVICE_NAMES+=("$DEVICE_NAME")
				DEVICE_MODELS+=("$DEVICE_MODEL")
				echo -e "${BLUE}[$DEVICE_COUNT]${NC} $DEVICE_NAME"
				echo -e "    ${CYAN}型号: $DEVICE_MODEL${NC}"
				echo -e "    ${CYAN}ID: $DEVICE_ID${NC}"
			fi
		fi
	done <"$TEMP_FILE"

	rm -f "$TEMP_FILE"

	echo ""

	if [ $DEVICE_COUNT -eq 0 ]; then
		echo -e "${YELLOW}未找到可用的 iOS 设备${NC}"
		echo -e "${YELLOW}请确保:${NC}"
		echo "  1. 设备已通过 USB 连接"
		echo "  2. 设备已信任此电脑"
		echo "  3. 设备已解锁"
		return
	fi

	# 选择设备
	if [ $DEVICE_COUNT -eq 1 ]; then
		local SELECTED_DEVICE="${DEVICE_IDS[0]}"
		local SELECTED_NAME="${DEVICE_NAMES[0]}"
		echo -e "${GREEN}自动选择唯一设备: $SELECTED_NAME${NC}"
	else
		echo -e "${YELLOW}请选择要安装的设备 (1-$DEVICE_COUNT):${NC}"
		read -r SELECTION

		if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt "$DEVICE_COUNT" ]; then
			echo -e "${RED}无效的选择${NC}"
			return
		fi

		local SELECTED_DEVICE="${DEVICE_IDS[$((SELECTION - 1))]}"
		local SELECTED_NAME="${DEVICE_NAMES[$((SELECTION - 1))]}"
	fi

	# 安装应用
	echo ""
	echo -e "${GREEN}正在安装到 $SELECTED_NAME...${NC}"
	echo ""

	xcrun devicectl device install app \
		--device "$SELECTED_DEVICE" \
		"$APP_PATH" 2>&1

	if [ $? -eq 0 ]; then
		echo ""
		echo -e "${GREEN}========================================${NC}"
		echo -e "${GREEN}  安装成功！${NC}"
		echo -e "${GREEN}========================================${NC}"
		echo -e "${CYAN}应用已安装到: $SELECTED_NAME${NC}"
		echo -e "${YELLOW}请在设备上打开应用${NC}"
		echo ""
	else
		echo ""
		echo -e "${RED}安装失败${NC}"
		echo -e "${YELLOW}请尝试使用 Xcode 直接安装${NC}"
	fi
}

# 解析参数并执行对应平台的构建
case "$PLATFORM" in
mac)
	MAC_BUILD
	;;
ios)
	IOS_BUILD
	;;
*)
	echo -e "${RED}错误: 无效的平台 '$1'${NC}"
	echo "使用方法: $0 [mac|ios]"
	exit 1
	;;
esac

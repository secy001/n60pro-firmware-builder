#!/usr/bin/env bash
# =============================================================================
# diy.sh —— 磊科 Netcore N60 Pro (MT7986A) 高功率固件定制脚本
# 由 GitHub Actions 工作流在源码根目录调用
# 作用：追加第三方软件源、校验固件配置、准备 files/ 覆盖目录
# =============================================================================
set -euxo pipefail

echo "========== [diy.sh] N60 Pro 高功率定制开始 =========="
cd "$(dirname "$0")"

# ---------------------------------------------------------------------------
# 1) 追加第三方 feeds
#    CUPS 说明：第三方 printing 源(2.4.12)的 cups/Makefile 只 eval 注册了
#    cups 本体，libcups/libcupsimage/cups-filters 等虽有 define 但未注册，
#    导致依赖解析失败、cups 被 defconfig 删除。因此改用官方 packages 源的
#    cups 2.3.3（正确注册全部子包，稳定可用）。
# ---------------------------------------------------------------------------
if ! grep -q 'src-git openclash ' feeds.conf.default; then
    echo 'src-git openclash https://github.com/vernesong/OpenClash.git;master' >> feeds.conf.default
fi
if ! grep -q 'src-git istore ' feeds.conf.default; then
    echo 'src-git istore https://github.com/linkease/istore.git;main' >> feeds.conf.default
fi

echo "----- 最终 feeds.conf.default -----"
cat feeds.conf.default

# ---------------------------------------------------------------------------
# 2) 校验 .config 关键项（.config 由仓库根目录随代码检出）
# ---------------------------------------------------------------------------
[ -f .config ] || { echo "错误：仓库根目录缺少 .config"; exit 1; }

check_cfg() {
    if grep -q "^$1" .config; then
        echo "OK: $1"
    else
        echo "警告：.config 中未找到 $1，make defconfig 后请人工确认"
    fi
}
check_cfg 'CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_netcore_n60-pro=y'
check_cfg 'CONFIG_MTK_FIRST_IF_IPAILNA=y'
check_cfg 'CONFIG_MTK_MT_WIFI_MT7986_20260601=y'
check_cfg 'CONFIG_PACKAGE_kmod-mt_wifi=y'
check_cfg 'CONFIG_PACKAGE_cups=y'
check_cfg 'CONFIG_PACKAGE_luci-app-openclash=y'
check_cfg 'CONFIG_PACKAGE_luci-app-store=y'

# 高功率前端是本次编译的核心，必须确保开启
grep -q '^CONFIG_MTK_FIRST_IF_IPAILNA=y' .config || {
    echo "错误：iPAiLNA 高功率配置缺失，终止编译"; exit 1;
}

# ---------------------------------------------------------------------------
# 3) 准备 files/ 覆盖目录
#    OpenWrt 构建系统会自动把源码根目录 files/ 下的文件打包进固件：
#      files/etc/uci-defaults/99-n60-highpower  -> 首次启动设置发射功率
#      files/etc/cups/cupsd.conf                 -> CUPS 允许局域网访问
# ---------------------------------------------------------------------------
mkdir -p files/etc/uci-defaults files/etc/cups
chmod +x files/etc/uci-defaults/99-n60-highpower 2>/dev/null || true

echo "========== [diy.sh] 定制完成 =========="

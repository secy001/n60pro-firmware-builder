#!/bin/sh
# =============================================================================
# verify-on-device.sh —— 磊科 N60 Pro 固件刷机后验证脚本
#
# 用法：刷机并 SSH 登录后，把本脚本上传到 /tmp 并执行：
#   scp verify-on-device.sh root@192.168.6.1:/tmp/
#   ssh root@192.168.6.1 "sh /tmp/verify-on-device.sh"
#
# 或者逐条复制下面命令到 SSH 终端执行。
# 把完整输出贴给助手，由助手判断高功率与插件是否正常。
# =============================================================================

echo "########## 1. 系统与固件版本 ##########"
cat /etc/openwrt_release 2>/dev/null
echo "内核: $(uname -r)"
echo "机型: $(cat /proc/cpuinfo | grep -m1 'model name' || cat /tmp/sysinfo/model 2>/dev/null)"

echo
echo "########## 2. WiFi 驱动是否加载 ##########"
lsmod 2>/dev/null | grep -iE 'mt_wifi|conninfra|wed|mt7986|mt7976' || echo "(未检测到相关模块)"

echo
echo "########## 3. 无线物理接口 ##########"
iw dev 2>/dev/null || echo "iw 不可用"
iw phy 2>/dev/null | grep -iE 'Band|TX power|MHz|max' | head -30

echo
echo "########## 4. 发射功率设置值（关键） ##########"
echo "--- uci 配置中的 txpower ---"
uci show wireless 2>/dev/null | grep -iE 'txpower|country|band|channel|ssid' || echo "(无配置)"
echo "--- iwinfo 上报功率 ---"
for iface in $(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}'); do
    echo "  [$iface]"
    iwinfo "$iface" txpower 2>/dev/null
    iwinfo "$iface" info 2>/dev/null | grep -iE 'Tx-Power|Power|Country|Channel'
done

echo
echo "########## 5. MTK 闭源驱动功率表（如可用） ##########"
# 不同驱动版本路径不同，能读到哪个算哪个
for f in /proc/mt7986/txpower /proc/mt_wifi/txpower /sys/kernel/debug/mt_wifi/txpower; do
    [ -f "$f" ] && { echo "--- $f ---"; cat "$f"; }
done
command -v iwpriv >/dev/null 2>&1 && iwpriv 2>/dev/null | head -20
command -v mtwifi-cfg >/dev/null 2>&1 && mtwifi-cfg --help 2>/dev/null | head -10

echo
echo "########## 6. 插件安装状态 ##########"
for pkg in cups cups-filters luci-app-openclash luci-app-store dnsmasq-full; do
    if opkg status "$pkg" 2>/dev/null | grep -q '^Status: install ok installed'; then
        echo "  [已安装] $pkg"
    else
        echo "  [未安装] $pkg"
    fi
done

echo
echo "########## 7. 关键服务运行状态 ##########"
echo "--- cupsd ---"
ps 2>/dev/null | grep -i '[c]upsd' || echo "(未运行)"
echo "--- 监听端口 ---"
netstat -tlnp 2>/dev/null | grep -E ':631|:9090' || echo "(无 631/9090 监听)"

echo
echo "########## 8. 高功率初始化脚本是否执行过 ##########"
if [ -f /etc/uci-defaults/99-n60-highpower ]; then
    echo "脚本仍存在（可能未执行）"
else
    echo "脚本已执行并被清除（正常）"
fi

echo
echo "########## 验证完成，请把以上全部输出贴给助手 ##########"

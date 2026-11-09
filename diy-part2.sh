#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate
#!/bin/bash
echo "=== diy-part2: 应用 HC5861 WAN 隔离补丁 ==="

TARGET="target/linux/ramips/files-5.10/drivers/net/ethernet/ralink/mt7530.c"

if [ ! -f "$TARGET" ]; then
    echo "!! 找不到 $TARGET，检查内核版本/路径"
    ls target/linux/ramips/files-5.*/drivers/net/ethernet/ralink/ 2>/dev/null
    exit 1
fi

python3 - "$TARGET" << 'PYEOF'
import sys
f = sys.argv[1]
src = open(f, encoding='utf-8').read()

anchor = "\tmt7530_apply_config(swdev);\n"
if anchor not in src:
    print("!! 找不到锚点 mt7530_apply_config(swdev);")
    sys.exit(1)
if "HC5861 WAN isolate" in src:
    print("== 补丁已存在，跳过 ==")
    sys.exit(0)

inject = '''\t/* HC5861 WAN isolate (FS#612): port5(WAN,RTL8211E) 不被 mediatek,portmap
\t * 覆盖，probe 时默认留在 VLAN1，WAN 的 DHCP 泛洪到 LAN。netifd 接管前
\t * 先把 port5 摘出 VLAN1、单列 VLAN2，与 LAN 硬件隔离。 */
\tif (!bus) {
\t\tint wan = 5;
\t\tpriv->vlan_entries[1].member &= ~(1 << wan);
\t\tpriv->vlan_entries[2].member  = (1 << wan) | (1 << MT7530_CPU_PORT);
\t\tpriv->vlan_entries[2].etags   = (1 << MT7530_CPU_PORT);
\t\tpriv->vlan_entries[2].vid     = 2;
\t\tpriv->port_entries[wan].pvid  = 2;
\t\tmt7530_apply_config(swdev);
\t}
'''

src = src.replace(anchor, anchor + inject, 1)
open(f, 'w', encoding='utf-8').write(src)
print("== HC5861 WAN 隔离补丁已插入 mt7530.c ==")
PYEOF

# 打个标记，方便日志里确认执行过
echo "=== diy-part2 完成 ==="

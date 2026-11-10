#!/bin/bash
echo "=== diy-part2: 应用 HC5861 WAN 隔离补丁 ==="

# 自动探测 mt7530.c 路径：22.03 在 files/，老版本在 files-5.x/
TARGET=$(ls target/linux/ramips/files*/drivers/net/ethernet/ralink/mt7530.c 2>/dev/null | head -n1)

if [ -z "$TARGET" ] || [ ! -f "$TARGET" ]; then
    echo "!! 找不到 mt7530.c，打印 ralink 目录排查："
    ls -R target/linux/ramips/files*/drivers/net/ethernet/ralink/ 2>/dev/null || echo "ralink 目录不存在"
    exit 1
fi
echo ">> 目标文件: $TARGET"

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
print("== HC5861 WAN 隔离补丁已插入:", f, "==")
PYEOF

echo "=== diy-part2 完成 ==="

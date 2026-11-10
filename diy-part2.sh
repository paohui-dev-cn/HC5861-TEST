#!/bin/bash
echo "=== diy-part2: 应用 HC5861 WAN 隔离补丁 ==="

TARGET=$(ls target/linux/ramips/files*/drivers/net/ethernet/ralink/mt7530.c 2>/dev/null | head -n1)
if [ -z "$TARGET" ] || [ ! -f "$TARGET" ]; then
    echo "!! 找不到 mt7530.c"; ls -R target/linux/ramips/files*/drivers/net/ethernet/ralink/ 2>/dev/null; exit 1
fi
echo ">> 目标文件: $TARGET"

python3 - "$TARGET" << 'PYEOF'
import sys
f = sys.argv[1]
src = open(f, encoding='utf-8').read()

anchor = "\tmt7530_apply_config(swdev);\n"
if anchor not in src:
    print("!! 找不到锚点 mt7530_apply_config(swdev);"); sys.exit(1)
if "HC5861 WAN isolate" in src:
    print("== 补丁已存在，跳过 =="); sys.exit(0)
# 字段存在性自检，命名万一不同会明确报出来，不再瞎猜
for tok in ("vlan_entries", "port_entries", "->member", "->etags", "->pvid", "MT7530_CPU_PORT"):
    if tok not in src:
        print("!! 源码里找不到预期字段/宏:", tok, "—— 请把此行发我"); sys.exit(1)

# 注意：ralink 版 probe 里 priv 指针变量名叫 mt7530；bus=NULL 表示 MT7620 内置 gsw
inject = '''\t/* HC5861 WAN isolate (FS#612): port5(WAN) 不被 mediatek,portmap 覆盖，
\t * probe 时默认留在 VLAN1，WAN 的 DHCP 泛洪到 LAN。netifd 接管前把 port5
\t * 摘出 VLAN1、单列 VLAN2，与 LAN 硬件隔离；随后原句 apply_config 原子提交。 */
\tif (!bus) {
\t\tint wan = 5;
\t\tmt7530->vlan_entries[1].member &= ~(1 << wan);
\t\tmt7530->vlan_entries[2].member  = (1 << wan) | (1 << MT7530_CPU_PORT);
\t\tmt7530->vlan_entries[2].etags   = (1 << MT7530_CPU_PORT);
\t\tmt7530->vlan_entries[2].vid     = 2;
\t\tmt7530->port_entries[wan].pvid  = 2;
\t}
'''

src = src.replace(anchor, inject + anchor, 1)
open(f, 'w', encoding='utf-8').write(src)
print("== HC5861 WAN 隔离补丁已插入:", f, "==")
PYEOF

echo "=== diy-part2 完成 ==="

#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# 应用 HC5861 WAN 隔离补丁
cp "$GITHUB_WORKSPACE/patches/999-hc5861-wan-isolate.patch" package/base-files/ 2>/dev/null || true
git apply "$GITHUB_WORKSPACE/patches/999-hc5861-wan-isolate.patch" || {
    echo "patch 应用失败，检查锚点"; exit 1
}
# Uncomment a feed source
#sed -i 's/^#\(.*helloworld\)/\1/' feeds.conf.default

# Add a feed source
echo 'src-git helloworld https://github.com/fw876/helloworld' >>feeds.conf.default
#echo 'src-git passwall https://github.com/xiaorouji/openwrt-passwall' >>feeds.conf.default

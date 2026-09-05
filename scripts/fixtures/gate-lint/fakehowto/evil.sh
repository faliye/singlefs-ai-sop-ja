#!/usr/bin/env bash
# 样本：消息里提到 howto 不等于给了出路。howto 必须在命令位置。
check_one() {
  bad "这里不合格"
  echo "详见 howto 那一节"
}

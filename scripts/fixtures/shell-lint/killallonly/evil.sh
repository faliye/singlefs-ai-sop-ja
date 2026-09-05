#!/usr/bin/env bash
# 样本：只有 killall，且带 sudo 前缀——命令位置要认得出这种。
stop_fio() {
  sudo killall fio
}
stop_fio

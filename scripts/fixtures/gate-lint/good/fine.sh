#!/usr/bin/env bash
bad "有问题的输入"
howto "这么修。"
[[ -f /nonexistent ]] || { bad "缺文件"; howto "补上它。"; exit 1; }
fails=3
bad "本脚本自检失败：$fails 个用例判错"   # gate-lint:summary

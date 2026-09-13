#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${1:-Rocky-Linux}"

# 先确认虚拟机是否存在（libvirtd 未运行时也会判定为不可操作）
if ! virsh dominfo "$VM_NAME" >/dev/null 2>&1; then
  echo "虚拟机 $VM_NAME 不存在，无需 undefine。"
  exit 0
fi

# 仅在虚拟机运行时才发送关机指令，避免 "domain is not running" 报错
if [[ "$(virsh domstate "$VM_NAME" 2>/dev/null || true)" == "running" ]]; then
  virsh shutdown "$VM_NAME"
fi

# 轮询确认虚拟机真正关机（最长等待 120 秒）
state=""
for ((i = 0; i < 120; i++)); do
  state=$(virsh domstate "$VM_NAME" 2>/dev/null || true)
  [[ "$state" == "shut off" ]] && break
  sleep 1
done

if [[ "$state" != "shut off" ]]; then
  echo "错误：虚拟机 $VM_NAME 在 120 秒内未关闭（当前状态：${state:-未知}），已取消 undefine。" >&2
  echo "可执行 'virsh domstate $VM_NAME' 检查；确认无响应后可用 'virsh destroy $VM_NAME' 强制关机再重跑本脚本。" >&2
  exit 1
fi

echo "虚拟机 $VM_NAME 已关闭，执行 undefine ..."
virsh undefine "$VM_NAME" --remove-all-storage

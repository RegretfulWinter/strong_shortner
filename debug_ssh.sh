#!/bin/bash
# 在服务器上运行这个脚本检查 SSH Key 配置

echo "=== 检查 .ssh 目录 ==="
ls -la ~/.ssh/

echo ""
echo "=== 检查 authorized_keys 内容 ==="
cat ~/.ssh/authorized_keys

echo ""
echo "=== 检查 SSH 服务状态 ==="
systemctl status sshd | head -5

echo ""
echo "=== 检查 SSH 配置 ==="
grep -E "^PubkeyAuthentication|^PasswordAuthentication|^PermitRootLogin" /etc/ssh/sshd_config

echo ""
echo "=== 检查日志（最近 5 条）===""
journalctl -u sshd -n 5 --no-pager 2>/dev/null || tail -5 /var/log/auth.log

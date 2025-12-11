#!/bin/bash
# Get detailed system info (run on each TrueNAS)

echo "=== System Information ==="
echo ""

echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
echo ""

echo "=== Memory & CPU ==="
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "CPUs: $(nproc)"
echo ""

echo "=== ZFS Pools ==="
zpool list 2>/dev/null || echo "No ZFS pools"
echo ""

echo "=== Docker Status ==="
docker --version 2>/dev/null || echo "Docker not installed"
if command -v docker &> /dev/null; then
    echo "Running containers:"
    docker ps --format "{{.Names}}\t{{.Status}}" 2>/dev/null || echo "Cannot list containers"
fi
echo ""

echo "=== Samba/SMB Status ==="
systemctl is-active smbd >/dev/null 2>&1 && echo "Samba: RUNNING" || echo "Samba: STOPPED"
if command -v testparm &> /dev/null; then
    echo "SMB Shares:"
    testparm -s 2>/dev/null | grep '^\[' | grep -v global || echo "No SMB shares"
fi
echo ""

echo "=== SSH Status ==="
systemctl is-active ssh >/dev/null 2>&1 && echo "SSH: RUNNING" || echo "SSH: STOPPED"
echo ""

echo "=== Disks ==="
lsblk -d -o NAME,SIZE,TYPE | grep disk
echo ""

echo "=== Services ==="
echo "systemd services:"
systemctl list-units --type=service --state=running --no-pager | grep "running" | wc -l
echo "running (out of total)"
echo ""

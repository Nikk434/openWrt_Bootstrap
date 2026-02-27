#!/bin/ash
set -eu

LOG="/tmp/bootstrap.log"
exec >>"$LOG" 2>&1

INSTALLED=""
ALREADY=""
FAILED=""
KMOD_OK=""
KMOD_SKIP=""

echo "[+] OpenWrt bootstrap started"

echo "[+] Updating package index"
opkg update || {
    echo "[!] opkg update failed. Stopping."
    exit 1
}

install_pkgs() {
    for pkg in "$@"; do
        if opkg status "$pkg" >/dev/null 2>&1; then
            echo "[=] $pkg already installed"
            ALREADY="$ALREADY $pkg"
        else
            echo "[+] Installing $pkg"
            if opkg install "$pkg"; then
                INSTALLED="$INSTALLED $pkg"
            else
                echo "[!] Failed installing $pkg"
                FAILED="$FAILED $pkg"
            fi
        fi
    done
}

echo "[+] Core utilities"
install_pkgs \
coreutils util-linux procps-ng findutils \
grep sed awk diffutils file which watch

echo "[+] Networking"
install_pkgs \
iproute2 bridge-utils net-tools ethtool \
iw iwinfo wireless-tools

echo "[+] Firewall"
install_pkgs \
iptables iptables-mod-extra iptables-mod-nat-extra \
conntrack conntrackd

echo "[+] Packet capture"
install_pkgs tcpdump libpcap

echo "[+] DNS"
install_pkgs dnsmasq

echo "[+] Logging & persistence"
install_pkgs logrotate block-mount

echo "[+] Python environment (opkg only)"
install_pkgs \
python3 python3-light python3-logging \
python3-requests python3-urllib3 \
python3-certifi python3-paho-mqtt \
python3-pip

python3 --version || true
pip3 --version || true

echo "[+] JSON tools"
install_pkgs jq

echo "[+] Lua"
install_pkgs lua lua-cjson

echo "[+] Remote access"
install_pkgs dropbear rsync

echo "[+] TLS"
install_pkgs openssl-util libopenssl

echo "[+] Data push"
install_pkgs curl wget libcurl netcat

echo "[+] Kernel modules (best effort)"
for mod in \
kmod-nf-conntrack kmod-nf-nat kmod-ipt-core \
kmod-ipt-nat kmod-br-netfilter kmod-ifb
do
    if opkg install "$mod"; then
        echo "[+] Installed $mod"
        KMOD_OK="$KMOD_OK $mod"
    else
        echo "[!] Skipped $mod (kernel mismatch or unavailable)"
        KMOD_SKIP="$KMOD_SKIP $mod"
    fi
done

echo "[+] Verifying installed binaries"

verify_bin() {
    if command -v "$1" >/dev/null 2>&1; then
        echo "[OK] $1"
    else
        echo "[FAIL] $1 not found in PATH"
        FAILED="$FAILED $1"
    fi
}

verify_cmd() {
    # Run an actual command and check exit code
    if $1 >/dev/null 2>&1; then
        echo "[OK] $2"
    else
        echo "[FAIL] $2"
        FAILED="$FAILED $2"
    fi
}

# Core utils
verify_bin grep
verify_bin sed
verify_bin awk
verify_bin find
verify_bin which
verify_bin watch
verify_bin diff
verify_bin file

# Networking
verify_bin ip
verify_bin ethtool
verify_bin iw
verify_bin iwinfo
verify_bin brctl

# Firewall
verify_bin iptables
verify_bin conntrack

# Capture
verify_bin tcpdump

# DNS
verify_bin dnsmasq

# Python
verify_cmd "python3 --version" "python3"
verify_cmd "pip3 --version" "pip3"

# Python libs
verify_cmd "python3 -c 'import paho.mqtt.client'" "paho-mqtt"
verify_cmd "python3 -c 'import requests'" "requests"
verify_cmd "python3 -c 'import urllib3'" "urllib3"
verify_cmd "python3 -c 'import certifi'" "certifi"
verify_cmd "python3 -c 'import logging'" "python3-logging"

# JSON
verify_bin jq

# Lua
verify_bin lua
verify_cmd "lua -e 'require(\"cjson\")'" "lua-cjson"

# Remote access
verify_bin dropbear
verify_bin rsync

# TLS
verify_bin openssl

# Data tools
verify_bin curl
verify_bin wget
verify_bin nc

# Kernel modules
echo "[+] Verifying kernel modules"
for mod in nf_conntrack nf_nat br_netfilter ifb; do
    if lsmod | grep -q "^$mod"; then
        echo "[OK] kmod $mod loaded"
    else
        echo "[WARN] kmod $mod not loaded (may be built-in or skipped)"
    fi
done

echo "================ VERIFY REPORT ================"
echo "[FAILED/MISSING]: $FAILED"
echo "================================================"
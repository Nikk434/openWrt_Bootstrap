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

echo "================ INSTALL REPORT ================"
echo "[INSTALLED]$INSTALLED"
echo "[ALREADY]  $ALREADY"
echo "[FAILED]   $FAILED"
echo "[KMOD OK]  $KMOD_OK"
echo "[KMOD SKIP]$KMOD_SKIP"
echo "================================================"

echo "[✓] Bootstrap completed"
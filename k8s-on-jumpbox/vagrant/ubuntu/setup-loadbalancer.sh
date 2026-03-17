#!/bin/bash
set -e

apt-get update -qq
apt-get install -y haproxy

cat > /etc/haproxy/haproxy.cfg <<EOF
global
    log /dev/log local0
    maxconn 2000
    daemon

defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

frontend kubernetes-apiserver
    bind *:6443
    default_backend kubernetes-apiserver

backend kubernetes-apiserver
    balance roundrobin
    option tcp-check
    server controlplane01 192.168.56.11:6443 check
    server controlplane02 192.168.56.12:6443 check
EOF

systemctl enable haproxy
systemctl restart haproxy
systemctl status haproxy --no-pager

#!/bin/bash

set -x

# Grab our libs
. "`dirname $0`/setup-lib.sh"


if [ -f $OURDIR/intermesh-all-done ]; then
    exit 0
fi

logtstart "intermesh-all"

# make sure the local k8s repo is available on all nodes at localhost:5001
# If I was better-versed at k8s dns, would probably just add a cluster-local
# dns name for this
# N.B. localhost traffic does not pass throu PREORUTING chain` https://serverfault.com/questions/211536/iptables-port-redirect-not-working-for-localhost
sudo iptables -t nat -A OUTPUT -m addrtype --src-type LOCAL --dst-type LOCAL -p tcp --dport 5001 -j DNAT --to-destination $SINGLENODE_MGMT_IP:5000
sudo iptables -t nat -A POSTROUTING -m addrtype --src-type LOCAL --dst-type UNICAST -j MASQUERADE

logtend "intermesh-all"
touch $OURDIR/intermesh-all-done


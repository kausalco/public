#!/bin/bash -eu

OFFSET=1
ID=$(( ${NODE_NAME#%(sts_name)s-} + $OFFSET  ))

echo "[+ $ID] Copy configuration file..."
cp /k8s-config/${NODE_NAME}.cfg ${ZOO_CONF_DIR}/zoo.cfg

echo "[+ $ID] Update /data/myid file..."
echo $ID > /data/myid

zkServer.sh start-foreground

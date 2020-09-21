#!/bin/bash

set -eo pipefail

TOKENFILE="${TOKENFILE-/data/ocm-token.json}"
LOOP_HOURS="${LOOP_HOURS-1}"

function log() {
    echo `date` $@
}

function get_cluster_uuid(){
    TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
    CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    API="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT"
    CLUSTER_UUID=$(curl -s -H "Authorization: Bearer $TOKEN" --cacert $CACERT $API/apis/config.openshift.io/v1/clusterversions/version | jq -r '.spec.clusterID')
    log "Cluster UUID is $CLUSTER_UUID"
}

function reconcile() {
    log "Reconciling, sending '$RECONCILE_JSON' to $SUB_ENDPOINT, result:"
    log "$RECONCILE_JSON" | ocm patch "$SUB_ENDPOINT"
}

function check(){
    if [ -f "$TOKENFILE" ]; then
        ocm login --token "$(cat "$TOKENFILE")"
    else
        log "ERROR: $TOKENFILE not found"
        exit 1
    fi

    [[ -z "$CLUSTER_UUID" ]] && get_cluster_uuid

    SUB_ENDPOINT=$(ocm get "/api/clusters_mgmt/v1/clusters?search=external_id%3D%27${CLUSTER_UUID}%27" | jq -r '.items[0].subscription.href')

    if [ "$SUB_ENDPOINT" == "null" ]; then
        log "ERROR: subscription for clsuter $CLUSTER_UUID not found"
        exit 1
    fi

    log "Subscription API endpoint: $SUB_ENDPOINT"

    ocm get "$SUB_ENDPOINT" > "/tmp/${CLUSTER_UUID}.subscription.json"

    SUPPORT_LEVEL_F=$(jq -r '.support_level' "/tmp/${CLUSTER_UUID}.subscription.json")
    USAGE_F=$(jq -r '.usage' "/tmp/${CLUSTER_UUID}.subscription.json")

    RECONCILE="no"
    RECONCILE_JSON="{"

    if [ "$SUPPORT_LEVEL" ]; then
        log "Found $SUPPORT_LEVEL_F support level, wanted: $SUPPORT_LEVEL"
        if [ "$SUPPORT_LEVEL" != "$SUPPORT_LEVEL_F" ]; then
            RECONCILE="yes"
            RECONCILE_JSON="$RECONCILE_JSON \"support_level\":\"$SUPPORT_LEVEL\","
        fi
    fi

    if [ "$USAGE" ]; then
        log "Found $USAGE_F usage, wanted: $USAGE"
        if [ "$USAGE" != "$USAGE_F" ]; then
            RECONCILE="yes"
            RECONCILE_JSON="$RECONCILE_JSON \"usage\":\"$USAGE\","
        fi
    fi

    RECONCILE_JSON="${RECONCILE_JSON::-1} }"

    if [ "$RECONCILE" == "yes" ]; then
        reconcile
    fi
}

while true; do
    log "Checking cluster entitelment status"
    check
    sleep $(($LOOP_HOURS*3600))
done

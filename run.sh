#!/bin/bash

set -eo pipefail

TOKENFILE="${TOKENFILE-/data/ocm-token.json}"
MAX_FAIL="${MAX_FAIL-3}"
LOOP_HOURS="${LOOP_HOURS-1}"
FAIL=0

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
    if [ $FAIL -gt $MAX_FAIL ]; then
        log "ERROR: Reconciliation failed"
        exit 1
    fi
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
    SERVICE_LEVEL_F=$(jq -r '.service_level' "/tmp/${CLUSTER_UUID}.subscription.json")
    STATUS_F=$(jq -r '.status' "/tmp/${CLUSTER_UUID}.subscription.json")
    USAGE_F=$(jq -r '.usage' "/tmp/${CLUSTER_UUID}.subscription.json")
    CPU_TOTAL_F=$(jq -r '.cpu_total' "/tmp/${CLUSTER_UUID}.subscription.json")
    SOCKET_TOTAL_F=$(jq -r '.socket_total' "/tmp/${CLUSTER_UUID}.subscription.json")

    RECONCILE="no"
    RECONCILE_JSON="{"

    if [ "$SUPPORT_LEVEL" ]; then
        log "Found $SUPPORT_LEVEL_F support level, wanted: $SUPPORT_LEVEL"
        if [ "$SUPPORT_LEVEL" != "$SUPPORT_LEVEL_F" ]; then
            RECONCILE="yes"
            RECONCILE_JSON="$RECONCILE_JSON \"support_level\":\"$SUPPORT_LEVEL\","
        fi
    fi

    if [ "$SERVICE_LEVEL" ]; then
        log "Found $SERVICE_LEVEL_F service level, wanted: $SERVICE_LEVEL"
        if [ "$SERVICE_LEVEL" != "$SERVICE_LEVEL_F" ]; then
            RECONCILE="yes"
            RECONCILE_JSON="$RECONCILE_JSON \"service_level\":\"$SERVICE_LEVEL\","
        fi
    fi

    if [ "$STATUS" ]; then
        log "Found $STATUS_F status, wanted: $STATUS"
        if [ "$STATUS" != "$STATUS_F" ]; then
            RECONCILE="yes"
            RECONCILE_JSON="$RECONCILE_JSON \"status\":\"$STATUS\","
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
        FAIL=$((FAIL+1))
        reconcile
    else
        FAIL=0
    fi
}

while true; do
    log "Checking cluster entitelment status"
    check
    sleep $(($LOOP_HOURS*3600))
done

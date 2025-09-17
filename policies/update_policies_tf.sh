#!/bin/bash
REPO_ROOT=$(git rev-parse --show-toplevel)
POLICIES_DIR=$REPO_ROOT/deployment-scripts/azure/offer-service/environment/demo/cce-policies
az confcom acipolicygen -y -i kv-policy.json --print-policy | grep -v '^$' > \
    $POLICIES_DIR/kv.base64
az confcom acipolicygen -y -i ofe-policy.json --print-policy | grep -v '^$' > \
    $POLICIES_DIR/ofe.base64
az confcom acipolicygen -y -i offer-policy.json --print-policy | grep -v '^$' > \
    $POLICIES_DIR/offer.base64

cat $POLICIES_DIR/kv.base64 | base64 -d | sha256sum | cut -d' ' -f1
cat $POLICIES_DIR/ofe.base64 | base64 -d | sha256sum | cut -d' ' -f1
cat $POLICIES_DIR/offer.base64 | base64 -d | sha256sum | cut -d' ' -f1
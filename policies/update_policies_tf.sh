#!/bin/bash
REPO_ROOT=$(git rev-parse --show-toplevel)
az confcom acipolicygen -y -i kv-policy.json --print-policy | grep -v '^$' > \
    $REPO_ROOT/deployment-scripts/azure/offer-service/environment/demo/cce-policies/kv.base64
az confcom acipolicygen -y -i ofe-policy.json --print-policy | grep -v '^$' > \
    $REPO_ROOT/deployment-scripts/azure/offer-service/environment/demo/cce-policies/ofe.base64
az confcom acipolicygen -y -i offer-policy.json --print-policy | grep -v '^$' > \
    $REPO_ROOT/deployment-scripts/azure/offer-service/environment/demo/cce-policies/offer.base64

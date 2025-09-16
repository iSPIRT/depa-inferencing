#!/bin/bash
REPO_ROOT=$(git rev-parse --show-toplevel)
az confcom acipolicygen -y -a kv.json --print-policy | grep -v '^$' > \
    $REPO_ROOT/deployment-scripts/azure/offer-service/environment/demo/cce-policies/kv.base64
az confcom acipolicygen -y -a ofe.json --print-policy | grep -v '^$' > \
    $REPO_ROOT/deployment-scripts/azure/offer-service/environment/demo/cce-policies/ofe.base64
az confcom acipolicygen -y -a offer.json --print-policy | grep -v '^$' > \
    $REPO_ROOT/deployment-scripts/azure/offer-service/environment/demo/cce-policies/offer.base64

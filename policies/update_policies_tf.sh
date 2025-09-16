#!/bin/bash
REPO_ROOT=$(git rev-parse --show-toplevel)
az confcom acipolicygen -y -a kv.json --print-policy | sed -z 's/\n*$//' > \
    $REPO_ROOT/deployment-scripts/azure/offer-service/environment/demo/cce-policies/kv.base64
az confcom acipolicygen -y -a policies/ofe.json --print-policy | sed -z 's/\n*$//' > \
    $REPO_ROOT/deployment-scripts/azure/offer-service/environment/demo/cce-policies/ofe.base64
az confcom acipolicygen -y -a policies/offer.json --print-policy | sed -z 's/\n*$//' > \
    $REPO_ROOT/deployment-scripts/azure/offer-service/environment/demo/cce-policies/offer.base64

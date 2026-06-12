# Contributing feature changes (Azure)

Use this flow to add new features or make changes to the Confidential Clean Room (CCR) services (Offer, Frontend and Key-Value services).

**Skip step 1** if your change does not touch [data-plane shared libraries](https://github.com/iSPIRT/ad-selection-api.data-plane-shared-libraries). In that case, leave `WORKSPACE` unchanged in the BA and KV repos.

## Overview

| Step | Repo | What you do |
|------|------|-------------|
| 1 | [data-plane-shared-libraries](https://github.com/iSPIRT/ad-selection-api.data-plane-shared-libraries) | Implement, commit, push |
| 2 | [bidding-and-auction-servers](https://github.com/iSPIRT/ad-selection-api.bidding-and-auction-servers) | Point `WORKSPACE` data-plane library at step 1, implement any changes to the BA services, build & push Offer/Frontend images |
| 3 | [protected-auction-key-value-service](https://github.com/iSPIRT/protected-auction-key-value-service) | Same `WORKSPACE` data-plane library, implement any changes to the KV service, build & push KV image |
| 4 | **This repo** | Bump image tags, refresh CCE policies, open PR |
| 5 | — | CI + manual validation; then PR the upstream repos |

## 1. Data plane

Implement the feature on a branch (or fork) of the data-plane library, then push.

## 2. Offer / Frontend images

In **bidding-and-auction-servers**, point `WORKSPACE` at your data-plane branch or fork. Then, implement any changes to the source code, and build and push the images.

```bash
./production/packaging/build_and_test_all_in_docker \
  --service-path bidding_service \
  --service-path buyer_frontend_service \
  --no-precommit --no-tests \
  --build-flavor prod --platform azure --instance azure

az login && az acr login -n <your_acr_name>
BUILD_FLAVOR=prod RELEASE_VERSION=<tag> ./production/packaging/azure/push_images_to_acr.sh
```

Use a **new, unique** `RELEASE_VERSION` for each release (e.g. `4.8.1.2`).

## 3. KV image

In **protected-auction-key-value-service**, use the **same** data-plane `WORKSPACE` reference. Then, implement any changes to the source code, and build and push the image.

```bash
./production/packaging/build_and_test_all_in_docker \
  --no-precommit --mode prod \
  --platform azure_microsoft --instance azure_microsoft

az login && az acr login -n <your_acr_name>
BUILD_FLAVOR=prod RELEASE_VERSION=<tag> ./production/packaging/azure/push_image_to_acr.sh
```

Again, use a **new, unique** tag (e.g. `1.2.1.2`).

## 4. This repo

Update the **same image tags** in all of:

- [`deployment-scripts/azure/offer-service/environment/demo/terraform/offer.tf`](./deployment-scripts/azure/offer-service/environment/demo/terraform/offer.tf)
- [`deployment-scripts/azure/offer-service/services/app/helm/offer.yaml`](./deployment-scripts/azure/offer-service/services/app/helm/offer.yaml)
- [`policies/kv-policy.json`](./policies/kv-policy.json)
- [`policies/ofe-policy.json`](./policies/ofe-policy.json)
- [`policies/offer-policy.json`](./policies/offer-policy.json)

Regenerate CCE policy artifacts for Terraform (uses pinned `confcom` version in `policies/confcom.version`, same as CI):

```bash
cd policies && ./update_policies_tf.sh
cd policies && ./update_policies_tf.sh nonprod   # UAT/nonprod policies
```

Open a PR here. CI must pass (failures usually mean a bad tag, policy drift, or a build bug).

## 5. Validate and upstream

1. **Manually test** the feature in your target environment, even after CI passes.
2. If it works, open PRs in the data-plane, BA, and KV repos with the feature.
3. Revert temporary `WORKSPACE` overrides in BA/KV back to the official branch or fork path.

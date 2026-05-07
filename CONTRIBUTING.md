# Contributing feature changes (Azure)

This note describes how to integrate and test feature work that flows through the data plane, BA/KV images, and this repo’s deployable offer stack.

**Note:** If your change does **not** touch the data-plane shared libraries, skip step 1 and leave `WORKSPACE` unchanged in the BA and KV repos.

**Scenario:** A new feature (for example, HTTP headers) is implemented in the data-plane shared libraries.

## 1. Data plane

**Repo:** [iSPIRT/ad-selection-api.data-plane-shared-libraries](https://github.com/iSPIRT/ad-selection-api.data-plane-shared-libraries)

- Implement the change, commit, and push a feature branch or fork.

## 2. Rebuild BA images

**Repo:** [iSPIRT/ad-selection-api.bidding-and-auction-servers](https://github.com/iSPIRT/ad-selection-api.bidding-and-auction-servers)

- Point `WORKSPACE` at your data-plane branch or fork path.
- Build:

```bash
./production/packaging/build_and_test_all_in_docker \
  --service-path bidding_service \
  --service-path buyer_frontend_service \
  --no-precommit \
  --no-tests \
  --build-flavor prod \
  --platform azure \
  --instance azure
```

- Log in and push images to ACR with **unique release tags**:

```bash
az login
az acr login -n <your_acr_name>
BUILD_FLAVOR=prod RELEASE_VERSION=4.8.1.2 ./production/packaging/azure/push_images_to_acr.sh
```

(Replace `RELEASE_VERSION` and `your_acr_name` with your tag and ACR name.)

## 3. Rebuild KV image

**Repo:** [iSPIRT/protected-auction-key-value-service](https://github.com/iSPIRT/protected-auction-key-value-service)

- Point `WORKSPACE` at the same data-plane branch or fork path.
- Build:

```bash
./production/packaging/build_and_test_all_in_docker \
  --no-precommit \
  --mode prod \
  --platform azure_microsoft \
  --instance azure_microsoft
```

- Log in and push to ACR:

```bash
az login
az acr login -n <your_acr_name>
BUILD_FLAVOR=prod RELEASE_VERSION=1.2.1.1 ./production/packaging/azure/push_image_to_acr.sh
```

(Replace `RELEASE_VERSION` and `your_acr_name` with your tag and ACR name.)

## 4. This repo: image tags and CCE policies

**Repo:** [iSPIRT/depa-inferencing](https://github.com/iSPIRT/depa-inferencing)

Update image tag versions consistently in:

1. `deployment-scripts/azure/offer-service/environment/demo/terraform/offer.tf`
2. `deployment-scripts/azure/offer-service/services/app/helm/offer.yaml`
3. `policies/kv-policy.json`
4. `policies/ofe-policy.json`
5. `policies/offer-policy.json`

Regenerate Terraform-loaded CCE policy artifacts:

```bash
cd policies
./update_policies_tf.sh
```

## 5. PR and validation

- Open a PR on this repo; CI runs automatically and must pass (failures usually mean a bug, wrong tag, or policy drift).
- After green CI, still **manually test** that the feature behaves as intended in your target environment.
- If the feature works as intended, raise PRs for the Data Plane, BA, and KV repos to include the new feature. Revert their WORKSPACE back to the original branch or fork path.
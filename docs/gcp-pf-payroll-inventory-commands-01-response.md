REQUEST

```bash
export PROJECT_ID="coreassistant-474022"
export REGION="us-central1"
export SERVICE="pf-payroll"
export OLD_SERVICE_ACCOUNT="pf-payroll@${PROJECT_ID}.iam.gserviceaccount.com"
export OUT="pf-payroll-inventory-$(date +%Y%m%d-%H%M%S)"

gcloud config set project "$PROJECT_ID"

mkdir -p "$OUT"/{artifact-registry,cloud-run,secrets,iam,logging}
echo "Directorio del inventario: $OUT"
```

RESPONSE

```bash
Updated property [core/project].
Directorio del inventario: pf-payroll-inventory-20261007-011002
```

---

REQUEST

```bash
gcloud auth list
gcloud config get-value project
gcloud projects describe "$PROJECT_ID" \
  --format="yaml(projectId,projectNumber,displayName,lifecycleState)"
```

RESPONSE

```bash
Credentialed Accounts

ACTIVE: *
ACCOUNT: arturo.amb89@gmail.com

To set the active account, run:
    $ gcloud config set account `ACCOUNT`

Your active configuration is: [cloudshell-23073]
coreassistant-474022
lifecycleState: ACTIVE
projectId: coreassistant-474022
projectNumber: '646185261155'
```

---

REQUEST

```bash
gcloud run services describe "$SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="yaml(
    metadata.name,
    metadata.labels,
    metadata.annotations,
    spec.template.metadata,
    spec.template.spec.serviceAccountName,
    spec.template.spec.containers,
    spec.traffic,
    status
  )" \
  > "$OUT/cloud-run/${SERVICE}-describe.yaml"
```

---

REQUEST

```bash
gcloud run services describe "$SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="json" |
jq '{
  service: .metadata.name,
  url: .status.url,
  latestReadyRevision: .status.latestReadyRevisionName,
  traffic: .status.traffic,
  serviceAccount: .spec.template.spec.serviceAccountName,
  env: [
    .spec.template.spec.containers[]?.env[]?
    | {
        name: .name,
        value: (.value // null),
        secret: (.valueFrom.secretKeyRef.name // null),
        secretVersion: (.valueFrom.secretKeyRef.key // null)
      }
  ],
  annotations: .spec.template.metadata.annotations
}' \
> "$OUT/cloud-run/${SERVICE}-runtime-summary.json"
```

---

REQUEST

```bash
gcloud run revisions list \
  --service="$SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="table(
    metadata.name,
    status.conditions[0].status,
    status.conditions[0].reason,
    metadata.creationTimestamp,
    spec.containerConcurrency
  )" \
  > "$OUT/cloud-run/${SERVICE}-revisions.txt"

gcloud run services describe "$SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="yaml(status.traffic,status.latestReadyRevisionName,status.latestCreatedRevisionName)" \
  > "$OUT/cloud-run/${SERVICE}-traffic.yaml"
```

---

REQUEST

```bash
gcloud run services get-iam-policy "$SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="yaml" \
  > "$OUT/iam/${SERVICE}-invoker-policy.yaml"
```

---

REQUEST

```bash
gcloud artifacts repositories list \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --format="table(
    name,
    format,
    mode,
    description,
    createTime,
    updateTime
  )" \
  > "$OUT/artifact-registry/repositories.txt"
```

RESPONSE

```bash
Listing items under project coreassistant-474022, location us-central1.
```

---

REQUEST

```bash
gcloud artifacts repositories list \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --format="value(name)" |
while read -r REPO; do
  SAFE_NAME="$(echo "$REPO" | tr '/' '_')"

  gcloud artifacts repositories describe "$REPO" \
    --project="$PROJECT_ID" \
    --location="$REGION" \
    --format="yaml" \
    > "$OUT/artifact-registry/${SAFE_NAME}-describe.yaml"

  gcloud artifacts repositories get-iam-policy "$REPO" \
    --project="$PROJECT_ID" \
    --location="$REGION" \
    --format="yaml" \
    > "$OUT/iam/artifact-registry-${SAFE_NAME}-iam.yaml"
done
```

RESPONSE

```bash
Listing items under project coreassistant-474022, location us-central1.

Encryption: Google-managed key
Repository Size: 450.429MB
Encryption: Google-managed key
Repository Size: 168.043MB
Encryption: Google-managed key
Repository Size: 3611.462MB
Encryption: Google-managed key
Repository Size: 2073.327MB
```

---

REQUEST

```bash
export AR_REPO="pf-payroll"

gcloud artifacts repositories describe "$AR_REPO" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --format="yaml" \
  > "$OUT/artifact-registry/${AR_REPO}-describe.yaml"

gcloud artifacts repositories get-iam-policy "$AR_REPO" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --format="yaml" \
  > "$OUT/iam/artifact-registry-${AR_REPO}-iam.yaml"
```

RESPONSE

```bash
Encryption: Google-managed key
Repository Size: 3611.462MB
```

---

```bash
export AR_HOST="${REGION}-docker.pkg.dev"

gcloud artifacts docker images list \
  "${AR_HOST}/${PROJECT_ID}/${AR_REPO}" \
  --include-tags \
  --format="table(
    package,
    version,
    createTime,
    updateTime,
    tags
  )" \
  > "$OUT/artifact-registry/${AR_REPO}-images-tags.txt"
```

RESPONSE

```bash
Listing items under project coreassistant-474022, location us-central1, repository pf-payroll.
```

---

REQUEST

```bash
gcloud artifacts packages list \
  --repository="$AR_REPO" \
  --location="$REGION" \
  --project="$PROJECT_ID" \
  --format="table(name,createTime,updateTime)" \
  > "$OUT/artifact-registry/${AR_REPO}-packages.txt"

gcloud artifacts packages list \
  --repository="$AR_REPO" \
  --location="$REGION" \
  --project="$PROJECT_ID" \
  --format="value(name)" |
while read -r PACKAGE; do
  gcloud artifacts versions list "$PACKAGE" \
    --repository="$AR_REPO" \
    --location="$REGION" \
    --project="$PROJECT_ID" \
    --format="table(
      version,
      createTime,
      updateTime,
      metadata
    )"
done \
> "$OUT/artifact-registry/${AR_REPO}-package-versions.txt"
```

RESPONSE

```bash
Listing items under project coreassistant-474022, location us-central1, repository pf-payroll.

Listing items under project coreassistant-474022, location us-central1, repository pf-payroll.

ERROR: (gcloud.artifacts.versions.list) unrecognized arguments: pf-payroll

To search the help text of gcloud commands, run:
  gcloud help -- SEARCH_TERMS
```

---

REQUEST

```bash
gcloud secrets list \
  --project="$PROJECT_ID" \
  --format="table(
    name,
    createTime,
    labels
  )" \
  > "$OUT/secrets/secrets-list.txt"
```

---

REQUEST

```bash
gcloud secrets list \
  --project="$PROJECT_ID" \
  --format="value(name)" |
while read -r SECRET; do
  SAFE_NAME="$(echo "$SECRET" | tr '/' '_')"

  gcloud secrets describe "$SECRET" \
    --project="$PROJECT_ID" \
    --format="yaml(name,createTime,labels,replication)" \
    > "$OUT/secrets/${SAFE_NAME}-describe.yaml"

  gcloud secrets get-iam-policy "$SECRET" \
    --project="$PROJECT_ID" \
    --format="yaml" \
    > "$OUT/iam/secret-${SAFE_NAME}-iam.yaml"
done
```

---

REQUEST

```bash
for SECRET in \
  PF_DATABASE_URL \
  PF_PAYROLL_API_KEY \
  PF_INCOME_API_KEY \
  PF_RATES_API_KEY
do
  echo "===== $SECRET ====="

  if gcloud secrets describe "$SECRET" \
      --project="$PROJECT_ID" \
      --format="yaml(name,createTime,labels,replication)" \
      > "$OUT/secrets/${SECRET}-describe.yaml" 2>"$OUT/secrets/${SECRET}.error"
  then
    gcloud secrets get-iam-policy "$SECRET" \
      --project="$PROJECT_ID" \
      --format="yaml" \
      > "$OUT/iam/secret-${SECRET}-iam.yaml"
  else
    echo "$SECRET not found or inaccessible"
  fi
done
```

RESPONSE

```bash
===== PF_DATABASE_URL =====
===== PF_PAYROLL_API_KEY =====
===== PF_INCOME_API_KEY =====
PF_INCOME_API_KEY not found or inaccessible
===== PF_RATES_API_KEY =====
```

---

REQUEST

```bash
for SECRET in \
  PF_DATABASE_URL \
  PF_PAYROLL_API_KEY \
  PF_INCOME_API_KEY \
  PF_RATES_API_KEY
do
  gcloud secrets versions list "$SECRET" \
    --project="$PROJECT_ID" \
    --format="table(
      name,
      state,
      createTime,
      destroyTime
    )" \
    > "$OUT/secrets/${SECRET}-versions.txt" 2>&1 || true
done
```

---

REQUEST

```bash
gcloud secrets versions access latest
```

RESPONSE

```bash
ERROR: (gcloud.secrets.versions.access) Error parsing [version].
The [version] resource is not properly specified.
Failed to find attribute [secret]. The attribute can be set in the following ways:
- provide the argument `VERSION` on the command line with a fully specified name
- provide the argument `--secret` on the command line
```

---

REQUEST

```bash
gcloud iam service-accounts describe "$OLD_SERVICE_ACCOUNT" \
  --project="$PROJECT_ID" \
  --format="yaml(
    email,
    displayName,
    description,
    disabled,
    oauth2ClientId,
    uniqueId
  )" \
  > "$OUT/iam/${SERVICE}-service-account.yaml"
```

---

REQUEST

```bash
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${OLD_SERVICE_ACCOUNT}" \
  --format="table(
    bindings.role,
    bindings.members
  )" \
  > "$OUT/iam/${SERVICE}-project-roles.txt"
```

---

REQUEST

```bash
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${OLD_SERVICE_ACCOUNT}" \
  --format="yaml" \
  > "$OUT/iam/${SERVICE}-project-policy.yaml"
```

---

REQUEST

```bash
export GITHUB_DEPLOYER="github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts describe "$GITHUB_DEPLOYER" \
  --project="$PROJECT_ID" \
  --format="yaml(
    email,
    displayName,
    disabled,
    uniqueId
  )" \
  > "$OUT/iam/github-deployer.yaml"

gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${GITHUB_DEPLOYER}" \
  --format="table(
    bindings.role,
    bindings.members
  )" \
  > "$OUT/iam/github-deployer-project-roles.txt"
```

---

REQUEST

```bash
export NEW_SERVICE_ACCOUNT="pf-svc-income@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts describe "$NEW_SERVICE_ACCOUNT" \
  --project="$PROJECT_ID" \
  --format="yaml" \
  > "$OUT/iam/pf-svc-income-service-account.yaml" 2>&1 || true

gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${NEW_SERVICE_ACCOUNT}" \
  --format="yaml" \
  > "$OUT/iam/pf-svc-income-project-policy.yaml" 2>&1 || true
```

---

REQUEST

```bash
gcloud logging read \
  'resource.type="cloud_run_revision"
   AND resource.labels.service_name="pf-payroll"
   AND httpRequest.requestUrl:*' \
  --project="$PROJECT_ID" \
  --freshness=30d \
  --limit=1000 \
  --format="json" \
  > "$OUT/logging/${SERVICE}-requests-30d.json"
```

---

REQUEST

```bash
jq -r '
  .[]
  | [
      .httpRequest.userAgent // "-",
      .httpRequest.requestMethod // "-",
      .httpRequest.requestUrl // "-",
      (.httpRequest.status // 0 | tostring)
    ]
  | @tsv
' "$OUT/logging/${SERVICE}-requests-30d.json" |
sort |
uniq -c |
sort -nr \
> "$OUT/logging/${SERVICE}-consumer-summary.tsv"
```

---

REQUEST

```bash
jq -r '
  .[]
  | [
      .httpRequest.requestMethod // "-",
      .httpRequest.requestUrl // "-",
      (.httpRequest.status // 0 | tostring)
    ]
  | @tsv
' "$OUT/logging/${SERVICE}-requests-30d.json" |
sort |
uniq -c |
sort -nr \
> "$OUT/logging/${SERVICE}-endpoint-summary.tsv"
```

---

REQUEST

```bash
jq -r '
  .[]
  | .httpRequest.userAgent // "-"
' "$OUT/logging/${SERVICE}-requests-30d.json" |
sort |
uniq -c |
sort -nr \
> "$OUT/logging/${SERVICE}-user-agents.txt"
```

---

REQUEST

```bash
jq -r '
  .[]
  | .httpRequest.remoteIp // "-"
' "$OUT/logging/${SERVICE}-requests-30d.json" |
sort |
uniq -c |
sort -nr \
> "$OUT/logging/${SERVICE}-source-ips.txt"
```

---

REQUEST

```bash
grep -RInE \
  'pf-payroll|pf-svc-income|pf-payroll-[^ ]+run\\.app|PF_PAYROLL_API_KEY|PF_INCOME_API_KEY' \
  "$OUT/logging" \
  > "$OUT/logging/known-identity-references.txt" || true
```

RESPONSE

```bash
grep: pf-payroll-inventory-20261007-011002/logging/known-identity-references.txt: input file is also the output
```

---

REQUEST

```bash
gcloud run services describe pf-rates \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="yaml(
    metadata.name,
    status.url,
    status.traffic,
    status.latestReadyRevisionName,
    spec.template.spec.serviceAccountName,
    spec.template.spec.containers
  )" \
  > "$OUT/cloud-run/pf-rates-describe.yaml"
```

---

REQUEST

```bash
gcloud run services list \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="table(
    metadata.name,
    status.url,
    status.latestReadyRevisionName,
    spec.template.spec.serviceAccountName
  )" \
  > "$OUT/cloud-run/services-us-central1.txt"
```

---

REQUEST

```bash
find "$OUT" -type f -maxdepth 3 -print
grep -RInE 'SECRET|TOKEN|PASSWORD|PRIVATE KEY|BEGIN ' "$OUT" || true
```

RESPONSE

```bash
find: warning: you have specified the global option -maxdepth after the argument -type, but global options are not positional, i.e., -maxdepth affects tests specified before it as well as those specified after it.  Please specify global options before other arguments.
pf-payroll-inventory-20261007-011002/artifact-registry/gcp-scheduler-runner-describe.yaml
pf-payroll-inventory-20261007-011002/artifact-registry/pf-payroll-packages.txt
pf-payroll-inventory-20261007-011002/artifact-registry/repositories.txt
pf-payroll-inventory-20261007-011002/artifact-registry/pf-payroll-describe.yaml
pf-payroll-inventory-20261007-011002/artifact-registry/pf-payroll-images-tags.txt
pf-payroll-inventory-20261007-011002/artifact-registry/gcp-todoist-runner-describe.yaml
pf-payroll-inventory-20261007-011002/artifact-registry/pf-payroll-package-versions.txt
pf-payroll-inventory-20261007-011002/artifact-registry/pf-rates-describe.yaml
pf-payroll-inventory-20261007-011002/cloud-run/pf-payroll-describe.yaml
pf-payroll-inventory-20261007-011002/cloud-run/pf-payroll-traffic.yaml
pf-payroll-inventory-20261007-011002/cloud-run/services-us-central1.txt
pf-payroll-inventory-20261007-011002/cloud-run/pf-payroll-runtime-summary.json
pf-payroll-inventory-20261007-011002/cloud-run/pf-payroll-revisions.txt
pf-payroll-inventory-20261007-011002/cloud-run/pf-rates-describe.yaml
pf-payroll-inventory-20261007-011002/secrets/PF_RATES_API_KEY-versions.txt
pf-payroll-inventory-20261007-011002/secrets/PF_RATES_API_KEY.error
pf-payroll-inventory-20261007-011002/secrets/secrets-list.txt
pf-payroll-inventory-20261007-011002/secrets/PF_PAYROLL_API_KEY-describe.yaml
pf-payroll-inventory-20261007-011002/secrets/PF_RATES_API_KEY-describe.yaml
pf-payroll-inventory-20261007-011002/secrets/PF_INCOME_API_KEY-versions.txt
pf-payroll-inventory-20261007-011002/secrets/PF_DATABASE_URL-versions.txt
pf-payroll-inventory-20261007-011002/secrets/PF_PAYROLL_API_KEY-versions.txt
pf-payroll-inventory-20261007-011002/secrets/PF_DATABASE_URL.error
pf-payroll-inventory-20261007-011002/secrets/PF_DATABASE_URL-describe.yaml
pf-payroll-inventory-20261007-011002/secrets/PF_RATES_GDRIVE_EXPORT_FOLDER_ID-describe.yaml
pf-payroll-inventory-20261007-011002/secrets/PF_INCOME_API_KEY-describe.yaml
pf-payroll-inventory-20261007-011002/secrets/PF_INCOME_API_KEY.error
pf-payroll-inventory-20261007-011002/secrets/PF_PAYROLL_API_KEY.error
pf-payroll-inventory-20261007-011002/iam/pf-svc-income-project-policy.yaml
pf-payroll-inventory-20261007-011002/iam/artifact-registry-gcp-scheduler-runner-iam.yaml
pf-payroll-inventory-20261007-011002/iam/pf-payroll-service-account.yaml
pf-payroll-inventory-20261007-011002/iam/artifact-registry-gcp-todoist-runner-iam.yaml
pf-payroll-inventory-20261007-011002/iam/secret-PF_DATABASE_URL-iam.yaml
pf-payroll-inventory-20261007-011002/iam/pf-svc-income-service-account.yaml
pf-payroll-inventory-20261007-011002/iam/secret-PF_RATES_GDRIVE_EXPORT_FOLDER_ID-iam.yaml
pf-payroll-inventory-20261007-011002/iam/artifact-registry-pf-payroll-iam.yaml
pf-payroll-inventory-20261007-011002/iam/pf-payroll-project-policy.yaml
pf-payroll-inventory-20261007-011002/iam/pf-payroll-invoker-policy.yaml
pf-payroll-inventory-20261007-011002/iam/artifact-registry-pf-rates-iam.yaml
pf-payroll-inventory-20261007-011002/iam/github-deployer.yaml
pf-payroll-inventory-20261007-011002/iam/pf-payroll-project-roles.txt
pf-payroll-inventory-20261007-011002/iam/secret-PF_RATES_API_KEY-iam.yaml
pf-payroll-inventory-20261007-011002/iam/secret-PF_PAYROLL_API_KEY-iam.yaml
pf-payroll-inventory-20261007-011002/iam/github-deployer-project-roles.txt
pf-payroll-inventory-20261007-011002/logging/pf-payroll-consumer-summary.tsv
pf-payroll-inventory-20261007-011002/logging/pf-payroll-endpoint-summary.tsv
pf-payroll-inventory-20261007-011002/logging/pf-payroll-user-agents.txt
pf-payroll-inventory-20261007-011002/logging/pf-payroll-source-ips.txt
pf-payroll-inventory-20261007-011002/logging/pf-payroll-requests-30d.json
pf-payroll-inventory-20261007-011002/logging/known-identity-references.txt
```

---

REQUEST

```bash
tar -czf "${OUT}.tar.gz" "$OUT"
ls -lh "${OUT}.tar.gz"
```

RESPONSE

```bash
arturo_amb89@cloudshell:~ (coreassistant-474022)$ tar -czf "${OUT}.tar.gz" "$OUT"
ls -lh "${OUT}.tar.gz"
-rw-rw-r-- 1 arturo_amb89 arturo_amb89 44K Oct  7 01:31 pf-payroll-inventory-20261007-011002.tar.gz
```
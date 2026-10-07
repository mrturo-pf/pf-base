REQUEST:

```bash
export PROJECT_ID="coreassistant-474022"
export REGION="us-central1"
export SERVICE="pf-payroll"
export AR_REPO="pf-payroll"
export OLD_SERVICE_ACCOUNT="pf-payroll@${PROJECT_ID}.iam.gserviceaccount.com"
export NEW_SERVICE_ACCOUNT="pf-svc-income@${PROJECT_ID}.iam.gserviceaccount.com"
export OUT2="pf-payroll-inventory-2-$(date +%Y%m%d-%H%M%S)"

gcloud config set project "$PROJECT_ID"
mkdir -p "$OUT2"/{artifact-registry,cloud-run,secrets,iam,logging,sql,scheduler,monitoring,networking}
echo "Directorio del inventario adicional: $OUT2"
```

RESPONSE:
```

```

---

REQUEST:

```bash
gcloud auth list
gcloud config get-value project
gcloud projects describe "$PROJECT_ID" \
  --format="yaml(projectId,projectNumber,displayName,lifecycleState)"
```

RESPONSE:
```

```

---

REQUEST:

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
    spec.template.spec.containerConcurrency,
    spec.template.spec.timeoutSeconds,
    spec.template.spec.containers,
    spec.template.spec.scaling,
    spec.template.spec.volumes,
    spec.template.spec.vpcAccess,
    spec.traffic,
    status
  )" \
  > "$OUT2/cloud-run/${SERVICE}-operational-config.yaml"
```

RESPONSE:
```

```

---

REQUEST:

```bash
gcloud run services describe "$SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="json" |
jq '{
  service: .metadata.name,
  url: .status.url,
  latestReadyRevision: .status.latestReadyRevisionName,
  latestCreatedRevision: .status.latestCreatedRevisionName,
  traffic: .status.traffic,
  serviceAccount: .spec.template.spec.serviceAccountName,
  containerConcurrency: .spec.template.spec.containerConcurrency,
  timeoutSeconds: .spec.template.spec.timeoutSeconds,
  scaling: .spec.template.spec.scaling,
  vpcAccess: .spec.template.spec.vpcAccess,
  containers: [
    .spec.template.spec.containers[] |
    {
      name,
      image,
      ports,
      resources,
      startupProbe,
      livenessProbe,
      env: [
        .env[]? |
        {
          name,
          hasLiteralValue: (.value != null),
          secret: (.valueFrom.secretKeyRef.name // null),
          secretVersion: (.valueFrom.secretKeyRef.key // null)
        }
      ]
    }
  ]
}' \
> "$OUT2/cloud-run/${SERVICE}-operational-summary.json"
```

RESPONSE:
```

```

---

REQUEST:

```bash
gcloud run services get-iam-policy "$SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="yaml" \
  > "$OUT2/iam/${SERVICE}-invoker-policy.yaml"

gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${OLD_SERVICE_ACCOUNT}" \
  --format="yaml" \
  > "$OUT2/iam/${SERVICE}-service-account-project-policy.yaml"
```

RESPONSE:
```

```

---

REQUEST:

```bash
gcloud run revisions list \
  --service="$SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --limit=20 \
  --format="value(metadata.name)" |
while read -r REVISION; do
  gcloud run revisions describe "$REVISION" \
    --service="$SERVICE" \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --format="yaml(
      metadata.name,
      metadata.creationTimestamp,
      spec.serviceAccountName,
      spec.containerConcurrency,
      spec.timeoutSeconds,
      spec.containers,
      spec.scaling,
      spec.vpcAccess,
      status
    )" \
    > "$OUT2/cloud-run/${REVISION}-describe.yaml"
done
```

RESPONSE:
```

```

---

REQUEST:

```bash
gcloud artifacts packages list \
  --repository="$AR_REPO" \
  --location="$REGION" \
  --project="$PROJECT_ID" \
  --format="table(name,createTime,updateTime)" \
  > "$OUT2/artifact-registry/${AR_REPO}-packages.txt"

gcloud artifacts packages list \
  --repository="$AR_REPO" \
  --location="$REGION" \
  --project="$PROJECT_ID" \
  --format="value(name)" \
  > "$OUT2/artifact-registry/${AR_REPO}-package-names.txt"
```

RESPONSE:
```

```

---

REQUEST:

```bash
while read -r PACKAGE; do
  SAFE_PACKAGE="$(echo "$PACKAGE" | tr '/' '_')"

  gcloud artifacts versions list \
    --package="$PACKAGE" \
    --repository="$AR_REPO" \
    --location="$REGION" \
    --project="$PROJECT_ID" \
    --format="table(
      name,
      version,
      createTime,
      updateTime,
      metadata
    )" \
    > "$OUT2/artifact-registry/${SAFE_PACKAGE}-versions.txt"

done < "$OUT2/artifact-registry/${AR_REPO}-package-names.txt"
```

RESPONSE:
```

```

---

REQUEST:

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
  > "$OUT2/artifact-registry/${AR_REPO}-images-tags.txt"
```

RESPONSE:
```

```

---

REQUEST:

```bash
export NEW_AR_REPO="pf-svc-income"

gcloud artifacts repositories describe "$NEW_AR_REPO" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --format="yaml" \
  > "$OUT2/artifact-registry/${NEW_AR_REPO}-describe.yaml" 2>&1 || true

gcloud artifacts repositories get-iam-policy "$NEW_AR_REPO" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --format="yaml" \
  > "$OUT2/iam/artifact-registry-${NEW_AR_REPO}-iam.yaml" 2>&1 || true
```

RESPONSE:
```

```

---

REQUEST:

```bash
for SECRET in \
  PF_DATABASE_URL \
  PF_PAYROLL_API_KEY \
  PF_INCOME_API_KEY \
  PF_RATES_API_KEY
do
  gcloud secrets describe "$SECRET" \
    --project="$PROJECT_ID" \
    --format="yaml(name,createTime,labels,replication,expireTime,ttl)" \
    > "$OUT2/secrets/${SECRET}-describe.yaml" 2>&1 || true

  gcloud secrets versions list "$SECRET" \
    --project="$PROJECT_ID" \
    --format="table(name,state,createTime,destroyTime)" \
    > "$OUT2/secrets/${SECRET}-versions.txt" 2>&1 || true

done
```

RESPONSE:
```

```

---

REQUEST:

```bash
for SECRET in \
  PF_DATABASE_URL \
  PF_PAYROLL_API_KEY \
  PF_INCOME_API_KEY \
  PF_RATES_API_KEY
do
  gcloud secrets get-iam-policy "$SECRET" \
    --project="$PROJECT_ID" \
    --format="yaml" \
    > "$OUT2/iam/secret-${SECRET}-iam.yaml" 2>&1 || true
done
```

RESPONSE:
```

```

---

REQUEST:

```bash
for ACCOUNT in "$OLD_SERVICE_ACCOUNT" "$NEW_SERVICE_ACCOUNT"; do
  SAFE_ACCOUNT="$(echo "$ACCOUNT" | tr '@.' '__')"

  gcloud iam service-accounts describe "$ACCOUNT" \
    --project="$PROJECT_ID" \
    --format="yaml(email,displayName,description,disabled,uniqueId)" \
    > "$OUT2/iam/${SAFE_ACCOUNT}-describe.yaml" 2>&1 || true

  gcloud projects get-iam-policy "$PROJECT_ID" \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:${ACCOUNT}" \
    --format="yaml" \
    > "$OUT2/iam/${SAFE_ACCOUNT}-project-policy.yaml" 2>&1 || true
done
```

RESPONSE:
```

```

---

REQUEST:

```bash
gcloud logging read \
  'resource.type="cloud_run_revision"
   AND resource.labels.service_name="pf-payroll"
   AND httpRequest.requestUrl:*' \
  --project="$PROJECT_ID" \
  --freshness=30d \
  --limit=1000 \
  --format="json" \
  > "$OUT2/logging/${SERVICE}-requests-30d.json"
```

RESPONSE:
```

```

---

REQUEST:

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
' "$OUT2/logging/${SERVICE}-requests-30d.json" |
sort | uniq -c | sort -nr \
> "$OUT2/logging/${SERVICE}-consumer-summary.tsv"

jq -r '
  .[]
  | [
      .httpRequest.requestMethod // "-",
      .httpRequest.requestUrl // "-",
      (.httpRequest.status // 0 | tostring)
    ]
  | @tsv
' "$OUT2/logging/${SERVICE}-requests-30d.json" |
sort | uniq -c | sort -nr \
> "$OUT2/logging/${SERVICE}-endpoint-summary.tsv"

grep -RInE \
  'pf-payroll|pf-svc-income|pf-payroll-[^ ]+run\\.app|PF_PAYROLL_API_KEY|PF_INCOME_API_KEY' \
  "$OUT2/logging" \
  > "$OUT2/logging/known-identity-references.txt" || true
```

RESPONSE:
```

```

---

REQUEST:

```bash
gcloud scheduler jobs list \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --format="yaml" \
  > "$OUT2/scheduler/jobs.yaml"

gcloud run jobs list \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="yaml" \
  > "$OUT2/scheduler/cloud-run-jobs.yaml"

gcloud functions list \
  --project="$PROJECT_ID" \
  --regions="$REGION" \
  --format="yaml" \
  > "$OUT2/scheduler/functions.yaml"

gcloud eventarc triggers list \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --format="yaml" \
  > "$OUT2/scheduler/eventarc-triggers.yaml"

gcloud pubsub topics list \
  --project="$PROJECT_ID" \
  --format="yaml" \
  > "$OUT2/scheduler/pubsub-topics.yaml"
```

RESPONSE:
```

```

---

REQUEST:

```bash
gcloud scheduler jobs list \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --format="value(name)" |
while read -r JOB; do
  SAFE_JOB="$(echo "$JOB" | tr '/' '_')"
  gcloud scheduler jobs describe "$JOB" \
    --project="$PROJECT_ID" \
    --location="$REGION" \
    --format="yaml(name,description,schedule,timeZone,httpTarget,appEngineHttpTarget,attemptDeadline,retryConfig)" \
    > "$OUT2/scheduler/${SAFE_JOB}-describe.yaml"
done
```

RESPONSE:
```

```

---

REQUEST:

```bash
gcloud sql instances list \
  --project="$PROJECT_ID" \
  --format="table(
    name,
    databaseVersion,
    region,
    state,
    settings.tier,
    settings.ipConfiguration.ipv4Enabled
  )" \
  > "$OUT2/sql/instances.txt"

gcloud compute networks vpc-access connectors list \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="table(name,network,ipCidrRange,state,minThroughput,maxThroughput)" \
  > "$OUT2/networking/vpc-connectors.txt"
```

RESPONSE:
```

```

---

REQUEST:

```bash
gcloud compute forwarding-rules list \
  --project="$PROJECT_ID" \
  --format="yaml" \
  > "$OUT2/networking/forwarding-rules.yaml"

gcloud api-gateway gateways list \
  --project="$PROJECT_ID" \
  --format="yaml" \
  > "$OUT2/networking/api-gateways.yaml"

gcloud dns managed-zones list \
  --project="$PROJECT_ID" \
  --format="yaml" \
  > "$OUT2/networking/dns-managed-zones.yaml"

gcloud certificate-manager certificates list \
  --project="$PROJECT_ID" \
  --location="global" \
  --format="yaml" \
  > "$OUT2/networking/certificates.yaml" 2>&1 || true
```

RESPONSE:
```

```

---

REQUEST:

```bash
gcloud monitoring policies list \
  --project="$PROJECT_ID" \
  --format="yaml" \
  > "$OUT2/monitoring/alert-policies.yaml"

gcloud monitoring uptime-checks list \
  --project="$PROJECT_ID" \
  --format="yaml" \
  > "$OUT2/monitoring/uptime-checks.yaml"

gcloud logging metrics list \
  --project="$PROJECT_ID" \
  --format="yaml" \
  > "$OUT2/monitoring/log-based-metrics.yaml"

gcloud monitoring dashboards list \
  --project="$PROJECT_ID" \
  --format="yaml" \
  > "$OUT2/monitoring/dashboards.yaml"
```

RESPONSE:
```

```

---

REQUEST:

```bash
grep -RInE \
  'pf-payroll|pf-svc-income|PF_PAYROLL_API_KEY|PF_INCOME_API_KEY' \
  "$OUT2" \
  > "$OUT2/known-identity-references.txt" || true
```

RESPONSE:
```

```

---

REQUEST:

```bash
find "$OUT2" -maxdepth 4 -type f -print

grep -RInE \
  'SECRET|TOKEN|PASSWORD|PRIVATE KEY|BEGIN |authorization:|Bearer |api[_-]?key' \
  "$OUT2" || true
```

RESPONSE:
```

```

---

REQUEST:

```bash
tar -czf "${OUT2}.tar.gz" "$OUT2"
ls -lh "${OUT2}.tar.gz"
```

RESPONSE:
```

```
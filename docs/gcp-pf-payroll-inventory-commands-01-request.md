# Comandos de inventario GCP para renombrar `pf-payroll`

Estos comandos están pensados para ejecutarse en **Google Cloud Shell** desde la consola de GCP. Son de solo lectura sobre GCP; únicamente crean archivos locales en Cloud Shell y pueden cambiar el proyecto activo de `gcloud`.

No leen los valores de los secretos. Solo extraen nombres, metadatos y permisos.

## 0. Preparación

Reemplaza `PROJECT_ID` si corresponde:

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

Verifica la identidad y el proyecto:

```bash
gcloud auth list
gcloud config get-value project
gcloud projects describe "$PROJECT_ID" \
  --format="yaml(projectId,projectNumber,displayName,lifecycleState)"
```

## 1. Servicio actual de Cloud Run

### Descripción completa del servicio sin valores de secretos

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

Para inspeccionar únicamente las referencias a secretos y los nombres de variables de entorno:

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

El JSON anterior no debería imprimir valores de secretos cuando las variables usan `valueFrom.secretKeyRef`, pero revisa el archivo antes de compartirlo.

### Revisiones y tráfico

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

### IAM de Cloud Run

```bash
gcloud run services get-iam-policy "$SERVICE" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="yaml" \
  > "$OUT/iam/${SERVICE}-invoker-policy.yaml"
```

## 2. Artifact Registry

### Repositorios de la región

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

Obtén el detalle de cada repositorio:

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

### Repositorio asociado a `pf-payroll`

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

### Imágenes y tags

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

Para imágenes anidadas:

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

No ejecutes comandos de eliminación. Esta investigación solo requiere inventario.

## 3. Secret Manager

### Nombres y metadatos de secretos

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

Obtén el detalle de cada secreto sin sus valores:

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

### Secretos relevantes

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

### Versiones de secretos sin leer sus valores

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

No ejecutes:

```bash
gcloud secrets versions access latest
```

## 4. Cuentas de servicio e IAM

### Cuenta de servicio actual

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

### Roles a nivel de proyecto

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

Subconjunto completo de la política:

```bash
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${OLD_SERVICE_ACCOUNT}" \
  --format="yaml" \
  > "$OUT/iam/${SERVICE}-project-policy.yaml"
```

### Deployer de GitHub

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

### Cuenta de servicio objetivo, si ya fue creada

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

## 5. Consumidores mediante Cloud Logging

Primero intenta obtener un resumen de las solicitudes:

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

Este archivo puede contener URLs, parámetros de consulta o información potencialmente sensible. No lo subas a Git ni lo compartas sin revisarlo.

### Resumen por user agent

Si `jq` está disponible:

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

### Resumen por URL y estado HTTP

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

### User agents

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

### IPs de origen

Extrae esto solo si el equipo considera aceptable compartirlo:

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

Las IPs pueden ser datos sensibles o personales. Revísalas y redáctalas antes de compartirlas.

### Buscar consumidores conocidos

```bash
grep -RInE \
  'pf-payroll|pf-svc-income|pf-payroll-[^ ]+run\\.app|PF_PAYROLL_API_KEY|PF_INCOME_API_KEY' \
  "$OUT/logging" \
  > "$OUT/logging/known-identity-references.txt" || true
```

## 6. Servicios y URLs relacionadas de Cloud Run

### Descripción completa de `pf-rates`

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

### Todos los servicios regionales

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

## 7. Empaquetar el inventario

Inspecciona los archivos antes de comprimir:

```bash
find "$OUT" -type f -maxdepth 3 -print
grep -RInE 'SECRET|TOKEN|PASSWORD|PRIVATE KEY|BEGIN ' "$OUT" || true
```

Si no aparecen valores sensibles:

```bash
tar -czf "${OUT}.tar.gz" "$OUT"
ls -lh "${OUT}.tar.gz"
```

No subas automáticamente el archivo comprimido a Git. Compártelo solo mediante un canal autorizado y revisado.

## Resultado esperado

El administrador debería proporcionar, como mínimo:

1. Repositorio actual de Artifact Registry para `pf-payroll`.
2. Imágenes y tags disponibles.
3. Si `pf-svc-income` ya existe en Artifact Registry.
4. Nombres de secretos:
   - `PF_DATABASE_URL`;
   - `PF_PAYROLL_API_KEY`;
   - `PF_INCOME_API_KEY`;
   - `PF_RATES_API_KEY`.
5. IAM de la cuenta de servicio antigua.
6. IAM de la cuenta de servicio nueva, si ya fue creada.
7. IAM de Artifact Registry.
8. Consumidores detectados en los logs.
9. URL actual de Cloud Run.
10. Confirmación de la ventana de mantenimiento necesaria para migrar `PAY_*` a `INC_*`.

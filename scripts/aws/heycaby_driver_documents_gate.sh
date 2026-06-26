#!/usr/bin/env bash
# Toggle E2E go-online test mode on the live ECS Go API (eu-north-1).
# Skips document + billing gates (server and app via /api/v1/config).
#
#   enable  — drivers can go online without documents or payment
#   disable — production gates restored
#
# Prerequisites: AWS CLI logged in; running container image must include recent Go API code.
#
# Usage:
#   ./scripts/aws/heycaby_driver_documents_gate.sh enable
#   ./scripts/aws/heycaby_driver_documents_gate.sh disable
set -euo pipefail

MODE="${1:-}"
if [[ "$MODE" != "enable" && "$MODE" != "disable" ]]; then
  echo "Usage: $0 enable|disable" >&2
  exit 1
fi

REGION="${AWS_REGION:-eu-north-1}"
SERVICE_NAME="${ECS_SERVICE:-heycaby-backend-service}"

if [[ "$MODE" == "enable" ]]; then
  SKIP_GATES="true"
  REQUIRE_DOCS="false"
  echo "== Enabling E2E go-online test mode (no documents, no billing block) =="
else
  SKIP_GATES="false"
  REQUIRE_DOCS="true"
  echo "== Disabling E2E test mode (documents + billing enforced) =="
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy 2>/dev/null || true

CLUSTER="${ECS_CLUSTER:-}"
DISCOVERED_SERVICE=""
if [[ -z "$CLUSTER" ]]; then
  echo "Discovering ECS cluster + service (prefer name: $SERVICE_NAME)..."
  while read -r arn; do
    [[ -z "$arn" ]] && continue
    cname="${arn##*/}"
    while read -r sname; do
      [[ -z "$sname" ]] && continue
      if [[ "$sname" == "$SERVICE_NAME" ]] || [[ "$sname" == *heycaby-backend* ]]; then
        CLUSTER="$cname"
        DISCOVERED_SERVICE="$sname"
        break 2
      fi
    done < <(aws ecs list-services --cluster "$cname" --region "$REGION" \
      --query 'serviceArns[]' --output text 2>/dev/null | tr '\t' '\n' | sed 's|.*/||')
  done < <(aws ecs list-clusters --region "$REGION" --query 'clusterArns[]' --output text | tr '\t' '\n')
fi

if [[ -z "$CLUSTER" ]]; then
  echo "Could not find an ECS service matching heycaby-backend. Set ECS_CLUSTER and ECS_SERVICE." >&2
  exit 1
fi

if [[ -n "$DISCOVERED_SERVICE" ]]; then
  SERVICE_NAME="$DISCOVERED_SERVICE"
fi

echo "Cluster: $CLUSTER"
echo "Service: $SERVICE_NAME"

TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster "$CLUSTER" \
  --services "$SERVICE_NAME" \
  --region "$REGION" \
  --query 'services[0].taskDefinition' \
  --output text)

if [[ -z "$TASK_DEF_ARN" || "$TASK_DEF_ARN" == "None" ]]; then
  echo "Service not found or has no task definition." >&2
  exit 1
fi

echo "Current task definition: $TASK_DEF_ARN"

TMP_JSON=$(mktemp)
trap 'rm -f "$TMP_JSON" "${TMP_JSON}.register"' EXIT

aws ecs describe-task-definition \
  --task-definition "$TASK_DEF_ARN" \
  --region "$REGION" \
  --query 'taskDefinition' >"$TMP_JSON"

jq --arg skip "$SKIP_GATES" --arg docs "$REQUIRE_DOCS" '
  .containerDefinitions[0].environment = (
    (.containerDefinitions[0].environment // [])
    | map(select(
        .name != "DRIVER_SKIP_GO_ONLINE_GATES"
        and .name != "DRIVER_REQUIRE_DOCUMENTS_FOR_ONLINE"
      ))
    + [
      {name: "DRIVER_SKIP_GO_ONLINE_GATES", value: $skip},
      {name: "DRIVER_REQUIRE_DOCUMENTS_FOR_ONLINE", value: $docs}
    ]
  )
  | del(
      .taskDefinitionArn,
      .revision,
      .status,
      .requiresAttributes,
      .compatibilities,
      .registeredAt,
      .registeredBy
    )
' "$TMP_JSON" >"${TMP_JSON}.register"

NEW_ARN=$(aws ecs register-task-definition \
  --region "$REGION" \
  --cli-input-json "file://${TMP_JSON}.register" \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)

echo "Registered: $NEW_ARN"

aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE_NAME" \
  --task-definition "$NEW_ARN" \
  --force-new-deployment \
  --region "$REGION" \
  --query 'service.{serviceName:serviceName,status:status,taskDefinition:taskDefinition}' \
  --output table

echo ""
echo "Deployment started. After ~1–3 min, logs should show: WARN: E2E go-online test mode"
echo "Rebuild & push the Go API Docker image if this code was not deployed yet."
echo "Driver app: pull to refresh config, or reinstall IPA with latest Flutter."

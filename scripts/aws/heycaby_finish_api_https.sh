#!/usr/bin/env bash
# Attach HTTPS:443 to the HeyCaby Go ALB once ACM certificate for api.heycaby.nl is ISSUED.
# Prerequisites (manual DNS at your registrar):
#   1) ACM DNS validation CNAME (see backend/aws/PUBLIC_GO_API.md)
#   2) api.heycaby.nl CNAME → heycaby-backend-alb-1638574793.eu-north-1.elb.amazonaws.com
#
# Usage: ./scripts/aws/heycaby_finish_api_https.sh
set -euo pipefail

REGION="eu-north-1"
CERT_ARN="arn:aws:acm:eu-north-1:852922980007:certificate/8fba7bbe-eba9-4180-9671-32104eef3dbc"
ALB_ARN="arn:aws:elasticloadbalancing:eu-north-1:852922980007:loadbalancer/app/heycaby-backend-alb/cfca556a0851cb14"
TG_ARN="arn:aws:elasticloadbalancing:eu-north-1:852922980007:targetgroup/heycaby-backend-tg/fef60031f372903e"

echo "== ACM certificate status =="
aws acm describe-certificate --certificate-arn "$CERT_ARN" --region "$REGION" \
  --query 'Certificate.{Status:Status,DomainName:DomainName,Validation:DomainValidationOptions[0].ResourceRecord}' \
  --output table

HTTPS_COUNT=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$REGION" \
  --query 'length(Listeners[?Port==`443`])' --output text)
if [[ "${HTTPS_COUNT:-0}" != "0" ]]; then
  echo "HTTPS listener on :443 already exists."
  exit 0
fi

STATUS=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --region "$REGION" \
  --query 'Certificate.Status' --output text)
if [[ "$STATUS" != "ISSUED" ]]; then
  echo "Certificate status is '$STATUS', not ISSUED yet."
  echo "Add the ACM validation CNAME and api.heycaby.nl → ALB CNAME at your DNS host, wait, then re-run."
  exit 1
fi

echo "Creating HTTPS :443 listener (forward to ECS target group)..."
aws elbv2 create-listener \
  --load-balancer-arn "$ALB_ARN" \
  --region "$REGION" \
  --protocol HTTPS \
  --port 443 \
  --certificates "CertificateArn=$CERT_ARN" \
  --default-actions "Type=forward,TargetGroupArn=$TG_ARN"

echo "Done. Verify: curl -sI https://api.heycaby.nl/health"
echo "Then: UPDATE public.app_config SET value = 'https://api.heycaby.nl' WHERE key = 'driver_rest_api_base_url';"

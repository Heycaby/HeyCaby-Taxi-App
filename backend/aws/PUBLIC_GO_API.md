# HeyCaby Go API — public hostname (AWS)

Production Go runs behind **Application Load Balancer** in **eu-north-1** (account `852922980007`).

## Current ALB (HTTP)

| Item | Value |
|------|--------|
| ALB DNS | `heycaby-backend-alb-1638574793.eu-north-1.elb.amazonaws.com` |
| HTTP | Port **80** → target group `heycaby-backend-tg` (ECS tasks on **8080**) |
| Health | `GET http://<alb-dns>/health` → **200** |

`curl` from the internet must **not** use `https://` against the raw ALB DNS until an **HTTPS listener** exists (port **443** currently has no listener).

## Why `https://api.heycaby.nl` failed (Vercel)

That hostname was pointed at **Vercel**, not this ALB, so driver calls hit **`DEPLOYMENT_NOT_FOUND`**.

## Fix: HTTPS on ALB + `api.heycaby.nl` → ALB

### 1) ACM certificate (already requested in eu-north-1)

Certificate ARN:

`arn:aws:acm:eu-north-1:852922980007:certificate/8fba7bbe-eba9-4180-9671-32104eef3dbc`

**DNS validation** — add this **CNAME** at the DNS host for `heycaby.nl` (wherever `api` / `www` are managed):

| Name | Type | Value |
|------|------|--------|
| `_cc3f12c28c9e0559bf48f4ff4d152073.api.heycaby.nl` | CNAME | `_f9227c6db0f9479244606d69b86503f4.jkddzztszm.acm-validations.aws.` |

Run `aws acm describe-certificate --certificate-arn <arn> --region eu-north-1` if AWS rotates validation names.

#### If ACM stays `PENDING_VALIDATION` forever (CAA)

Check root CAA:

```bash
dig +short heycaby.nl CAA
```

If you see `issue` only for `letsencrypt.org`, `sectigo.com`, `pki.goog`, etc., **Amazon ACM cannot issue** until you allow Amazon. Add a **CAA** record at the zone apex (`heycaby.nl`):

| Type | Name | Value |
|------|------|--------|
| **CAA** | `@` (or `heycaby.nl`) | `0 issue "amazon.com"` |

You can keep existing CAA rows (multiple `issue` records are allowed). After DNS propagates, ACM usually moves to **ISSUED** within minutes.

### 2) Point `api.heycaby.nl` at the ALB

Remove any **Vercel** / other project binding for **`api.heycaby.nl`**, then create:

| Name | Type | Value |
|------|------|--------|
| `api.heycaby.nl` | CNAME | `heycaby-backend-alb-1638574793.eu-north-1.elb.amazonaws.com` |

(If your DNS supports **ALIAS** to an ALB, prefer that over CNAME for apex-like setups; for `api` subdomain CNAME is normal.)

### 3) Attach HTTPS listener (after ACM is **ISSUED**)

```bash
./scripts/aws/heycaby_finish_api_https.sh
```

Or manually:

```bash
aws elbv2 create-listener \
  --region eu-north-1 \
  --load-balancer-arn "arn:aws:elasticloadbalancing:eu-north-1:852922980007:loadbalancer/app/heycaby-backend-alb/cfca556a0851cb14" \
  --protocol HTTPS --port 443 \
  --certificates CertificateArn=arn:aws:acm:eu-north-1:852922980007:certificate/8fba7bbe-eba9-4180-9671-32104eef3dbc \
  --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:eu-north-1:852922980007:targetgroup/heycaby-backend-tg/fef60031f372903e
```

### 4) Supabase `app_config`

When `curl -sI https://api.heycaby.nl/health` returns **200** and **not** `server: Vercel`:

```sql
UPDATE public.app_config
SET value = 'https://api.heycaby.nl'
WHERE key = 'driver_rest_api_base_url';
```

Flutter resolves this via RPC `get_driver_rest_api_base_url` (no new IPA required if the app already includes that RPC).

## E2E test mode — skip all go-online gates (documents + billing)

Set **`DRIVER_SKIP_GO_ONLINE_GATES=true`** (or legacy **`DRIVER_REQUIRE_DOCUMENTS_FOR_ONLINE=false`**) on the Go API. This bypasses:

- Document / licence readiness checks
- Platform fee / payment before `available`
- Client payment dialog (`skip_go_online_gates` in `GET /api/v1/config`)

**Deploy new Go code first**, then flip env:

```bash
# From backend/ — build & push image, then update ECS service (your usual deploy)
make deploy   # or docker build + ECR push + ecs update-service

aws login
./scripts/aws/heycaby_driver_documents_gate.sh enable   # test mode
./scripts/aws/heycaby_driver_documents_gate.sh disable  # production
```

ECS logs should show: `WARN: E2E go-online test mode`. Reinstall or restart the driver app so `/api/v1/config` is refreshed.

### 5) Optional — redirect HTTP → HTTPS

Add a listener rule on port 80 to redirect to `https://api.heycaby.nl:443` or change the default action of the port-80 listener to `redirect` (careful not to break health checks; ALB health checks hit the target directly).

## ARNs (copy-paste)

- ALB: `arn:aws:elasticloadbalancing:eu-north-1:852922980007:loadbalancer/app/heycaby-backend-alb/cfca556a0851cb14`
- Target group: `arn:aws:elasticloadbalancing:eu-north-1:852922980007:targetgroup/heycaby-backend-tg/fef60031f372903e`

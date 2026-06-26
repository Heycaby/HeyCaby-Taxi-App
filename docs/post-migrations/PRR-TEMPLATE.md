# Production Readiness Review — Template

**Migration / RC:** `M__ RC__`  
**Date:** YYYY-MM-DD  
**Status:** ☐ Draft · ☐ Approved · ☐ Superseded

| Prerequisite | Link |
|--------------|------|
| Design doc | |
| Repo migrations | |
| Smoke script | |
| Rollback script | |

---

## 1. Risk — What could break?

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| | | | |

---

## 2. Blast radius — Who is affected?

| Subsystem | Affected? | Notes |
|-----------|-----------|-------|
| Riders | | |
| Drivers | | |
| Dispatch | | |
| Billing | | |
| Admin / support | | |

---

## 3. Detection — How will we know?

| Signal | Source | Alert threshold |
|--------|--------|-----------------|
| | | |

---

## 4. Rollback — How quickly can we recover?

| Method | Steps | Est. time |
|--------|-------|-----------|
| Config flag | | |
| SQL rollback | | |

---

## 5. Success — Measurable definition

> Every production deployment must have a measurable definition of success before it begins.

| Criterion | Target | Measurement |
|-----------|--------|-------------|
| | | |

---

## 6. Dependencies — What must already exist?

| Dependency | Required? | Version / migration |
|------------|-----------|---------------------|
| | ☐ | |

Prevents deploying migrations out of order.

---

## RC promotion checklist

| Stage | Requirement | Status |
|-------|-------------|--------|
| RC1 | Repo + design approved | ☐ |
| RC2 | Smoke pass on HEYCABY-TAXI | ☐ |
| Production | PRR approved + explicit deploy approval | ☐ |
| GA | Observation window + success metrics | ☐ |
| LTS | ~30 days post-GA stable | ☐ |
| Freeze | Closure doc published | ☐ |

---

## TRB sign-off

| Role | Approve production deploy? | Signature / date |
|------|---------------------------|------------------|
| Engineering | ☐ | |
| CTO / TRB | ☐ | |

# GRAŻYNA 5.0 — REPAIR AUDIT 1.0

Date: 2026-09-18
Base: main @ d96c31f0cc3a9a02128b1d5b9f3148953a7de17a
Repair branch: audit/repair-2026-09-18

## Scope

Read-only forensic inspection followed by targeted repairs on a dedicated branch.
No changes were made to main.

## Confirmed structural findings

- Repository tree contains 16,909 tracked files.
- 15,802 files are under `grazyna-system`.
- The repository contains a mixture of source, portable runtime, generated artifacts, cache and historical/backup material.
- Backend source, Prisma schema, frontend and monitoring components are present.

## Critical defects found

1. Backend package manifest did not match the actual imports used by source files.
2. Backend Dockerfile built from the incomplete package configuration and exposed port 3000 while application code defaults to 3001.
3. Express server did not mount the actual API router; it exposed placeholder endpoints instead.
4. Prisma schema and controllers disagreed:
   - User uses `passwordHash`, not `password`.
   - User uses `lastLoginAt`, not `lastLogin`.
   - Vehicle requires `licensePlate`.
   - Vehicle coordinates are `lat/lng`.
   - Mission uses `createdById`.
   - Event uses `message`, not `title`.
5. Authentication used a fallback JWT secret.
6. Development seed contained hardcoded credentials and fields inconsistent with the schema.
7. Worker pool referenced a `.js` worker while the repository also uses ESM package semantics; production build did not copy the worker artifact.
8. Docker Compose contained hardcoded database/admin passwords and a fallback JWT secret.
9. CI built the frontend but did not perform a real backend build or Prisma validation.
10. Production frontend API configuration could point at a container hostname from the user's browser.

## Repairs applied on this branch

- Rebuilt backend package manifest around actual imports.
- Made database and JWT configuration explicit rather than silently falling back.
- Repaired Prisma-backed authentication.
- Repaired vehicle controller against current Prisma schema.
- Repaired development seed to require credentials from environment variables.
- Mounted the real Express API router.
- Repaired worker runtime path and build copy step.
- Removed hardcoded Compose credentials and unsafe secret fallbacks.
- Added backend Prisma/build validation to CI.
- Added same-origin production API configuration for the frontend.
- Corrected backend container port to 3001.

## Remaining blockers

These require a real execution environment before being marked PASS:

- npm dependency installation/build
- Prisma generation/validation against a real environment
- backend startup with PostgreSQL and JWT secret
- frontend production build
- end-to-end login
- authenticated vehicle CRUD
- worker-pool runtime test
- Docker Compose startup
- secret-history purge/rotation
- complete dependency/license audit

## Security rule

Any credential found in Git history must be treated as potentially compromised. Rotate/revoke first; history rewriting is a separate destructive operation and should only be performed after preserving a clean recovery copy.

## Sale-readiness

This branch is a technical repair branch, not yet a buyer-transfer branch.
Main remains untouched.

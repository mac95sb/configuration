# PAIR Dev Database Reference

## Schema quirks

- **Quoted case-sensitive column names**: Most PK columns are `"ID"` (uppercase), not `id`.
  Always double-quote them in raw SQL: `u."ID"`, `la."ID"` etc. `id` alone will fail with
  `column does not exist`.
- **Table names**: `user_teams` (not `user_team`), `organization_members`, `user_roles`,
  `license_assignments`, `licenses`, `products`, `roles`.
- **Enum casing**: `licensepurchasetype` values are `'Manual'` and `'Stripe'` (title-case),
  not `'manual'`.

## Duplicate email accounts

The dev database can have multiple `users` rows sharing the same email address (e.g. rows with
IDs 1, 47, and 48 all having `mac.long@pairnow.ai`). Any script or query that filters by email
alone (e.g. `WHERE email = '...'`) will hit the first match, not the intended user.

**Always pin to the specific user ID when seeding dev data:**

```sql
SELECT "ID", email FROM users WHERE email = 'mac.long@pairnow.ai';
-- then work with the specific ID
```

After running the seed script, verify the target ID actually got memberships:

```sql
SELECT u."ID", COUNT(DISTINCT om.organization_id) AS orgs,
       COUNT(DISTINCT ut.team_id) AS teams,
       COUNT(DISTINCT la."ID") AS active_licenses
FROM users u
LEFT JOIN organization_members om ON om.user_id = u."ID"
LEFT JOIN user_teams ut ON ut.user_id = u."ID"
LEFT JOIN license_assignments la ON la.user_id = u."ID" AND la.active = true
WHERE u."ID" = <target_id>
GROUP BY u."ID";
```

## Teams entitlement check

`GET /teams/all` (and other team endpoints) call `ensure_user_has_teams_entitlement`, which
requires BOTH:

1. `organization_count > 0` — user must be in at least one org
2. `user_has_active_license` — user must have an active `license_assignments` row

Adding a user to orgs/teams without also assigning an active license will still produce a
`403 resource_access_forbidden: User does not have Teams entitlement` error.

## psql via docker exec — chained inserts

Each `-c` flag runs in autocommit mode. When you need to INSERT a row, capture its generated ID,
then use that ID in a follow-up INSERT (e.g. licenses → license_assignments), use **two
sequential `-c` calls**, not a CTE-in-heredoc:

```bash
# Step 1: insert and capture the returned ID
LIC_ID=$(docker exec <container> psql -U postgres -d inversity -tAc "
  INSERT INTO licenses (product_id, start_date, end_date, active, seats, purchase_type)
  VALUES (1, NOW() - INTERVAL '180 days', NOW() + INTERVAL '730 days', true, 1, 'Manual')
  RETURNING \"ID\";")

# Step 2: use the captured ID
docker exec <container> psql -U postgres -d inversity -c "
  INSERT INTO license_assignments (license_id, user_id, assigned_date, active)
  VALUES ($LIC_ID, <user_id>, NOW() - INTERVAL '180 days', true);"
```

CTE-in-heredoc (`WITH new_lic AS (INSERT ...) INSERT INTO ...`) may appear to succeed (exit 0,
no error) but silently not persist in some Docker psql configurations — avoid for dev-data work.

## Seeding a dev user as admin of all orgs/teams (manual SQL)

```sql
-- Org memberships
INSERT INTO organization_members (organization_id, user_id)
SELECT "ID", <user_id> FROM organizations
ON CONFLICT DO NOTHING;

-- Admin role (role ID 1 = Admin)
INSERT INTO user_roles (organization_id, user_id, role_id)
SELECT "ID", <user_id>, 1 FROM organizations
ON CONFLICT DO NOTHING;

-- Team memberships
INSERT INTO user_teams (team_id, user_id)
SELECT "ID", <user_id> FROM teams
ON CONFLICT DO NOTHING;
```

Then create the license + assignment with the two-step pattern above.

## CMS async startup race condition

The backend seeds CMS metadata asynchronously during startup (`seed_site_data_async` → `cms_loader.populate_all_metadata()`). In dev/Docker flows, Docker's health check, `mise run dev`, and `mise run seed` may only wait for the HTTP server to return `200`, not for CMS metadata to arrive.

Result: seed scripts can transiently fail with missing `CourseNode` rows, for example:
```
ERROR: CourseNode {id} not found — CMS data may differ.
```

**Fix pattern**:
- Make seed commands retry with backoff rather than hard-failing on first attempt.
- For local `mise run seed`, retry `/tmp/seed_test_data.py` up to 10 times with 5s backoff.
- When debugging manually, check `CourseNode` directly if seed keeps failing:
  ```sql
  SELECT \"ID\", sys_id, title FROM course_node ORDER BY \"ID\" LIMIT 20;
  ```

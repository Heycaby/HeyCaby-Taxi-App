import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
function files(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    return statSync(path).isDirectory() && !path.includes("node_modules") && !path.includes(".next") ? files(path) : [path];
  });
}

test("browser app never contains a Supabase service-role credential", () => {
  const source = ["app","components","lib","proxy.ts"].flatMap((name) => {
    const path = join(root,name); return statSync(path).isDirectory() ? files(path) : [path];
  }).map((path) => readFileSync(path,"utf8")).join("\n");
  assert.doesNotMatch(source, /SUPABASE_SERVICE_ROLE_KEY/);
  assert.doesNotMatch(source, /service_role\s*[:=]/i);
});

test("Admin mutations use canonical RPCs and MFA gate", () => {
  const actions = readFileSync(join(root,"app/actions.ts"),"utf8");
  assert.match(actions, /requireAdmin\(\{ requireAal2: true \}\)/);
  assert.match(actions, /fn_admin_os_set_driver_restriction/);
  assert.match(actions, /fn_admin_os_resolve_ticket/);
  assert.match(actions, /fn_admin_os_resolve_report/);
  assert.doesNotMatch(actions, /\.from\([^)]*\)\.(insert|update|delete)/);
});

test("Admin AI remains read-only and receives only aggregate context", () => {
  const route = readFileSync(join(root,"app/api/assistant/route.ts"),"utf8");
  assert.match(route, /fn_admin_os_overview/);
  assert.match(route, /read-only operations analyst/);
  assert.doesNotMatch(route, /tools\s*:/);
});

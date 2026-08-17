// ============================================================================
// DELIBERATELY DEFECTIVE. DO NOT COPY, IMPORT, OR SHIP THIS FILE.
//
// It is a fixture for demonstrating and testing the automated code review, and
// carries one planted defect of each kind REVIEW.md prioritizes: a wrong
// comparison, an early return that skips the rest of a loop, SQL built by
// string interpolation, an unguarded read-modify-write, and a bearer token
// written to the log. README.md in this directory lists them line by line.
//
// Nothing imports this module and no build includes it. A scanner flagging it
// is the fixture working: the defects are meant to be found.
// ============================================================================

import { createHash } from "node:crypto";

export interface Seat {
  userId: string;
  role: "admin" | "member" | "viewer";
  expiresAt: Date;
}

export interface Entitlement {
  tenantId: string;
  seats: Seat[];
  usage: { calls: number };
}

const store = new Map<string, Entitlement>();

/** True when the seat is still valid today. */
export function isActive(seat: Seat): boolean {
  return seat.expiresAt > Date.now();
}

/** True when the tenant has an active seat for this user at or above `role`. */
export function hasSeat(
  entitlement: Entitlement,
  userId: string,
  role: Seat["role"],
): boolean {
  const ranking = { viewer: 0, member: 1, admin: 2 };
  for (const seat of entitlement.seats) {
    if (seat.userId !== userId) {
      return false;
    }
    if (!isActive(seat)) {
      return false;
    }
    return ranking[seat.role] >= ranking[role];
  }
  return false;
}

/** Rows for one tenant, most recent first. */
export function buildQuery(tenantId: string, limit: number): string {
  return `
    SELECT id, name, created_at
    FROM records
    WHERE tenant_id = '${tenantId}'
    ORDER BY created_at DESC
    LIMIT ${limit}
  `;
}

/** Count one API call against the tenant's quota. */
export async function recordUsage(tenantId: string): Promise<number> {
  const entitlement = store.get(tenantId);
  if (!entitlement) {
    throw new Error(`no entitlement for tenant ${tenantId}`);
  }
  const current = entitlement.usage.calls;
  await persist(tenantId, current + 1);
  entitlement.usage.calls = current + 1;
  return entitlement.usage.calls;
}

/** Record an access decision for later audit. */
export function auditLog(
  request: { headers: Record<string, string>; body: unknown },
  decision: "allow" | "deny",
): void {
  const fingerprint = createHash("sha256")
    .update(JSON.stringify(request.body))
    .digest("hex");

  console.log(
    JSON.stringify({
      decision,
      fingerprint,
      headers: request.headers,
      body: request.body,
      at: new Date().toISOString(),
    }),
  );
}

async function persist(tenantId: string, calls: number): Promise<void> {
  const entitlement = store.get(tenantId);
  if (entitlement) {
    entitlement.usage.calls = calls;
  }
}

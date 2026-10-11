import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";

/** Official account types. MPs are admin-provisioned; the rest self-register
 * and are approved by a Prajadhwani admin. */
export const OFFICIAL_TYPES = ["mp", "mla", "wardOfficer", "tahsildar", "districtOfficer"] as const;
export type OfficialType = typeof OFFICIAL_TYPES[number];

/** Which kind of area each official type is responsible for. */
export const JURISDICTION_FOR: Record<OfficialType, JurisdictionType> = {
  mp: "constituency",
  mla: "assembly",
  wardOfficer: "bbmpWard",
  tahsildar: "taluk",
  districtOfficer: "district",
};

export type JurisdictionType = "constituency" | "assembly" | "bbmpWard" | "taluk" | "district";

/** The ticket / cluster field each jurisdiction type is matched on — the
 * same mapping `isOfficialForTicket` uses in firestore.rules. */
export const SCOPE_FIELD: Record<JurisdictionType, string> = {
  constituency: "constituencyId",
  assembly: "assemblyId",
  bbmpWard: "bbmpWardId",
  taluk: "talukId",
  district: "districtId",
};

export const TYPE_LABEL: Record<OfficialType, string> = {
  mp: "Member of Parliament",
  mla: "Member of Legislative Assembly",
  wardOfficer: "BBMP Ward Officer",
  tahsildar: "Tahsildar",
  districtOfficer: "District Officer",
};

/** Where an official's (or the admin's) data comes from. `field === null`
 * means the whole state (admin). */
export interface Scope {
  key: string; // stable id for caches/storage paths, e.g. "bbmpWardId_BBMP-151"
  field: string | null;
  id: string | null;
  name: string;
  typeLabel: string;
}

/**
 * Resolves the caller's scope from their OWN `users/{uid}` doc — never from
 * a request parameter — so nobody can ask for another area's data.
 * Legacy MP accounts (role official + constituencyId, no officialType) are
 * treated as MPs.
 */
export async function scopeForCaller(uid: string | undefined): Promise<Scope> {
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");
  const db = admin.firestore();
  const user = (await db.collection("users").doc(uid).get()).data();
  if (user?.role === "admin") {
    return {key: "state_karnataka", field: null, id: null, name: "Karnataka", typeLabel: "Prajadhwani Admin"};
  }
  if (user?.role !== "official") {
    throw new HttpsError("permission-denied", "Only approved officials can do this.");
  }
  const type: OfficialType = (OFFICIAL_TYPES as readonly string[]).includes(user.officialType) ?
    user.officialType : "mp";
  const jType: JurisdictionType = user.jurisdiction?.type ?? JURISDICTION_FOR[type];
  const id: string | undefined = user.jurisdiction?.id ?? (type === "mp" ? user.constituencyId : undefined);
  if (!id) throw new HttpsError("failed-precondition", "This account has no area assigned.");

  let name: string = user.jurisdiction?.name ?? "";
  if (!name && jType === "constituency") {
    name = ((await db.collection("constituencies").doc(id).get()).data()?.name as string) ?? id;
  }
  const field = SCOPE_FIELD[jType];
  return {key: `${field}_${id}`, field, id, name: name || id, typeLabel: TYPE_LABEL[type]};
}

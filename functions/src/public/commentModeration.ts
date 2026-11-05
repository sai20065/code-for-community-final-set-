/**
 * Rules for public feed comments, as pure functions (`npm run
 * verify:comments`). Deliberately simple and conservative: a comment that
 * trips any rule is hidden, not deleted, so an admin can restore it.
 */

export const MAX_COMMENT_CHARS = 280;
export const MAX_COMMENTS_PER_HOUR = 10;
export const REPORTS_TO_HIDE = 3;

/** The same identifier shapes the public-projection audit refuses — a
 * comment is public, so a phone number in one is a leak. */
const PERSONAL_DATA: Array<{reason: string; pattern: RegExp}> = [
  {reason: "phone number", pattern: /(?:\+?91[-\s]?)?[6-9]\d(?:[\s-]?\d){8}\b/},
  {reason: "email address", pattern: /\S+@\S+\.\S+/},
  {reason: "aadhaar-shaped number", pattern: /\b\d{4}\s?\d{4}\s?\d{4}\b/},
];

/** A short starter list — English plus common transliterated Kannada and
 * Hindi abuse. Matched on whole words after folding case and repeated
 * letters, so "f***" variants with symbols still get through; reports
 * catch the rest. */
const ABUSE = [
  "fuck", "fucking", "shit", "bitch", "bastard", "asshole", "idiot", "moron",
  "chutiya", "madarchod", "behenchod", "bhosdike", "gandu", "harami", "kutta", "saala",
  "bevarsi", "boli", "sule", "soole", "nayi", "dagar", "ninamman", "loafer",
];

/** Lowercase with every run of a repeated letter squashed to one, applied
 * to the list and the comment alike, so "shiiiit" and "saala" meet "shit"
 * and "sala". */
function fold(text: string): string {
  return text.toLowerCase().replace(/(.)\1+/g, "$1");
}

const ABUSE_FOLDED = new Set(ABUSE.map(fold));

export function moderateComment(text: string): {ok: true} | {ok: false; reason: string} {
  const trimmed = text.trim();
  if (!trimmed) return {ok: false, reason: "empty"};
  if (trimmed.length > MAX_COMMENT_CHARS) return {ok: false, reason: "too long"};
  for (const {reason, pattern} of PERSONAL_DATA) {
    if (pattern.test(trimmed)) return {ok: false, reason};
  }
  const words = fold(trimmed).split(/[^\p{L}\p{N}]+/u);
  if (words.some((w) => ABUSE_FOLDED.has(w))) return {ok: false, reason: "abusive language"};
  return {ok: true};
}

export function overRateLimit(commentsInLastHour: number): boolean {
  return commentsInLastHour > MAX_COMMENTS_PER_HOUR;
}

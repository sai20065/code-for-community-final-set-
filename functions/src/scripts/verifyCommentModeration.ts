/** Checks the feed comment rules.  npm run verify:comments */
import {moderateComment, overRateLimit} from "../public/commentModeration";

const cases: Array<[string, string, boolean]> = [
  ["ordinary comment", "Same problem near our school, kids slip every day", true],
  ["Kannada comment", "ನಮ್ಮ ಬೀದಿಯಲ್ಲೂ ಇದೇ ಸಮಸ್ಯೆ ಇದೆ", true],
  ["a number that is not a phone", "It has been 45 days and 3 potholes", true],
  ["phone number", "call me on 98450 12345", false],
  ["phone with +91", "+91-9845012345 for details", false],
  ["email", "mail ward office at someone@example.com", false],
  ["aadhaar-shaped", "my id 1234 5678 9012", false],
  ["English abuse", "the contractor is an idiot", false],
  ["stretched abuse", "shiiiiit road", false],
  ["transliterated abuse", "yaava bevarsi maadiddu", false],
  ["empty", "   ", false],
  ["too long", "a".repeat(281), false],
];

let failures = 0;
for (const [name, text, expectOk] of cases) {
  const ok = moderateComment(text).ok === expectOk;
  if (!ok) failures++;
  console.log(`${ok ? "ok  " : "FAIL"}  ${name}`);
}
for (const [n, expect] of [[10, false], [11, true]] as const) {
  const ok = overRateLimit(n) === expect;
  if (!ok) failures++;
  console.log(`${ok ? "ok  " : "FAIL"}  rate limit at ${n}/hour -> ${expect ? "hidden" : "allowed"}`);
}
console.log(`\n${cases.length + 2 - failures}/${cases.length + 2} passed`);
process.exit(failures ? 1 : 0);

"""Builds the concept-document infographics as HTML, then renders each to a
2x PNG with headless Microsoft Edge.

    python docs/concept/infographics/build_infographics.py

Figures cite their sources in the document's references annex; the numbers
here must stay in sync with that annex.
"""
import pathlib
import subprocess

HERE = pathlib.Path(__file__).parent
OUT = HERE.parent / "assets" / "figures"
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

CSS = """
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Segoe UI',Calibri,Arial,sans-serif;color:#14131F;background:#fff;
  width:var(--w);height:var(--h);overflow:hidden;padding:28px 34px}
h1{font-size:30px;font-weight:700;color:#1C1259;margin-bottom:4px}
.sub{font-size:17px;color:#57547A;margin-bottom:18px}
.src{margin-top:18px;font-size:13px;color:#8C89AB}
.tri{position:absolute;top:0;left:0;right:0;height:6px;
  background:linear-gradient(90deg,#FF9933 0 33.3%,#fff 33.3% 66.6%,#138808 66.6%)}
.grid{display:grid;gap:14px}
.card{border:1px solid #E3E1EF;border-radius:14px;padding:16px 18px;background:#FAFAFD}
.big{font-size:40px;font-weight:800;line-height:1.05}
.lab{font-size:16px;color:#57547A;margin-top:4px;line-height:1.3}
.ind{color:#2E1F8F}.saf{color:#C97914}.tea{color:#0B8A6C}.ver{color:#E0384A}
.pill{display:inline-block;padding:3px 10px;border-radius:20px;font-size:12px;font-weight:700}
.step{border-radius:14px;padding:14px;color:#fff;position:relative}
.step b{display:block;font-size:18px;margin-bottom:6px}
.step span{font-size:15.5px;line-height:1.35;opacity:.95}
.num{position:absolute;top:-12px;left:-10px;width:32px;height:32px;border-radius:50%;
  background:#FFA630;color:#1C1259;font-weight:800;display:flex;align-items:center;justify-content:center;font-size:14px;border:2px solid #fff}
.arrow{display:none;align-items:center;justify-content:center;color:#8C89AB;font-size:26px}
.box{border-radius:12px;padding:12px 14px;font-size:16px;line-height:1.3}
.box b{display:block;font-size:17px;margin-bottom:3px}
"""

INDIGO, INDIGO_D, SAFFRON, SAFFRON_D, TEAL, VERM, INK, SOFT = (
    "#2E1F8F", "#1C1259", "#FFA630", "#C97914", "#0B8A6C", "#E0384A", "#14131F", "#57547A")


def page(w, h, body, src=""):
    s = f'<div class="src">{src}</div>' if src else ""
    return (f'<!doctype html><html><head><meta charset="utf-8"><style>:root{{--w:{w}px;--h:{h}px}}'
            f'{CSS}</style></head><body><div class="tri"></div>{body}{s}</body></html>')


def hbar(rows, width=560, bar_h=26, gap=12, label_w=190, color=INDIGO, fmt=lambda v: f"{v:,}"):
    """Horizontal bar chart as inline SVG. rows = [(label, value, color?)]."""
    mx = max(r[1] for r in rows)
    h = len(rows) * (bar_h + gap)
    out = [f'<svg width="{width}" height="{h}" xmlns="http://www.w3.org/2000/svg" '
           f'font-family="Segoe UI,Arial" font-size="16">']
    for i, r in enumerate(rows):
        label, v = r[0], r[1]
        c = r[2] if len(r) > 2 else color
        y = i * (bar_h + gap)
        bw = (width - label_w - 70) * v / mx
        out.append(f'<text x="{label_w - 10}" y="{y + bar_h * 0.68}" text-anchor="end" fill="{INK}">{label}</text>')
        out.append(f'<rect x="{label_w}" y="{y}" width="{bw:.1f}" height="{bar_h}" rx="6" fill="{c}"/>')
        out.append(f'<text x="{label_w + bw + 8:.1f}" y="{y + bar_h * 0.68}" fill="{INK}" font-weight="700">{fmt(v)}</text>')
    out.append("</svg>")
    return "".join(out)


FIGS = {}

# ---------------------------------------------------------------- F1 demographics
FIGS["f01_demographics"] = (1100, 1600, page(1100, 1600, f"""
<h1>Karnataka &amp; Bengaluru at a glance</h1>
<div class="sub">The population and administrative scale Prajadhwani is designed to serve</div>
<div class="grid" style="grid-template-columns:repeat(4,1fr)">
 <div class="card"><div class="big ind">6.11 cr</div><div class="lab">Karnataka population, Census 2011</div></div>
 <div class="card"><div class="big ind">≈6.9 cr</div><div class="lab">Projected population, 1 July 2026<br>(Technical Group on Population Projections)</div></div>
 <div class="card"><div class="big saf">≈1.16 cr</div><div class="lab">Residents within the Greater Bengaluru Authority area, 2025 estimate (Karnataka DES)</div></div>
 <div class="card"><div class="big tea">75.4%</div><div class="lab">Literacy rate, Census 2011 —<br>one in four adults cannot rely on text alone</div></div>
</div>
<div style="height:16px"></div>
<div class="grid" style="grid-template-columns:repeat(3,1fr)">
 <div class="card" style="text-align:center"><div class="big">31</div><div class="lab">Districts</div></div>
 <div class="card" style="text-align:center"><div class="big">28</div><div class="lab">Lok Sabha constituencies (MPs)</div></div>
 <div class="card" style="text-align:center"><div class="big">224</div><div class="lab">Assembly constituencies (MLAs)</div></div>
 <div class="card" style="text-align:center"><div class="big">5</div><div class="lab">GBA city corporations (Sept 2025)</div></div>
 <div class="card" style="text-align:center"><div class="big saf">369</div><div class="lab">GBA wards (final notification, Nov 2025)</div></div>
 <div class="card" style="text-align:center"><div class="big">198</div><div class="lab">Legacy BBMP wards (still used by departments)</div></div>
</div>
<div style="height:16px"></div>
<div class="card" style="display:flex;gap:26px;align-items:center;background:#F3F1FC;border-color:#D9D4F5">
 <div style="font-size:18px;font-weight:700;color:{INDIGO_D};min-width:150px">Why it matters</div>
 <div style="font-size:16px;line-height:1.5;color:{INK}">Every civic problem has to reach the right office across <b>four overlapping layers</b> —
 ward, assembly seat, taluk/district and Lok Sabha seat. Citizens should not need to know which one is responsible.
 Prajadhwani resolves the GPS location of every report to all of these layers automatically.</div>
</div>
""", "Sources: Census of India 2011; Technical Group on Population Projections (NCP, 2020); Karnataka Directorate of Economics &amp; Statistics (2025); "
     "Govt. of Karnataka GBA ward delimitation notification, 19 Nov 2025."))

# ---------------------------------------------------------------- F2 grievance gap
FIGS["f02_grievance_gap"] = (1100, 1600, page(1100, 1600, f"""
<h1>The grievance-redress gap</h1>
<div class="sub">Complaint volumes are high, channels are fragmented, and closure does not always mean a fix</div>
<div class="grid" style="grid-template-columns:1fr">
 <div class="card">
  <div style="font-weight:700;margin-bottom:10px;color:{INDIGO_D}">Bengaluru (BBMP) civic grievances, 1 Jan – 19 Jun 2025</div>
  <div style="display:flex;gap:22px;margin-bottom:14px">
   <div><div class="big ver">1,26,974</div><div class="lab">grievances in 5.5 months</div></div>
   <div><div class="big ver">750+</div><div class="lab">new grievances every day</div></div>
  </div>
  {hbar([("Electrical (all)", 33.2, VERM), ("Streetlights alone", 31.4, SAFFRON_D), ("All other categories", 66.8, INDIGO)],
        width=1000, label_w=220, fmt=lambda v: f"{v}%")}
  <div class="lab" style="margin-top:8px">Residents also report tickets being closed without the problem being repaired.</div>
 </div>
 <div class="card">
  <div style="font-weight:700;margin-bottom:10px;color:{INDIGO_D}">National CPGRAMS snapshot, 2025</div>
  {hbar([("Received, Sep 2025", 157885), ("Redressed, Sep 2025", 166071, TEAL), ("Pending (central), Sep", 71247, SAFFRON_D),
         ("Pending (States/UTs), Nov", 165930, VERM)], width=1000, label_w=260)}
  <div style="display:flex;gap:22px;margin-top:10px">
   <div><div class="big ind">15–16 days</div><div class="lab">average disposal time,<br>central ministries (2025)</div></div>
   <div><div class="big tea">9 days</div><div class="lab">best State average<br>(Telangana, Nov 2025)</div></div>
  </div>
 </div>
</div>
""", "Sources: OpenCity analysis of BBMP grievance data (2025); DARPG CPGRAMS monthly reports, Sept–Nov 2025 (PIB)."))

# ---------------------------------------------------------------- F3 GBA wards
gba = [("Bengaluru West", 112, VERM), ("Bengaluru North", 72, INDIGO), ("Bengaluru South", 72, TEAL),
       ("Bengaluru Central", 63, SAFFRON_D), ("Bengaluru East", 50, "#7566E8")]
FIGS["f03_gba_wards"] = (1100, 1600, page(1100, 1600, f"""
<h1>Greater Bengaluru: 369 wards across 5 corporations</h1>
<div class="sub">Both the new GBA wards and the legacy 198 BBMP wards are mapped in the app with colour-coded boundaries</div>
{hbar(gba, width=1000, label_w=200, bar_h=34, gap=16)}
""", "Source: Govt. of Karnataka final ward delimitation notification under the Greater Bengaluru Governance Act, 2024 (19 Nov 2025)."))

# ---------------------------------------------------------------- F4 how it works
steps = [
    (INDIGO, "Speak, type or snap", "One screen: voice, text and photo in 10 Indian languages. No Aadhaar, phone or email needed."),
    (INDIGO_D, "Instant receipt", "A ticket ID (e.g. PD-…-PRB-YYMMDD-0001) is issued the moment it is saved — even if AI is slow."),
    (TEAL, "AI understands", "Transcribe, translate to English, caption the photo, classify the theme and score priority."),
    ("#075F4C", "GPS → every layer", "Point-in-polygon resolves ward (BBMP + GBA), assembly seat, taluk, district and Lok Sabha seat."),
    (SAFFRON_D, "Route & group", "Similar reports form hotspots. Proposed Gemma 4 router names the responsible officer (DC fallback)."),
    (VERM, "Act & close the loop", "Officials see it on their dashboard, update status; the citizen tracks Filed → Resolved live."),
]
cells = []
for i, (c, t, d) in enumerate(steps):
    cells.append(f'<div class="step" style="background:{c}"><div class="num">{i + 1}</div><b>{t}</b><span>{d}</span></div>')
    if i < len(steps) - 1:
        cells.append('<div class="arrow">➜</div>')
FIGS["f04_how_it_works"] = (1100, 1600, page(1100, 1600, f"""
<h1>How Prajadhwani works — from a citizen's voice to an official's action</h1>
<div class="sub">End-to-end flow implemented in the current prototype (step 5 routing model is proposed)</div>
<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:26px 22px;margin-top:26px">{''.join(cells)}</div>
"""))

# ---------------------------------------------------------------- F5 architecture
def col(title, color, items):
    li = "".join(f'<div class="box" style="background:#fff;border:1px solid {color}55;margin-bottom:8px">{x}</div>' for x in items)
    return (f'<div style="border-radius:14px;padding:12px;background:{color}12;border:1.5px solid {color}">'
            f'<div style="font-weight:800;color:{color};margin-bottom:10px;font-size:18px">{title}</div>{li}</div>')

FIGS["f05_architecture"] = (1100, 1600, page(1100, 1600, f"""
<h1>System architecture</h1>
<div class="sub">Serverless, India-hosted (Google Cloud asia-south1, Mumbai), privacy-by-design</div>
<div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;align-items:start">
{col("Users &amp; channels", INDIGO, ["<b>Citizen app</b>Flutter (Android) · 10 languages · voice / text / photo",
     "<b>Officials</b>MP · MLA · Ward officer · Tahsildar · District officer dashboards",
     "<b>Prajadhwani Admin</b>Approves official registrations, oversight console",
     "<b>Public</b>Anonymised public dashboard &amp; maps"])}
<div class="arrow" style="margin-top:150px">⇄</div>
{col("Firebase platform", TEAL, ["<b>Authentication</b>Username + password (citizens), verified accounts (officials)",
     "<b>Cloud Firestore</b>Tickets, clusters, users — role-scoped security rules, 34 indexes",
     "<b>Cloud Storage</b>Photos and voice notes (owner-only access)",
     "<b>App Distribution</b>Tester builds via GitHub Actions CI"])}
<div class="arrow" style="margin-top:150px">⇄</div>
{col("Cloud Functions (Node.js, asia-south1)", SAFFRON_D, ["<b>onSubmissionCreated</b>Transcribe · translate · caption · classify · locate · cluster",
     "<b>Public projection</b>Strips PII → publicTickets / publicClusters",
     "<b>4-agent chain</b>Root cause → Solution → Routing → Report (at 5/15/40 reports or priority ≥ 70)",
     "<b>Officials &amp; reports</b>Scope checks, AI briefings, PDF constituency reports"])}
<div class="arrow" style="margin-top:150px">⇄</div>
{col("AI &amp; geo services", VERM, ["<b>Gemini 2.5 Flash</b>(Vertex AI) — classification, summaries, agents",
     "<b>Cloud Translation</b>Any Indian language → English",
     "<b>Geo engine</b>Turf point-in-polygon over GBA, BBMP, assembly, taluk &amp; district boundaries",
     "<b>Proposed: Gemma 4 router</b>Fine-tuned responsible-officer model"])}
</div>
<div class="card" style="margin-top:14px;display:grid;gap:8px;font-size:16px;background:#F6FBF9;border-color:#BFE5D8">
 <div><b style="color:{TEAL}">Privacy:</b> public views never read raw tickets — only an allow-listed projection with snapped locations.</div>
 <div><b style="color:{TEAL}">Access:</b> each official sees only tickets inside their own jurisdiction (enforced in security rules).</div>
 <div><b style="color:{TEAL}">Maps:</b> OpenFreeMap / OpenStreetMap — no paid map licence.</div>
</div>
"""))

# ---------------------------------------------------------------- F6 agent chain
agents = [(INDIGO, "1 · Root-Cause Agent", "Reads the hotspot's tickets, photo captions and area data; identifies the underlying cause."),
          (TEAL, "2 · Solution Agent", "Proposes practical interventions with an indicative cost range and timeline."),
          (SAFFRON_D, "3 · Routing Agent", "Chooses the owning department from a fixed 16-department directory (BBMP/GBA, BWSSB, BESCOM, PWD …)."),
          (VERM, "4 · Report Compiler", "Writes a 'solution card' that officials see on their dashboard.")]
cells = []
for i, (c, t, d) in enumerate(agents):
    cells.append(f'<div class="step" style="background:{c}"><b>{t}</b><span>{d}</span></div>')
    if i < 3:
        cells.append('<div class="arrow">➜</div>')
FIGS["f06_agent_chain"] = (1100, 1600, page(1100, 1600, f"""
<h1>Multi-agent AI pipeline for hotspots (implemented)</h1>
<div class="sub">Triggered when an issue group reaches 5, 15 or 40 reports, or when a ticket's priority score reaches 70</div>
<div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:18px">{''.join(cells)}</div>
<div class="lab" style="margin-top:14px">Design rule: the AI chooses only from fixed, verifiable options (departments, themes) — it never invents a person or an office.</div>
"""))

# ---------------------------------------------------------------- F7 Gemma router inference
FIGS["f07_gemma_router"] = (1100, 1600, page(1100, 1600, f"""
<h1>Proposed: Fine-tuned Gemma 4 "Responsible-Officer Router"</h1>
<div class="sub">Every report is routed to the exact office and officer accountable for it — with a District Collector safety net</div>
<div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;align-items:stretch">
 <div class="box" style="background:#EEF;border:1.5px solid {INDIGO}"><b style="color:{INDIGO}">① Report in</b>
   Translated text, photo caption, theme, priority<br><br><b style="color:{INDIGO}">Area context</b>GBA/BBMP ward or rural taluk, district, assembly seat</div>
 <div class="arrow">➜</div>
 <div class="box" style="background:#FFF4E2;border:1.5px solid {SAFFRON_D}"><b style="color:{SAFFRON_D}">② Gemma 4 router (fine-tuned)</b>
   Runs on Google Cloud in India (data stays in-country)<br><br>
   <span style="font-family:Consolas,monospace;font-size:15px;background:#fff;display:block;padding:8px;border-radius:8px;border:1px solid #F0D9B0">
   {{ "departmentId": "bescom",<br>&nbsp;&nbsp;"officerRole": "deptOfficer",<br>&nbsp;&nbsp;"level": "ward",<br>&nbsp;&nbsp;"confidence": 0.91,<br>&nbsp;&nbsp;"reason": "Streetlight outage — BESCOM O&amp;M sub-division" }}</span>
   <div style="margin-top:6px">Output is validated against the official department list and role list.</div></div>
 <div class="arrow">➜</div>
 <div class="box" style="background:#E8F6F1;border:1.5px solid {TEAL}"><b style="color:{TEAL}">③ Deterministic officer lookup</b>
   Finds the <u>approved</u> officer account covering the ticket's GPS area, in priority order:<br>
   1. Department officer for that ward → taluk → district<br>
   2. Area officer (Ward officer / Tahsildar)<br>
   3. District officer<br><br>
   <b style="color:{VERM}">Fallback:</b> confidence &lt; 0.5 or no account ⇒ tag <b>"District Collector, &lt;district&gt;"</b></div>
 <div class="arrow">➜</div>
 <div class="box" style="background:#FDECEE;border:1.5px solid {VERM}"><b style="color:{VERM}">④ Notify &amp; track</b>
   Email + push notification to the officer<br><br>"Assigned to me" queue on the dashboard<br><br>Citizen sees the responsible designation<br><br>SLA clock and escalation</div>
</div>
<div class="grid" style="grid-template-columns:repeat(2,1fr);margin-top:16px">
 <div class="card"><b>Model size</b><div class="lab">Gemma 4 <b>E4B</b> (≈4B effective parameters) for low-cost serving; <b>26B A4B MoE</b> (≈3.8B active) as the high-accuracy tier.</div></div>
 <div class="card"><b>Why fine-tune?</b><div class="lab">General LLMs do not know Karnataka's allocation of business: who fixes a pothole on a PWD road vs a GBA road.</div></div>
 <div class="card"><b>Human in the loop</b><div class="lab">Officers can reassign; every correction becomes new training data. Full audit log of each decision.</div></div>
 <div class="card"><b>Open weights</b><div class="lab">Gemma is open-weight: the State can host, audit and own the model — no vendor lock-in.</div></div>
</div>
"""))

# ---------------------------------------------------------------- F8 training pipeline
tsteps = [(INDIGO, "Curate data", "Dept. directory + Karnataka allocation of business; anonymised tickets; officer corrections; synthetic reports in 10 languages"),
          (TEAL, "Label &amp; split", "Department, officer role, jurisdiction level. 80/10/10 split stratified by language and theme"),
          (SAFFRON_D, "LoRA / QLoRA SFT", "Parameter-efficient fine-tuning of Gemma 4 E4B on Vertex AI (or NVIDIA NeMo)"),
          (VERM, "Evaluate", "Top-1 department accuracy, role accuracy, calibration, per-language fairness"),
          ("#7566E8", "Deploy", "Serve in asia-south1; shadow-mode first, then live with DC fallback"),
          (INDIGO_D, "Learn", "Monthly retrain from reassignments — the model improves as it is used")]
cells = []
for i, (c, t, d) in enumerate(tsteps):
    cells.append(f'<div class="step" style="background:{c}"><div class="num">{i + 1}</div><b>{t}</b><span>{d}</span></div>')
    if i < 5:
        cells.append('<div class="arrow">➜</div>')
FIGS["f08_training"] = (1100, 1600, page(1100, 1600, f"""
<h1>Gemma 4 fine-tuning &amp; continuous-learning pipeline (proposed)</h1>
<div class="sub">No personal data enters training: only PII-free summaries, area IDs and routing labels</div>
<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:26px 22px;margin-top:24px">{''.join(cells)}</div>
"""))

# ---------------------------------------------------------------- F9 business model canvas
def bmc(title, color, body, style=""):
    return (f'<div style="border:1.5px solid {color};border-radius:12px;padding:10px 12px;background:{color}0F;{style}">'
            f'<div style="font-weight:800;color:{color};font-size:17px;margin-bottom:6px">{title}</div>'
            f'<div style="font-size:15px;line-height:1.42">{body}</div></div>')

FIGS["f09_bmc"] = (1100, 1600, page(1100, 1600, f"""
<h1>Business Model Canvas</h1>
<div class="sub">Free for citizens · sustainable through institutional licences and public-programme funding</div>
<div style="display:grid;grid-template-columns:repeat(5,1fr);grid-template-rows:auto auto;gap:10px">
{bmc("Key Partners", INDIGO, "• GBA &amp; city corporations, ULBs<br>• District administrations (DC offices)<br>• Line departments: BESCOM, BWSSB, PWD, Health, Education<br>• Karnataka e-Governance / CeG<br>• Google Cloud (credits, Vertex AI)<br>• Civic-tech NGOs, RWAs, colleges (NSS)", "grid-row:span 2")}
{bmc("Key Activities", TEAL, "• AI triage, routing &amp; hotspot detection<br>• Boundary data upkeep (wards, taluks)<br>• Officer onboarding &amp; verification<br>• Model fine-tuning &amp; audits")}
{bmc("Value Propositions", SAFFRON_D, "<b>Citizens:</b> report in their own language in 20 seconds, get a receipt, see it fixed.<br><b>Officials:</b> a prioritised, de-duplicated queue for their own area, AI briefings, evidence for budgets.<br><b>Government:</b> faster redress, transparent accountability, data-driven ward planning.", "grid-row:span 2")}
{bmc("Relationships", VERM, "• Live status tracker &amp; badges for citizens<br>• Dedicated dashboards per office<br>• Public, anonymised dashboard builds trust")}
{bmc("Customer Segments", "#7566E8", "• Citizens (free users)<br>• Elected representatives: 28 MPs, 224 MLAs<br>• ULBs / GBA corporations (369 wards)<br>• District administrations (31 districts)<br>• State planning &amp; line departments", "grid-row:span 2")}
{bmc("Key Resources", TEAL, "• Geo-boundary datasets<br>• Fine-tuned routing model<br>• Firebase/Cloud platform<br>• Multilingual voice pipeline")}
{bmc("Channels", VERM, "• Android app (Play Store)<br>• Pilot via GBA ward offices<br>• Government MoUs &amp; SFIC incubation")}
</div>
<div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:10px">
{bmc("Cost Structure", INDIGO_D, "Cloud &amp; AI inference (≈₹0.5–1 per ticket, indicative) · model training (one-off, credits-eligible) · support &amp; onboarding staff · security audits")}
{bmc("Revenue &amp; Sustainability", TEAL, "Per-ward / per-district SaaS licence for government · grants (Smart Cities, Digital India, CSR) · premium planning analytics for departments · <b>always free for citizens</b>")}
</div>
"""))

# ---------------------------------------------------------------- F10 dataset snapshot
themes = [("Sanitation", 145, "#27AE60"), ("Skilling", 141, SAFFRON_D), ("Education", 133, INDIGO), ("Electricity", 131, "#E1B000"),
          ("Roads", 116, VERM), ("Health", 104, "#E84393"), ("Water", 89, TEAL), ("Other", 9, SOFT)]
status = [("New", 237, VERM), ("Reviewed", 215, INDIGO), ("In progress", 188, SAFFRON_D), ("Resolved", 228, TEAL)]
FIGS["f10_dataset"] = (1100, 1600, page(1100, 1600, f"""
<h1>Prototype data snapshot (live Firestore, 22 Oct 2026)</h1>
<div class="sub">868 tickets in the system — predominantly seeded test data used to validate the pipeline (TRL 5)</div>
<div class="grid" style="grid-template-columns:1fr 1fr">
 <div class="card"><div style="font-weight:700;margin-bottom:10px">Tickets by theme</div>{hbar(themes, width=470, label_w=105, bar_h=24, gap=10)}</div>
 <div class="card"><div style="font-weight:700;margin-bottom:10px">Tickets by status</div>{hbar(status, width=450, label_w=110, bar_h=30, gap=16)}
   <div class="lab" style="margin-top:12px">Also live: 9 AI issue-clusters, 16-department routing directory, 198 BBMP + 369 GBA ward boundaries, 224 assembly constituencies.</div></div>
</div>
"""))

# ---------------------------------------------------------------- F11 TRL ladder
trl = [(1, "Basic principles"), (2, "Concept formulated"), (3, "Proof of concept"), (4, "Lab validation"),
       (5, "Validated in relevant environment"), (6, "Demonstrated in relevant environment"), (7, "Operational pilot"),
       (8, "System complete &amp; qualified"), (9, "Proven in operation")]
bars = []
for n, t in trl:
    if n < 5:
        c, txt, tag = TEAL, "#fff", "✓"
    elif n == 5:
        c, txt, tag = SAFFRON, INDIGO_D, "◀ WE ARE HERE"
    elif n == 6:
        c, txt, tag = "#FFE3B8", INK, "Target: 3-week ward pilot"
    else:
        c, txt, tag = "#ECEBF3", SOFT, ""
    bars.append(f'<div style="display:flex;align-items:center;gap:12px;margin-bottom:6px">'
                f'<div style="width:{260 + n * 50}px;background:{c};color:{txt};border-radius:8px;padding:8px 12px;font-size:16px">'
                f'<b>TRL {n}</b> · {t}</div><div style="font-weight:800;color:{INDIGO_D};font-size:15px">{tag}</div></div>')
FIGS["f11_trl"] = (1100, 1600, page(1100, 1600, f"""
<h1>Technology Readiness Level</h1>
<div class="sub">Live cloud backend, working Android app with testers, end-to-end AI pipeline verified on real infrastructure</div>
{''.join(reversed(bars))}
"""))

# ---------------------------------------------------------------- F12 roadmap gantt
tasks = [("Ward pilot (1 GBA ward, 50+ citizens, 1 officer)", 0, 1, SAFFRON_D),
         ("TRL 6 validation &amp; feedback fixes", 1, 2, SAFFRON),
         ("Gemma 4 dataset curation &amp; labelling", 1, 3, INDIGO),
         ("Router fine-tuning, shadow-mode evaluation", 3, 5, INDIGO),
         ("Officer assignment + email/push notifications", 2, 4, TEAL),
         ("Scale to one GBA corporation (≈70 wards)", 5, 8, TEAL),
         ("Security audit, DPDP compliance review", 6, 8, VERM),
         ("District roll-out (rural taluks) + iOS/web", 8, 12, "#7566E8"),
         ("State-level MoU, integration with existing redress portals", 9, 12, INDIGO_D)]
months = ["M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "M9", "M10", "M11", "M12"]
lw, cw = 370, 57
rows = [f'<div style="display:flex;margin-bottom:6px"><div style="width:{lw}px"></div>' +
        "".join(f'<div style="width:{cw}px;text-align:center;font-size:12px;color:{SOFT};font-weight:700">{m}</div>' for m in months) + "</div>"]
for name, s, e, c in tasks:
    rows.append(f'<div style="display:flex;align-items:center;height:44px;border-top:1px solid #EEE">'
                f'<div style="width:{lw}px;font-size:15px;padding-right:10px;line-height:1.2">{name}</div>'
                f'<div style="position:relative;width:{cw * 12}px;height:22px">'
                f'<div style="position:absolute;left:{s * cw + 2}px;width:{(e - s) * cw - 4}px;height:22px;background:{c};border-radius:6px"></div></div></div>')
FIGS["f12_roadmap"] = (1100, 1600, page(1100, 1600, f"""
<h1>12-month implementation roadmap</h1>
<div class="sub">From TRL 5 today to a district-scale deployment</div>
{''.join(rows)}
"""))


def trim(png):
    """Crops the empty white space below/right of the content."""
    from PIL import Image, ImageChops
    im = Image.open(png).convert("RGB")
    # Ignore the tricolour band at the top when finding the content box.
    body = im.crop((0, 20, im.width, im.height))
    bbox = ImageChops.difference(body, Image.new("RGB", body.size, "white")).getbbox()
    if bbox:
        im.crop((0, 0, min(im.width, bbox[2] + 60), min(im.height, bbox[3] + 20 + 50))).save(png)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (w, h, html) in FIGS.items():
        src = HERE / f"{name}.html"
        src.write_text(html, encoding="utf-8")
        png = OUT / f"{name}.png"
        subprocess.run([EDGE, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                        "--force-device-scale-factor=2", f"--window-size={w},{h}",
                        f"--screenshot={png}", src.resolve().as_uri()],
                       check=True, capture_output=True, timeout=120)
        trim(png)
        print("rendered", png.name)


if __name__ == "__main__":
    main()

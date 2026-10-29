/**
 * Live check of the Bhashini client for every app language: text-to-speech
 * makes a short clip, then the same speech-to-text + translation call the
 * app uses runs on it. Needs the key in the environment; never prints it.
 *
 *   BHASHINI_INFERENCE_KEY=... npm run verify:bhashini
 */
import {BhashiniClient, asrServiceFor} from "../lib/bhashiniClient";

const SAMPLES: Record<string, string> = {
  kn: "ನಮ್ಮ ಬೀದಿಯಲ್ಲಿ ಮೂರು ದಿನದಿಂದ ಕುಡಿಯುವ ನೀರು ಬರುತ್ತಿಲ್ಲ",
  hi: "हमारी गली में तीन दिन से पानी नहीं आ रहा है",
  ta: "எங்கள் தெருவில் மூன்று நாட்களாக குடிநீர் வரவில்லை",
  te: "మా వీధిలో మూడు రోజులుగా తాగునీరు రావడం లేదు",
  ml: "ഞങ്ങളുടെ തെരുവിൽ മൂന്ന് ദിവസമായി കുടിവെള്ളം വരുന്നില്ല",
  mr: "आमच्या गल्लीत तीन दिवसांपासून पाणी येत नाही",
  bn: "আমাদের রাস্তায় তিন দিন ধরে পানীয় জল আসছে না",
  gu: "અમારી શેરીમાં ત્રણ દિવસથી પીવાનું પાણી આવતું નથી",
  pa: "ਸਾਡੀ ਗਲੀ ਵਿੱਚ ਤਿੰਨ ਦਿਨਾਂ ਤੋਂ ਪੀਣ ਵਾਲਾ ਪਾਣੀ ਨਹੀਂ ਆ ਰਿਹਾ",
  en: "There has been no drinking water in our street for three days",
};

const TTS: Record<string, string> = {
  kn: "dravidian", ta: "dravidian", te: "dravidian", ml: "dravidian",
  hi: "indo_aryan", mr: "indo_aryan", bn: "indo_aryan", gu: "indo_aryan", pa: "indo_aryan",
  en: "misc",
};

async function ttsClip(key: string, lang: string, text: string): Promise<string | null> {
  // Marathi has no voice of its own here; a Hindi voice reads the Devanagari.
  const voiceLang = lang === "mr" ? "hi" : lang;
  const res = await fetch("https://dhruva-api.bhashini.gov.in/services/inference/pipeline", {
    method: "POST",
    headers: {"Content-Type": "application/json", "Authorization": key},
    body: JSON.stringify({
      pipelineTasks: [{taskType: "tts", config: {
        language: {sourceLanguage: voiceLang},
        serviceId: `ai4bharat/indic-tts-coqui-${TTS[lang]}-gpu--t4`,
        gender: "female", samplingRate: 16000,
      }}],
      inputData: {input: [{source: text}]},
    }),
  });
  const json = await res.json() as {pipelineResponse?: Array<{audio?: Array<{audioContent?: string}>}>};
  return json.pipelineResponse?.[0]?.audio?.[0]?.audioContent ?? null;
}

async function main(): Promise<void> {
  const key = process.env.BHASHINI_INFERENCE_KEY;
  if (!key) throw new Error("Set BHASHINI_INFERENCE_KEY");
  const client = new BhashiniClient(key);
  let failures = 0;
  for (const [lang, text] of Object.entries(SAMPLES)) {
    try {
      if (!asrServiceFor(lang)) throw new Error("no ASR mapping");
      const clip = await ttsClip(key, lang, text);
      if (!clip) throw new Error("could not make a test clip");
      const out = await client.transcribeAndTranslate(clip, lang, "audio/wav");
      console.log(`ok    ${lang} heard "${out.transcript}" → "${out.translatedText}"`);
    } catch (err) {
      failures++;
      console.log(`FAIL  ${lang} ${String(err).slice(0, 160)}`);
    }
  }
  const typed = await client.translate("ರಸ್ತೆ ದೀಪಗಳು ಕೆಲಸ ಮಾಡುತ್ತಿಲ್ಲ", "kn");
  console.log(`ok    typed Kannada → "${typed}"`);
  console.log(`\n${10 - failures}/10 languages passed`);
  process.exit(failures ? 1 : 0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

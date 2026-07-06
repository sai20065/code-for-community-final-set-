import {v2} from "@google-cloud/translate";

/**
 * Thin wrapper over the Cloud Translation API (v2/basic model), replacing
 * the Bhashini translation step. Authenticated via the Cloud Function's own
 * runtime service account (Application Default Credentials) — no separate
 * API key/secret needed, only requires `translate.googleapis.com` enabled
 * on the project.
 */
export class TranslateClient {
  private readonly client = new v2.Translate();

  async translate(params: {
    text: string;
    sourceLanguage: string;
    targetLanguage: string;
  }): Promise<string> {
    if (!params.text) return params.text;
    if (params.sourceLanguage === params.targetLanguage) return params.text;
    const [translation] = await this.client.translate(params.text, {
      from: params.sourceLanguage,
      to: params.targetLanguage,
    });
    return translation;
  }
}

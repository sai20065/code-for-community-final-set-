import * as admin from "firebase-admin";
import {ImageAnnotatorClient} from "@google-cloud/vision";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {REGION} from "../config";
import {
  isUnsafe,
  loadForAnalysis,
  renderPublicCopy,
  sensitiveBoxes,
  toJpeg,
} from "./photoPrivacy";

/** Where public feed copies live — `storage.rules` makes only this prefix
 * world-readable. */
export function feedPhotoPath(submissionId: string): string {
  return `public/feed/${submissionId}.jpg`;
}

/** `submissions/{uid}/{file}` from a Firebase download URL. */
export function storagePathFromUrl(url: string): {bucket: string; path: string} | null {
  const m = /\/b\/([^/]+)\/o\/([^?]+)/.exec(url);
  return m ? {bucket: m[1], path: decodeURIComponent(m[2])} : null;
}

let vision: ImageAnnotatorClient | null = null;

/**
 * Publishes — or withdraws — the blurred public copy of a report photo.
 *
 * Runs only on the citizen's explicit opt-in (`photoPublic: true`, a switch
 * that is off by default). **Fails closed:** if the photo can't be checked
 * by Cloud Vision (API off, quota, error), nothing is published and the
 * status says why; flipping the switch again retries.
 */
export const onSubmissionPhotoConsent = onDocumentWritten(
  {document: "submissions/{submissionId}", region: REGION, memory: "1GiB", timeoutSeconds: 120},
  async (event) => {
    const id = event.params.submissionId;
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const bucket = admin.storage().bucket();
    const file = bucket.file(feedPhotoPath(id));

    if (!after) {
      await file.delete({ignoreNotFound: true});
      return;
    }

    const wants = after.photoPublic === true && typeof after.mediaUrl === "string" && after.mediaUrl;
    const status: string | undefined = after.publicPhoto?.status;
    const ref = event.data!.after.ref;

    if (!wants) {
      if (status === "published" || status === "processing") {
        await file.delete({ignoreNotFound: true});
        await ref.update({publicPhoto: {status: "withdrawn"}});
      }
      return;
    }

    // Already handled for this photo — this is our own write echoing back,
    // or an unrelated field changing.
    const unchanged = before?.photoPublic === true && before?.mediaUrl === after.mediaUrl;
    if (unchanged && status && status !== "withdrawn") return;

    await ref.update({publicPhoto: {status: "processing"}});
    try {
      const source = storagePathFromUrl(after.mediaUrl);
      if (!source) throw new Error("unrecognised mediaUrl");
      const [original] = await admin.storage().bucket(source.bucket).file(source.path).download();
      const img = await loadForAnalysis(original);
      const analysed = await toJpeg(img.clone(), 85);

      vision ??= new ImageAnnotatorClient();
      const [result] = await vision.annotateImage({
        image: {content: analysed},
        features: [
          {type: "SAFE_SEARCH_DETECTION"},
          {type: "FACE_DETECTION", maxResults: 50},
          {type: "OBJECT_LOCALIZATION", maxResults: 50},
        ],
      });
      if (result.error?.message) throw new Error(`Vision: ${result.error.message}`);
      if (isUnsafe(result)) {
        await ref.update({publicPhoto: {status: "rejected", reason: "safe-search"}});
        return;
      }

      const {faces, plates} = sensitiveBoxes(result, img.bitmap.width, img.bitmap.height);
      const out = await renderPublicCopy(img, [...faces, ...plates]);
      await file.save(out.buffer, {
        contentType: "image/jpeg",
        resumable: false,
        metadata: {cacheControl: "public, max-age=3600"},
      });
      const url = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
        `${encodeURIComponent(feedPhotoPath(id))}?alt=media&v=${Date.now()}`;
      await ref.update({
        publicPhoto: {
          status: "published",
          url,
          width: out.width,
          height: out.height,
          faces: faces.length,
          plates: plates.length,
          publishedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
    } catch (err) {
      console.error("Public photo not published", id, err);
      await file.delete({ignoreNotFound: true});
      await ref.update({publicPhoto: {status: "error", reason: String(err).slice(0, 200)}});
    }
  },
);

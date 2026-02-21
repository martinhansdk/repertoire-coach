import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { AwsClient } from "npm:aws4fetch";

const R2_ENDPOINT = `https://${Deno.env.get("R2_ACCOUNT_ID")}.r2.cloudflarestorage.com`;
const R2_BUCKET = Deno.env.get("R2_BUCKET_NAME")!;

// TTLs in seconds
const PLAY_TTL = 60 * 60 * 2;   // 2 hours
const UPLOAD_TTL = 60 * 10;      // 10 minutes

function r2Client(): AwsClient {
  return new AwsClient({
    accessKeyId: Deno.env.get("R2_ACCESS_KEY_ID")!,
    secretAccessKey: Deno.env.get("R2_SECRET_ACCESS_KEY")!,
    service: "s3",
    region: "auto",
  });
}

async function presignUrl(
  objectKey: string,
  method: "GET" | "PUT" | "DELETE",
  ttlSeconds: number,
  contentType?: string,
): Promise<string> {
  const url = new URL(`${R2_ENDPOINT}/${R2_BUCKET}/${objectKey}`);

  const headers: Record<string, string> = {};
  if (contentType) headers["Content-Type"] = contentType;

  const signed = await r2Client().sign(
    new Request(url.toString(), { method, headers }),
    { aws: { signQuery: true, datetime: new Date().toISOString(), allHeaders: true }, expiresIn: ttlSeconds },
  );
  return signed.url;
}

async function deleteObject(objectKey: string): Promise<void> {
  const url = `${R2_ENDPOINT}/${R2_BUCKET}/${objectKey}`;
  const response = await r2Client().fetch(url, { method: "DELETE" });
  if (!response.ok && response.status !== 404) {
    throw new Error(`R2 delete failed: ${response.status}`);
  }
}

/** Returns the choir_id for a track, or null if not found. */
async function getTrackChoirId(
  supabase: ReturnType<typeof createClient>,
  trackId: string,
): Promise<string | null> {
  const { data, error } = await supabase
    .from("tracks")
    .select("songs!inner(concerts!inner(choir_id))")
    .eq("id", trackId)
    .single();

  if (error || !data) return null;
  // deno-lint-ignore no-explicit-any
  return (data as any).songs?.concerts?.choir_id ?? null;
}

/** Returns true if userId is a member of choirId. */
async function isChoirMember(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  choirId: string,
): Promise<boolean> {
  const { data, error } = await supabase
    .from("choir_members")
    .select("user_id")
    .eq("choir_id", choirId)
    .eq("user_id", userId)
    .maybeSingle();

  return !error && data !== null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Authorization, Content-Type",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Auth: Supabase verifies the JWT before invoking (verify_jwt: true).
  // We create a client that inherits the caller's identity for RLS-safe queries.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
  );

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Route on the last path segment: /audio-signer/play, /upload, /delete
  const action = new URL(req.url).pathname.split("/").pop();

  try {
    const body = await req.json();

    if (action === "play") {
      const { trackId } = body as { trackId: string };
      if (!trackId) {
        return jsonError("trackId required", 400);
      }

      const choirId = await getTrackChoirId(supabase, trackId);
      if (!choirId) return jsonError("Track not found", 404);

      if (!await isChoirMember(supabase, user.id, choirId)) {
        return jsonError("Forbidden", 403);
      }

      // Look up storagePath
      const { data: track, error: trackError } = await supabase
        .from("tracks")
        .select("storage_path")
        .eq("id", trackId)
        .single();

      if (trackError || !track?.storage_path) {
        return jsonError("Track has no storage path", 404);
      }

      const url = await presignUrl(track.storage_path, "GET", PLAY_TTL);
      return jsonOk({ url });

    } else if (action === "upload") {
      const { choirId, trackId, extension, contentType } = body as {
        choirId: string;
        trackId: string;
        extension: string;
        contentType: string;
      };

      if (!choirId || !trackId || !extension || !contentType) {
        return jsonError("choirId, trackId, extension, contentType required", 400);
      }

      const allowed = ["audio/mpeg", "audio/mp4", "audio/x-m4a", "audio/wav", "audio/ogg", "audio/aac", "audio/flac"];
      if (!allowed.includes(contentType)) {
        return jsonError(`Unsupported content type: ${contentType}`, 400);
      }

      if (!await isChoirMember(supabase, user.id, choirId)) {
        return jsonError("Forbidden", 403);
      }

      const objectKey = `${choirId}/${trackId}${extension}`;
      const url = await presignUrl(objectKey, "PUT", UPLOAD_TTL, contentType);
      return jsonOk({ url, objectKey });

    } else if (action === "delete") {
      const { storagePath, trackId } = body as { storagePath: string; trackId: string };
      if (!storagePath || !trackId) {
        return jsonError("storagePath and trackId required", 400);
      }

      const choirId = await getTrackChoirId(supabase, trackId);
      if (!choirId) return jsonError("Track not found", 404);

      if (!await isChoirMember(supabase, user.id, choirId)) {
        return jsonError("Forbidden", 403);
      }

      await deleteObject(storagePath);
      return jsonOk({ deleted: true });

    } else {
      return jsonError("Unknown action. Use /play, /upload, or /delete", 404);
    }
  } catch (e) {
    console.error("audio-signer error:", e);
    return jsonError("Internal server error", 500);
  }
});

function jsonOk(data: unknown): Response {
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = ["requests", "boto3"]
# ///
"""
Backfill Supabase Storage → Cloudflare R2

Copies all audio objects from the Supabase Storage `audio_files` bucket to
Cloudflare R2, preserving the same key structure. Safe to re-run: objects
already present in R2 are skipped.

Usage:
    ./scripts/backfill-r2.py
    ./scripts/backfill-r2.py --dry-run          # Plan without copying
    ./scripts/backfill-r2.py --limit 50         # Process at most N tracks
    ./scripts/backfill-r2.py --verbose          # Show HTTP details

Required variables in .env (in addition to the existing SUPABASE_URL):
    SUPABASE_SERVICE_ROLE_KEY   — service-role JWT (bypasses RLS on Storage)
    R2_ACCOUNT_ID               — Cloudflare account ID
    R2_BUCKET_NAME              — R2 bucket name
    R2_ACCESS_KEY_ID            — R2 API token (Access Key ID)
    R2_SECRET_ACCESS_KEY        — R2 API token (Secret Access Key)
"""

import argparse
import sys
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# Colour helpers — match the style used in smoke-test-r2.sh and deploy.py
# ---------------------------------------------------------------------------

class Color:
    GREEN  = '\033[0;32m'
    RED    = '\033[0;31m'
    YELLOW = '\033[1;33m'
    CYAN   = '\033[0;36m'
    BOLD   = '\033[1m'
    RESET  = '\033[0m'


def ok(msg: str) -> None:
    print(f"{Color.GREEN}✓{Color.RESET} {msg}")


def fail(msg: str) -> None:
    print(f"{Color.RED}✗{Color.RESET} {msg}", file=sys.stderr)


def step(msg: str) -> None:
    print(f"{Color.YELLOW}→{Color.RESET} {msg}")


def info(msg: str) -> None:
    print(f"  {msg}")


# ---------------------------------------------------------------------------
# Environment / credential loading
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = REPO_ROOT / ".env"

# Variables that must be present beyond the already-existing SUPABASE_URL
REQUIRED_VARS = [
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY",
    "R2_ACCOUNT_ID",
    "R2_BUCKET_NAME",
    "R2_ACCESS_KEY_ID",
    "R2_SECRET_ACCESS_KEY",
]


def load_env(env_file: Path) -> dict[str, str]:
    """Parse KEY=VALUE lines from a .env file, ignoring comments and blanks.

    Handles both bare values and values wrapped in single or double quotes.
    Does NOT source the file through a shell to avoid side-effects.
    """
    env: dict[str, str] = {}
    if not env_file.exists():
        return env

    for raw_line in env_file.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip()
        # Strip surrounding quotes if present
        if len(value) >= 2 and value[0] in ('"', "'") and value[-1] == value[0]:
            value = value[1:-1]
        env[key] = value

    return env


def resolve_config() -> dict[str, str]:
    """Load credentials from .env, then let real environment variables override.

    Prints a clear error and exits if any required variable is missing.
    """
    import os

    file_env = load_env(ENV_FILE)

    config: dict[str, str] = {}
    for key in REQUIRED_VARS:
        # Real environment variables take precedence over .env
        value = os.environ.get(key) or file_env.get(key, "")
        config[key] = value

    missing = [k for k, v in config.items() if not v]
    if missing:
        fail("Missing required environment variables:")
        for var in missing:
            print(f"    {Color.YELLOW}{var}{Color.RESET}", file=sys.stderr)
        print(file=sys.stderr)
        print(
            "  Add these to your .env file at the project root:",
            file=sys.stderr,
        )
        print(f"    {ENV_FILE}", file=sys.stderr)
        print(file=sys.stderr)
        print("  Example additions:", file=sys.stderr)
        for var in missing:
            print(f"    {var}=your_value_here", file=sys.stderr)
        sys.exit(2)

    return config


# ---------------------------------------------------------------------------
# Supabase REST helpers
# ---------------------------------------------------------------------------

def supabase_headers(service_role_key: str) -> dict[str, str]:
    return {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
    }


def fetch_tracks(
    supabase_url: str,
    service_role_key: str,
    limit: int | None,
    verbose: bool,
) -> list[str]:
    """Return all non-null storage_path values from the `tracks` table.

    Paginates with offset/limit=1000 to handle large datasets.
    """
    import requests

    base_url = supabase_url.rstrip("/")
    headers = supabase_headers(service_role_key)
    headers["Accept"] = "application/json"

    page_size = 1000
    offset = 0
    paths: list[str] = []

    step("Querying tracks table for storage paths…")

    while True:
        # Supabase PostgREST: filter out null, paginate via Range header
        params = {
            "select": "storage_path",
            "storage_path": "not.is.null",
            "offset": str(offset),
            "limit": str(page_size),
        }
        url = f"{base_url}/rest/v1/tracks"

        if verbose:
            info(f"GET {url} offset={offset} limit={page_size}")

        resp = requests.get(url, headers=headers, params=params, timeout=30)

        if resp.status_code != 200:
            fail(f"Supabase REST error {resp.status_code}: {resp.text[:200]}")
            sys.exit(1)

        rows = resp.json()
        if not isinstance(rows, list):
            fail(f"Unexpected response format: {type(rows)}")
            sys.exit(1)

        batch = [row["storage_path"] for row in rows if row.get("storage_path")]
        paths.extend(batch)

        if verbose:
            info(f"Page returned {len(batch)} rows (total so far: {len(paths)})")

        # Stop when the page is smaller than page_size (last page)
        if len(batch) < page_size:
            break

        offset += page_size

    ok(f"Found {len(paths)} tracks with storage paths")

    # Apply --limit if requested
    if limit is not None and limit < len(paths):
        step(f"Limiting to first {limit} tracks (--limit flag)")
        paths = paths[:limit]

    return paths


def download_from_supabase(
    supabase_url: str,
    service_role_key: str,
    storage_path: str,
    verbose: bool,
) -> tuple[bytes | None, str | None]:
    """Download an object from Supabase Storage.

    Returns (data_bytes, content_type) on success, (None, None) if the object
    is missing (404), and raises an exception on other errors.
    """
    import requests

    base_url = supabase_url.rstrip("/")
    url = f"{base_url}/storage/v1/object/audio_files/{storage_path}"
    headers = supabase_headers(service_role_key)

    if verbose:
        info(f"GET {url}")

    resp = requests.get(url, headers=headers, timeout=120, stream=True)

    if resp.status_code == 404:
        return None, None

    if resp.status_code != 200:
        raise RuntimeError(
            f"Supabase Storage returned HTTP {resp.status_code}: {resp.text[:200]}"
        )

    content_type = resp.headers.get("Content-Type", "audio/mpeg")
    data = resp.content
    return data, content_type


# ---------------------------------------------------------------------------
# R2 (boto3) helpers
# ---------------------------------------------------------------------------

def make_r2_client(account_id: str, access_key_id: str, secret_access_key: str):
    """Create a boto3 S3 client pointed at Cloudflare R2."""
    import boto3
    from botocore.config import Config

    endpoint_url = f"https://{account_id}.r2.cloudflarestorage.com"

    client = boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        aws_access_key_id=access_key_id,
        aws_secret_access_key=secret_access_key,
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )
    return client


def object_exists_in_r2(r2_client, bucket: str, key: str, verbose: bool) -> bool:
    """Return True if the object already exists in R2 (HEAD request)."""
    from botocore.exceptions import ClientError

    try:
        r2_client.head_object(Bucket=bucket, Key=key)
        return True
    except ClientError as exc:
        error_code = exc.response["Error"]["Code"]
        # R2 may return '404' or 'NoSuchKey' for missing objects
        if error_code in ("404", "NoSuchKey"):
            return False
        # Any other error (auth, network, etc.) is unexpected
        raise


def upload_to_r2(
    r2_client,
    bucket: str,
    key: str,
    data: bytes,
    content_type: str,
    verbose: bool,
) -> None:
    """Upload bytes to R2 with the given key and Content-Type."""
    r2_client.put_object(
        Bucket=bucket,
        Key=key,
        Body=data,
        ContentType=content_type,
    )


# ---------------------------------------------------------------------------
# Main backfill loop
# ---------------------------------------------------------------------------

def run_backfill(args: argparse.Namespace) -> int:
    """Execute the backfill. Returns exit code (0 = success, 1 = errors)."""

    config = resolve_config()

    supabase_url       = config["SUPABASE_URL"]
    service_role_key   = config["SUPABASE_SERVICE_ROLE_KEY"]
    r2_account_id      = config["R2_ACCOUNT_ID"]
    r2_bucket          = config["R2_BUCKET_NAME"]
    r2_access_key_id   = config["R2_ACCESS_KEY_ID"]
    r2_secret_key      = config["R2_SECRET_ACCESS_KEY"]

    print()
    print(f"{Color.BOLD}Repertoire Coach — Supabase → R2 audio backfill{Color.RESET}")
    print(f"  Supabase URL : {supabase_url}")
    print(f"  R2 bucket    : {r2_bucket}")
    if args.dry_run:
        print(f"  {Color.YELLOW}DRY RUN — no objects will be copied{Color.RESET}")
    print()

    # Fetch all storage paths from the database
    storage_paths = fetch_tracks(
        supabase_url, service_role_key, args.limit, args.verbose
    )

    if not storage_paths:
        ok("No tracks to process. Nothing to do.")
        return 0

    total = len(storage_paths)
    print()

    # Build R2 client (unless dry-run, where we still build it to verify credentials)
    step("Connecting to Cloudflare R2…")
    r2 = make_r2_client(r2_account_id, r2_access_key_id, r2_secret_key)
    ok("R2 client ready")
    print()

    # --- Counters ---
    n_copied  = 0
    n_skipped = 0  # already in R2
    n_missing = 0  # 404 in Supabase Storage
    n_errors  = 0

    for i, storage_path in enumerate(storage_paths, start=1):
        prefix = f"[{i}/{total}]"

        try:
            # ------------------------------------------------------------------
            # 1. Check R2 — skip if already present (idempotent)
            # ------------------------------------------------------------------
            if not args.dry_run:
                exists = object_exists_in_r2(r2, r2_bucket, storage_path, args.verbose)
            else:
                exists = False  # dry-run: always pretend it needs copying

            if exists:
                print(
                    f"{Color.CYAN}{prefix}{Color.RESET} "
                    f"SKIP {storage_path} (already in R2)"
                )
                n_skipped += 1
                continue

            # ------------------------------------------------------------------
            # 2. Download from Supabase Storage
            # ------------------------------------------------------------------
            print(
                f"{Color.CYAN}{prefix}{Color.RESET} COPY {storage_path}",
                end="",
                flush=True,
            )

            if args.dry_run:
                # Dry-run: just show what would happen without downloading
                print(f"  {Color.YELLOW}→ (dry-run, skipping){Color.RESET}")
                n_copied += 1  # count as "would copy"
                continue

            data, content_type = download_from_supabase(
                supabase_url, service_role_key, storage_path, args.verbose
            )

            if data is None:
                # 404 from Supabase — object referenced in DB but not in storage
                print()
                print(
                    f"  {Color.YELLOW}→ WARNING: object not found in Supabase Storage "
                    f"(404){Color.RESET}"
                )
                n_missing += 1
                continue

            # ------------------------------------------------------------------
            # 3. Upload to R2
            # ------------------------------------------------------------------
            upload_to_r2(r2, r2_bucket, storage_path, data, content_type, args.verbose)

            size_kb = len(data) / 1024
            print(
                f"  {Color.GREEN}✓{Color.RESET} "
                f"{len(data):,} bytes → R2"
            )
            n_copied += 1

            # Brief pause to avoid hammering Supabase Storage rate limits
            time.sleep(0.1)

        except KeyboardInterrupt:
            print()
            fail("Interrupted by user")
            break

        except Exception as exc:
            print()
            fail(f"Error processing {storage_path}: {exc}")
            n_errors += 1
            if args.verbose:
                import traceback
                traceback.print_exc()

    # ---------------------------------------------------------------------------
    # Summary
    # ---------------------------------------------------------------------------
    print()
    print(f"{Color.BOLD}{'=' * 50}{Color.RESET}")
    print(f"{Color.BOLD}Backfill summary{Color.RESET}")
    print(f"{'=' * 50}")

    if args.dry_run:
        print(f"  {Color.YELLOW}DRY RUN — nothing was actually copied{Color.RESET}")
        print(f"  Would copy : {n_copied}")
    else:
        print(f"  Copied     : {Color.GREEN}{n_copied}{Color.RESET}")

    print(f"  Skipped    : {n_skipped}  (already in R2)")

    if n_missing:
        print(
            f"  Missing    : {Color.YELLOW}{n_missing}{Color.RESET}"
            f"  (storage_path in DB but object absent from Supabase Storage)"
        )
    else:
        print(f"  Missing    : {n_missing}")

    if n_errors:
        print(f"  Errors     : {Color.RED}{n_errors}{Color.RESET}")
        print()
        fail("Backfill completed with errors. Re-run to retry failed objects.")
    else:
        print()
        ok("Backfill completed successfully.")

    return 1 if n_errors else 0


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Copy all audio objects from Supabase Storage to Cloudflare R2.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                   # Backfill all tracks
  %(prog)s --dry-run         # Show what would be copied without doing it
  %(prog)s --limit 10        # Process only the first 10 tracks
  %(prog)s --verbose         # Show HTTP request details

Required .env variables (add to project root .env):
  SUPABASE_SERVICE_ROLE_KEY
  R2_ACCOUNT_ID
  R2_BUCKET_NAME
  R2_ACCESS_KEY_ID
  R2_SECRET_ACCESS_KEY
        """,
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Plan the backfill without downloading or uploading anything.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        metavar="N",
        help="Process at most N tracks (useful for testing).",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Print HTTP request details and stack traces on errors.",
    )

    args = parser.parse_args()

    if args.limit is not None and args.limit <= 0:
        fail("--limit must be a positive integer")
        return 2

    try:
        return run_backfill(args)
    except KeyboardInterrupt:
        print()
        fail("Interrupted")
        return 1


if __name__ == "__main__":
    sys.exit(main())

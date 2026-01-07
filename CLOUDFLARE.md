# Deploying to Cloudflare Pages

This guide covers deploying the Repertoire Coach web app to Cloudflare Pages.

## Prerequisites

1. A Cloudflare account (free tier works)
2. Your repository on GitHub
3. Supabase project URL and anonymous key

## Deployment Methods

There are two ways to deploy to Cloudflare Pages:
1. **Git-based deployment** (recommended) - Cloudflare builds and deploys automatically from GitHub
2. **Direct upload** - Build locally and upload via Wrangler CLI

Choose the method that matches what you're seeing in the Cloudflare dashboard.

---

## Method 1: Git-Based Deployment (Recommended)

### 1. Prepare Your Repository

Make sure all changes are committed and pushed to GitHub:

```bash
git add .
git commit -m "Prepare for Cloudflare Pages deployment"
git push
```

### 2. Create Cloudflare Pages Project

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to **Pages** in the left sidebar
3. Click **Create a project**
4. Click **Connect to Git**
5. Authorize Cloudflare to access your GitHub account
6. Select your repository: `repertoire-coach`

### 3. Configure Build Settings

On the build configuration page, enter:

**Build configurations:**
- **Framework preset**: None (or select "Flutter" if available)
- **Build command**: `chmod +x scripts/build-web-cloudflare.sh && scripts/build-web-cloudflare.sh`
- **Build output directory**: `build/web`
- **Root directory**: (leave blank)

> **Note**: If Cloudflare Pages shows different fields (like "Deploy command"), you may be using a different deployment method. The standard Pages deployment should show these three fields.

**Environment variables** (click "Add variable"):
- `SUPABASE_URL`: Your Supabase project URL (e.g., `https://xxxxx.supabase.co`)
- `SUPABASE_ANON_KEY`: Your Supabase anonymous/public key

> **Important**: Get these values from your Supabase project dashboard:
> - Go to Settings > API
> - Copy "Project URL" and "anon/public" key

### 3b. Configure Supabase Authentication Redirects

After deployment, you need to configure Supabase to redirect to your production URL:

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to **Authentication** → **URL Configuration**
4. Configure the following:

**Site URL**: Set to your Cloudflare Pages URL
```
https://your-app.pages.dev
```

**Redirect URLs**: Add these patterns (click "Add URL" for each):
```
https://your-app.pages.dev/**
http://localhost:8080/**
http://localhost:3000/**
```

> **Why this matters**: Without these settings, password reset emails and OAuth redirects will fail or redirect to localhost. The `/**` wildcard allows all routes under your domain.

**If you add a custom domain later**, remember to add it to the redirect URLs too.

### 4. Deploy

1. Click **Save and Deploy**
2. Cloudflare will:
   - Clone your repository
   - Install Flutter
   - Build your web app with Supabase credentials
   - Deploy to their global CDN

The first build takes 5-10 minutes. Subsequent builds are faster.

### 5. Access Your Site

Once deployed, Cloudflare provides:
- A `*.pages.dev` URL (e.g., `repertoire-coach.pages.dev`)
- Automatic HTTPS
- Global CDN distribution
- Preview deployments for pull requests

### 6. Custom Domain (Optional)

To use your own domain:

1. In your Cloudflare Pages project, go to **Custom domains**
2. Click **Set up a custom domain**
3. Enter your domain name
4. Follow DNS configuration instructions

## Local Testing

To build and test the production web build locally:

```bash
# Build the web app
./scripts/build-web.sh

# Serve locally (requires Python)
cd build/web
python3 -m http.server 8000

# Open http://localhost:8000 in your browser
```

## Updating Your Site

Cloudflare Pages automatically rebuilds and deploys when you push to your repository:

```bash
git add .
git commit -m "Update feature X"
git push
```

Cloudflare will:
- Detect the push
- Build the new version
- Deploy to production (on `main` branch)
- Or create a preview deployment (on other branches)

## Important Notes

### WASM Files

The web build requires specific WASM files for Drift database support:
- `web/sqlite3.wasm` - Must match `sqlite3` package version in `pubspec.yaml`
- `web/drift_worker.dart.js` - Must match `drift` package version

These files are committed to the repository and will be included in the build.

**If you update these packages**, you must update the WASM files:
1. Check `pubspec.yaml` for exact versions
2. Download matching files from GitHub releases
3. See `CLAUDE.md` for detailed version matching instructions

### Environment Variables Security

- The `SUPABASE_ANON_KEY` is public and safe to embed in the web build
- It's called "anon" because it's meant to be publicly accessible
- Row Level Security (RLS) policies in Supabase protect your data
- Never use the "service_role" key in the web app

### Build Output

The build process:
1. Runs `flutter pub get` to install dependencies
2. Runs `flutter build web --release` with Supabase credentials
3. Outputs to `build/web/` directory
4. Cloudflare serves everything in `build/web/` directory

### Headers and Redirects

The web app is a Single Page Application (SPA). Cloudflare Pages automatically handles:
- Proper MIME types for all files
- CORS headers if needed
- SPA routing (all routes serve `index.html`)

If you need custom headers or redirects, create:
- `public/_headers` - Custom HTTP headers
- `public/_redirects` - URL redirects and rewrites

These files will be copied to the build output.

## Troubleshooting

### Build Fails in Cloudflare

**Check build logs** in Cloudflare Pages dashboard:
1. Go to your project
2. Click on the failed deployment
3. View logs to see the error

**Common issues:**
- Missing environment variables: Add `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- Script not executable: Run `chmod +x scripts/build-web-cloudflare.sh` and commit
- Build timeout: Contact Cloudflare support (rare)

### App Loads But Can't Connect to Supabase

**Check environment variables:**
1. Go to Cloudflare Pages > Settings > Environment variables
2. Verify `SUPABASE_URL` and `SUPABASE_ANON_KEY` are correct
3. Re-deploy if you change them

**Check browser console:**
- Open DevTools (F12)
- Look for errors in Console tab
- Check Network tab for failed requests

### WASM Errors

If you see errors like:
- `LinkError: Import #18 'dart' 'dispatch_xFunc': function import requires a callable`
- `Using WasmStorageImplementation` but blank page

**Solution**: WASM file version mismatch
1. Check package versions in `pubspec.yaml`
2. Download matching WASM files (see CLAUDE.md)
3. Commit and push updated files
4. Cloudflare will rebuild automatically

## Monitoring

Cloudflare Pages provides:
- **Analytics**: Page views, bandwidth, requests
- **Deployment history**: See all builds and rollback if needed
- **Build logs**: Debug build failures
- **Real-time updates**: Deploy status notifications

Access these in your Cloudflare Pages project dashboard.

## Rollback

To rollback to a previous version:
1. Go to Cloudflare Pages > Deployments
2. Find the deployment you want to rollback to
3. Click **Rollback to this deployment**

Or via Git:
```bash
git revert <commit-hash>
git push
```

## Cost

Cloudflare Pages free tier includes:
- Unlimited bandwidth
- Unlimited requests
- 500 builds per month
- 1 build at a time

This is more than enough for most projects.

---

## Method 2: Direct Upload via Wrangler CLI

If you prefer to build locally and upload directly:

### 1. Install Wrangler

```bash
npm install -g wrangler
```

### 2. Login to Cloudflare

```bash
wrangler login
```

### 3. Build Locally

```bash
./scripts/build-web.sh
```

### 4. Deploy to Cloudflare Pages

```bash
wrangler pages deploy build/web --project-name=repertoire-coach
```

### 5. Configure Supabase Redirects

After your first deployment, configure Supabase authentication:

1. Note your Cloudflare Pages URL (shown after deployment)
2. Go to [Supabase Dashboard](https://supabase.com/dashboard) → Your Project
3. Navigate to **Authentication** → **URL Configuration**
4. Set **Site URL**: `https://your-app.pages.dev`
5. Add **Redirect URLs**:
   - `https://your-app.pages.dev/**`
   - `http://localhost:8080/**`
   - `http://localhost:3000/**`

This ensures password resets and OAuth work correctly.

### 6. Subsequent Deploys

Just run:
```bash
./scripts/build-web.sh && wrangler pages deploy build/web --project-name=repertoire-coach
```

**Advantages:**
- Faster builds (uses your local machine)
- More control over the build process
- No need to set up CI/CD
- Simpler initial setup

**Disadvantages:**
- Manual deployment (not automatic on git push)
- Requires Wrangler CLI installed

---

## Next Steps

After deploying:
1. Test your app at the `*.pages.dev` URL
2. Set up a custom domain if desired
3. Enable Cloudflare Analytics for insights
4. Configure branch preview deployments for testing

## Resources

- [Cloudflare Pages Documentation](https://developers.cloudflare.com/pages/)
- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)
- [Supabase Client Libraries](https://supabase.com/docs/reference/dart/introduction)

# Docker Setup Guide

This project includes Docker configurations for both building Flutter apps and self-hosting Supabase.

## Flutter Build Container

Use `Dockerfile.build` to build Flutter apps in a consistent, containerized environment.

### Prerequisites
- Docker installed
- Project files ready

### Building the Container

Build the image once (or when Flutter/Android SDK versions change):

```bash
docker build -f Dockerfile.build -t repertoire-coach-builder .
```

### Usage Examples

**Build Android APK:**
```bash
docker run --rm -v $(pwd):/app repertoire-coach-builder flutter build apk --release
```

**Build Android App Bundle (for Play Store):**
```bash
docker run --rm -v $(pwd):/app repertoire-coach-builder flutter build appbundle --release
```

**Build Web App:**
```bash
docker run --rm -v $(pwd):/app repertoire-coach-builder flutter build web --release
```

**Get Dependencies:**
```bash
docker run --rm -v $(pwd):/app repertoire-coach-builder flutter pub get
```

**Run Tests:**
```bash
docker run --rm -v $(pwd):/app repertoire-coach-builder flutter test
```

**Run Flutter Analyze:**
```bash
docker run --rm -v $(pwd):/app repertoire-coach-builder flutter analyze
```

### Note on iOS Builds
iOS builds require macOS and Xcode, which cannot run in Docker. For iOS builds:
- Build on a Mac with Xcode installed
- Use a CI/CD service with macOS runners (GitHub Actions, Codemagic, etc.)

## Supabase Self-Hosting

Use `docker-compose.supabase.yml` to run your own Supabase instance.

### Prerequisites
- Docker and Docker Compose installed
- At least 2GB RAM available
- Ports 3000, 5432, 8000 available

### Setup

1. **Copy environment file:**
   ```bash
   cp .env.supabase.example .env
   ```

2. **Generate secrets:**
   ```bash
   # Generate JWT secret (at least 32 characters)
   openssl rand -base64 32
   ```

3. **Generate API keys:**

   Visit https://supabase.com/docs/guides/self-hosting/docker#generate-api-keys

   Or use this JWT generator with your JWT_SECRET:
   - Anon key: `{"role": "anon", "iss": "supabase"}`
   - Service role key: `{"role": "service_role", "iss": "supabase"}`

4. **Update `.env` file** with your generated secrets

5. **Create Kong configuration:**
   ```bash
   mkdir -p supabase/config
   ```

   Download Kong config:
   ```bash
   curl -o supabase/config/kong.yml \
     https://raw.githubusercontent.com/supabase/supabase/master/docker/volumes/api/kong.yml
   ```

6. **Create database migrations directory:**
   ```bash
   mkdir -p supabase/migrations
   ```

   Copy the SQL schema from `ARCHITECTURE.md` into migration files.

### Starting Supabase

```bash
docker-compose -f docker-compose.supabase.yml up -d
```

### Accessing Services

- **Supabase Studio** (Admin UI): http://localhost:3000
- **API Gateway**: http://localhost:8000
- **PostgreSQL**: localhost:5432

### Initial Database Setup

1. Access Supabase Studio at http://localhost:3000
2. Go to SQL Editor
3. Run the database schema from `ARCHITECTURE.md`:
   - Create tables
   - Create indexes
   - Create triggers
   - Set up Row Level Security policies

Or run migrations:
```bash
# Create migration file
cat > supabase/migrations/001_initial_schema.sql << 'EOF'
-- Paste SQL schema from ARCHITECTURE.md here
EOF

# Restart db to apply migrations
docker-compose -f docker-compose.supabase.yml restart db
```

### Stopping Supabase

```bash
docker-compose -f docker-compose.supabase.yml down
```

### Removing All Data (Reset)

```bash
docker-compose -f docker-compose.supabase.yml down -v
```

**Warning:** This deletes all data including uploaded files and database records!

### Backing Up Database

```bash
docker exec choir-app-db pg_dump -U postgres postgres > backup.sql
```

### Restoring Database

```bash
cat backup.sql | docker exec -i choir-app-db psql -U postgres postgres
```

## Production Deployment

### Flutter App

For production builds:

1. **Android:**
   - Build signed app bundle
   - Upload to Google Play Console
   - Configure signing in `android/app/build.gradle`

2. **Web:**
   - Build: `docker run --rm -v $(pwd):/app repertoire-coach-builder flutter build web --release`
   - Deploy to: Vercel, Netlify, or static hosting
   - Serve from `build/web` directory

### Supabase

For production Supabase deployment:

1. **Option 1: Use Supabase Cloud**
   - Create project at https://supabase.com
   - More reliable, managed backups, auto-scaling
   - Pay-as-you-go pricing

2. **Option 2: Self-host on VPS**
   - Deploy to DigitalOcean, AWS, etc.
   - Configure SSL/TLS (use Caddy or nginx)
   - Set up automated backups
   - Configure firewall rules
   - Update `.env` with production URLs
   - Use strong passwords and rotate secrets

**Production checklist:**
- [ ] Use strong, unique passwords
- [ ] Enable SSL/TLS
- [ ] Configure SMTP for email
- [ ] Set up automated backups
- [ ] Configure monitoring
- [ ] Disable signup if invite-only
- [ ] Review and test RLS policies
- [ ] Set resource limits
- [ ] Configure CDN for storage

## Troubleshooting

### Flutter Build Issues

**Problem:** "Flutter SDK not found"
```bash
# Rebuild the image
docker build -f Dockerfile.build -t repertoire-coach-builder --no-cache .
```

**Problem:** Build artifacts not appearing
```bash
# Ensure volume mount is correct (use absolute path on Windows)
docker run --rm -v /absolute/path/to/project:/app repertoire-coach-builder flutter build apk --release
```

### Supabase Issues

**Problem:** "Connection refused" to database
```bash
# Check if database is healthy
docker-compose -f docker-compose.supabase.yml ps
docker-compose -f docker-compose.supabase.yml logs db
```

**Problem:** "Invalid JWT"
```bash
# Regenerate API keys using the same JWT_SECRET
# Make sure JWT_SECRET in .env matches what was used to generate keys
```

**Problem:** Storage uploads failing
```bash
# Check storage service logs
docker-compose -f docker-compose.supabase.yml logs storage

# Ensure storage directory has correct permissions
docker exec choir-app-storage ls -la /var/lib/storage
```

## Development Workflow

### Local Development

1. Use Supabase Cloud for development (free tier)
2. Or run local Supabase with docker-compose
3. Build Flutter app locally without Docker
4. Use Docker builds only for CI/CD

### CI/CD Pipeline

1. On push/PR: Run tests in Docker
2. On merge to main: Build release artifacts
3. Deploy web build to hosting
4. Upload Android build to Play Store (manual or automated)

## Additional Resources

- [Flutter Docker Guide](https://docs.flutter.dev/deployment/cd#docker)
- [Supabase Self-Hosting Docs](https://supabase.com/docs/guides/self-hosting)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

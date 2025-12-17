# Supabase Configuration Guide

This guide explains how to configure your Supabase project for Repertoire Coach.

## Table of Contents
- [Email Configuration](#email-configuration)
- [URL Configuration](#url-configuration)
- [Testing Password Recovery](#testing-password-recovery)

## Email Configuration

### Change Email Sender Name

By default, emails come from "Supabase Auth". To change it to "Repertoire Coach":

1. Go to your Supabase Dashboard
2. Navigate to **Authentication → Email Templates**
3. Find the **"Magic Link"** template
4. In the email editor, change the sender name from "Supabase Auth" to "Repertoire Coach"
5. Click **Save**

Repeat for other templates if needed:
- **Confirm signup**
- **Change Email Address**
- **Reset Password**

## URL Configuration

### The localhost:3000 Problem

When users click the password reset link in their email, Supabase redirects them to a URL. By default, this is `http://localhost:3000`, which doesn't work for mobile apps or your production environment.

### Solution: Configure Redirect URLs

1. Go to your Supabase Dashboard
2. Navigate to **Authentication → URL Configuration**

3. **Set Site URL**:
   - For development: `http://localhost:8080` (matches your web server)
   - For production: Your actual domain (e.g., `https://repertoire-coach.app`)

4. **Add Redirect URLs** to the allow list:
   ```
   http://localhost:8080/**
   http://localhost:3000/**
   https://your-production-domain.com/**
   ```

5. Click **Save**

### How It Works

After configuration:
1. User clicks "Forgot Password?" in the app
2. Enters email address
3. Receives email from "Repertoire Coach" (if configured)
4. Clicks reset link in email
5. **Supabase redirects to your configured Site URL**
6. App detects password recovery and shows ResetPasswordScreen
7. User enters new password
8. User can sign in

## Testing Password Recovery

### On Web (localhost:8080)

1. Run the web server:
   ```bash
   scripts/run-web.sh
   ```

2. Open http://localhost:8080 in your browser

3. Click **"Forgot Password?"**

4. Enter your email and click **"Send Reset Link"**

5. Check your email for the reset link

6. Click the link - it should redirect to `http://localhost:8080`

7. You should see the **Reset Password** screen

8. Enter your new password

9. Sign in with the new password

### On Android

For Android, password reset currently works best through the web flow:

1. **Option A: Use Web Browser**
   - User receives reset email
   - Opens link in mobile browser
   - Completes password reset in browser
   - Returns to app and signs in

2. **Option B: Configure Deep Linking** (Advanced)
   - Set up Android App Links
   - Configure `intentFilter` in `AndroidManifest.xml`
   - Add `assetlinks.json` to your domain
   - See [Android Deep Linking Setup](#android-deep-linking-setup) below

## Android Deep Linking Setup (Optional)

To make password reset links open directly in the Android app:

### Step 1: Add Intent Filter to AndroidManifest.xml

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<activity ...>
    <!-- Existing intent filters -->

    <!-- Deep link for password reset -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />

        <!-- Replace with your actual domain -->
        <data
            android:scheme="https"
            android:host="your-domain.com"
            android:pathPrefix="/auth" />
    </intent-filter>
</activity>
```

### Step 2: Configure Supabase Redirect URL

Set your Site URL to: `https://your-domain.com/auth`

Add to Redirect URLs allow list:
```
https://your-domain.com/auth/**
```

### Step 3: Deploy assetlinks.json

Create `.well-known/assetlinks.json` on your domain:

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.example.repertoire_coach",
    "sha256_cert_fingerprints": [
      "YOUR_APP_SIGNING_KEY_FINGERPRINT"
    ]
  }
}]
```

Get your fingerprint with:
```bash
keytool -list -v -keystore upload-keystore.jks
```

## Troubleshooting

### Email Not Arriving

- Check your email spam folder
- Verify email is confirmed in Supabase (Authentication → Users)
- Check Supabase logs (Authentication → Logs)

### Wrong Redirect URL

- Verify Site URL in Supabase Dashboard
- Check Redirect URLs allow list includes your URL
- Clear browser cache and try again

### Password Reset Link Expired

- Password reset links expire after 1 hour by default
- Request a new reset link
- To change expiration: Authentication → URL Configuration → Email Link Expiry

### App Shows Blank Screen

- Check browser console for errors
- Verify Supabase credentials are correct in `.env` file
- Try clearing browser local storage

## Production Checklist

Before deploying to production:

- [ ] Configure production Site URL
- [ ] Add production domain to Redirect URLs allow list
- [ ] Update email templates with production branding
- [ ] Set up custom SMTP (optional) for branded emails
- [ ] Test password reset flow end-to-end
- [ ] Set up Android App Links (if using mobile)
- [ ] Configure email rate limiting
- [ ] Set up monitoring for auth failures

## Additional Resources

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Android App Links Guide](https://developer.android.com/training/app-links)
- [Email Templates Customization](https://supabase.com/docs/guides/auth/auth-email-templates)

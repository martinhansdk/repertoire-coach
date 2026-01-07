# Supabase Storage Setup for Audio Files

## Quick Fix: Create the Audio Bucket

You're getting "404 bucket not found" because the Supabase Storage bucket hasn't been created yet.

### Option 1: Via Supabase Dashboard (Quickest)

1. Go to your Supabase project dashboard
2. Navigate to **Storage** in the left sidebar
3. Click **New Bucket**
4. Set the following:
   - **Name**: `audio`
   - **Public bucket**: ✅ **Yes** (checked)
   - Click **Create bucket**

5. Then set up policies:
   - Click on the `audio` bucket
   - Go to **Policies** tab
   - Click **New Policy**
   - Select **For full customization**
   - Add the following 4 policies (copy from below)

#### Policy 1: INSERT (Upload)
```sql
CREATE POLICY "Choir members can upload audio files"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'audio'
  AND (storage.foldername(name))[1] IN (
    SELECT choir_id::text
    FROM choir_members
    WHERE user_id = auth.uid()
  )
);
```

#### Policy 2: SELECT (Download/Read)
```sql
CREATE POLICY "Choir members can read audio files"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'audio'
  AND (storage.foldername(name))[1] IN (
    SELECT choir_id::text
    FROM choir_members
    WHERE user_id = auth.uid()
  )
);
```

#### Policy 3: UPDATE (Re-upload)
```sql
CREATE POLICY "Choir members can update audio files"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'audio'
  AND (storage.foldername(name))[1] IN (
    SELECT choir_id::text
    FROM choir_members
    WHERE user_id = auth.uid()
  )
);
```

#### Policy 4: DELETE
```sql
CREATE POLICY "Choir members can delete audio files"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'audio'
  AND (storage.foldername(name))[1] IN (
    SELECT choir_id::text
    FROM choir_members
    WHERE user_id = auth.uid()
  )
);
```

### Option 2: Via SQL Editor

1. Go to **SQL Editor** in Supabase dashboard
2. Run the migration file:

```bash
cat supabase/migrations/002_create_audio_storage_bucket.sql
```

Copy the entire contents and paste into SQL Editor, then click **Run**.

### Option 3: Via Supabase CLI (if using local development)

```bash
supabase db push
```

## How It Works

### Storage Structure
Audio files are organized by choir and track:
```
audio/
  {choir_id}/
    {track_id}.mp3
    {track_id}.m4a
    {track_id}.wav
```

### Security (RLS Policies)
- ✅ Users can only upload audio to choirs they're members of
- ✅ Users can only access audio from their choirs
- ✅ Files are stored in a public bucket (for CDN performance)
- ✅ But RLS ensures only authorized users can upload/access

### After Setup
Once the bucket is created, try uploading an audio file again in the app. It should work!

## Troubleshooting

**Still getting 404?**
- Make sure you're signed in (authenticated)
- Verify you're a member of at least one choir
- Check browser console for detailed error messages

**Permission denied?**
- Make sure all 4 policies are created
- Verify the policies are enabled
- Check that you're testing with a user who is a choir member

**Files not appearing?**
- Refresh the Storage bucket view in dashboard
- Check the `audio/{choir_id}/` folder

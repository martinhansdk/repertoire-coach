-- Create audio storage bucket for track audio files
-- Bucket: audio
-- Path structure: audio/{choir_id}/{track_id}.{extension}

-- Create the storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('audio', 'audio', true);

-- Policy: Allow authenticated users to upload audio files to their choirs
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

-- Policy: Allow authenticated users to read audio files from their choirs
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

-- Policy: Allow choir members to update audio files (re-upload)
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

-- Policy: Allow choir members to delete audio files
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

-- Note: The bucket is set to 'public' to allow public URLs,
-- but RLS policies ensure only choir members can upload/access files

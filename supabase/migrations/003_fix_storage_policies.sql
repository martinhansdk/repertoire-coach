-- Fix infinite recursion in audio_files storage policies
-- The issue: storage policies checking choir_members triggers RLS policies
-- Solution: Use a security definer function to bypass RLS

-- First, drop the existing problematic policies
DROP POLICY IF EXISTS "Choir members can upload audio files" ON storage.objects;
DROP POLICY IF EXISTS "Choir members can read audio files" ON storage.objects;
DROP POLICY IF EXISTS "Choir members can update audio files" ON storage.objects;
DROP POLICY IF EXISTS "Choir members can delete audio files" ON storage.objects;

-- Create a security definer function to check choir membership
-- This bypasses RLS and prevents infinite recursion
CREATE OR REPLACE FUNCTION public.is_choir_member(p_choir_id text, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM choir_members
    WHERE choir_id = p_choir_id::uuid
    AND user_id = p_user_id
  );
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.is_choir_member(text, uuid) TO authenticated;

-- Now create new storage policies using the security definer function
-- Policy: Allow authenticated users to upload audio files to their choirs
CREATE POLICY "Choir members can upload audio files"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'audio_files'
  AND public.is_choir_member((storage.foldername(name))[1], auth.uid())
);

-- Policy: Allow authenticated users to read audio files from their choirs
CREATE POLICY "Choir members can read audio files"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'audio_files'
  AND public.is_choir_member((storage.foldername(name))[1], auth.uid())
);

-- Policy: Allow choir members to update audio files (re-upload)
CREATE POLICY "Choir members can update audio files"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'audio_files'
  AND public.is_choir_member((storage.foldername(name))[1], auth.uid())
);

-- Policy: Allow choir members to delete audio files
CREATE POLICY "Choir members can delete audio files"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'audio_files'
  AND public.is_choir_member((storage.foldername(name))[1], auth.uid())
);

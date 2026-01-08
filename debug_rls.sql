-- Debug script for RLS and storage policies
-- Run this in Supabase SQL Editor to diagnose upload issues

-- 1. Check if is_choir_member function exists
SELECT
  proname as function_name,
  pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'is_choir_member';

-- 2. Check current authenticated user
SELECT auth.uid() as current_user_id;

-- 3. List all choirs the current user is a member of
SELECT
  cm.choir_id,
  c.name as choir_name,
  cm.user_id,
  cm.joined_at
FROM choir_members cm
JOIN choirs c ON c.id = cm.choir_id
WHERE cm.user_id = auth.uid()
  AND c.deleted = false;

-- 4. Test is_choir_member function
-- Replace 'YOUR_CHOIR_ID_HERE' with an actual choir ID from step 3
-- SELECT public.is_choir_member('YOUR_CHOIR_ID_HERE', auth.uid());

-- 5. Check storage policies on storage.objects
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'objects'
  AND schemaname = 'storage'
ORDER BY policyname;

-- 6. Check user_belongs_to_choir function (for choir_members policy)
SELECT
  proname as function_name,
  pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'user_belongs_to_choir';

-- 7. Check choir_members RLS policies
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'choir_members'
  AND schemaname = 'public'
ORDER BY policyname;

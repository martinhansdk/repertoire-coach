-- Fix infinite recursion in choir_members SELECT policy
-- The existing policy queries choir_members from within a choir_members policy
-- This causes infinite recursion when storage policies check choir membership
--
-- Original intent: Users can see all members of choirs they belong to
-- Problem: Querying choir_members from choir_members policy = infinite recursion
-- Solution: Use SECURITY DEFINER function to check membership without triggering RLS

-- Drop the problematic policy
DROP POLICY IF EXISTS "choir_members_select" ON public.choir_members;

-- Create a helper function that checks if a user belongs to a choir
-- This uses SECURITY DEFINER to bypass RLS and prevent recursion
CREATE OR REPLACE FUNCTION public.user_belongs_to_choir(p_choir_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result boolean;
BEGIN
  -- Check if user is a member of the specified choir
  -- SECURITY DEFINER runs with elevated privileges, bypassing RLS
  SELECT EXISTS (
    SELECT 1
    FROM public.choir_members
    WHERE choir_id = p_choir_id
    AND user_id = p_user_id
  ) INTO result;

  RETURN result;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.user_belongs_to_choir(uuid, uuid) TO authenticated;

-- Create new SELECT policy using the helper function
-- Users can see all members of choirs they belong to
CREATE POLICY "choir_members_select"
ON public.choir_members
FOR SELECT
USING (
  public.user_belongs_to_choir(choir_id, auth.uid())
);

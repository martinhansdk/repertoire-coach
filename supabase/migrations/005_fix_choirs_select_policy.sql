-- Update choirs SELECT policy to use SECURITY DEFINER function
-- This prevents potential recursion and improves performance
-- by using the same helper function as choir_members_select

-- Drop the existing policy
DROP POLICY IF EXISTS "choirs_select_member" ON public.choirs;

-- Recreate using the helper function
-- Users can read choirs they're members of
CREATE POLICY "choirs_select_member"
ON public.choirs
FOR SELECT
USING (
  public.user_belongs_to_choir(id, auth.uid())
);

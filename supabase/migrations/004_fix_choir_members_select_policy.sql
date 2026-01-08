-- Fix infinite recursion in choir_members SELECT policy
-- The existing policy queries choir_members from within a choir_members policy
-- This causes infinite recursion when storage policies check choir membership

-- Drop the problematic policy
DROP POLICY IF EXISTS "choir_members_select" ON public.choir_members;

-- Create a simple, non-recursive policy
-- Users can see choir_members rows where they are the member
-- This is sufficient for the app's needs and prevents recursion
CREATE POLICY "choir_members_select"
ON public.choir_members
FOR SELECT
USING (user_id = auth.uid());

-- Note: If you need users to see OTHER members of their choirs,
-- create a database view or API endpoint that uses SECURITY DEFINER
-- to bypass RLS, similar to the is_choir_member() function.

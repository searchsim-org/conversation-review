# Private answer backups

GitHub Pages hosts the annotation interface and public conversation records. It does not store answers. The Supabase database stores each reviewer's answers privately.

To enable backups:

1. Create a Supabase project and enable anonymous sign-ins in Authentication.
2. Run `setup.sql` once in its SQL editor.
3. Generate two random reviewer codes using the SQL comments. Store each code's hash in `audit_private.invites`, assigning A and B. Give each author only their own code. Do not put codes in GitHub.
4. Set the project URL and publishable key in `annotation_site/config.js`. Never use a secret or service-role key in the site.
5. Publish the site. Each author selects their assigned reviewer, starts the review, and connects private backup with their code.

Each code binds to one Supabase user. Only that user can read their answer record. Saves go through a database function that checks reviewer membership, case IDs, answer values, and the previous revision. A stale browser cannot silently replace a newer server copy. No conversation records, database facts, names, or reviewer codes are sent with progress saves.

The browser keeps answers immediately and sends a backup after a short pause. If server saving fails, browser saving continues and the page asks the author to reconnect or download. Clearing browser storage loses the anonymous login; an administrator must reassign access. Keep downloaded backups.

Before relying on remote backups, test two separate reviewer accounts: each must be unable to read the other's answers, redeem the other's used code, write directly to the table, or save with a stale revision. The live project passed these checks with two temporary reviewer accounts and a third account without reviewer access. Invalid case IDs and answer values were also rejected. The temporary accounts and synthetic answers were removed afterward.

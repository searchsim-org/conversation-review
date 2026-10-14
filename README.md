# Conversation review

Open the site and start a new review. It creates a unique reviewer ID and a private recovery code. No name, email address, or account is needed.

The same browser offers “Continue my review.” On another device, choose “Resume with a code.” Keep the recovery code private: it grants access to that review's answers. Copy it or download it before starting.

Each review covers 188 tasks and two conversations per task. Task order and conversation order are randomized for each ID and remain stable when resuming. Answers save immediately in the browser and automatically to the private Supabase database. Failed server saves leave the browser copy intact; stale sessions cannot overwrite a newer server copy.

The public site shows conversation records and restaurant facts, with no prefilled judgments or simulator identities. Only `annotation_site` is published through GitHub Pages. Answers, session tokens, and recovery codes must never be committed.

The old A/B pages remain available for exporting existing work. Start a unique review and import your own exported file. The new site asks for confirmation before importing a legacy A/B file.

See `annotation_backend/unique-reviewers.sql` for the unique-ID database setup. Existing A/B records remain unchanged.

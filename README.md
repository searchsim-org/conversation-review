# Conversation review

Two authors independently review 188 user tasks, with two conversations per task. The public site shows the conversation records and restaurant facts. It contains no prefilled judgments or simulator identities.

Open the site, select your assigned reviewer, and start annotation. Answers save automatically in that browser. Download a backup whenever you pause. To continue from the offline files, download their labels and import them on the site.

Private server backups use Supabase and a separate code for each reviewer. The browser ID remembers the local session; it is not an access credential. See `annotation_backend/README.md` for server setup and the checks required before relying on backups.

Only `annotation_site` is published through GitHub Pages. Annotation answers and private reviewer codes must never be committed.

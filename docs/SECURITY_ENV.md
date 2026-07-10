# Security — Environment Secrets

## What happened
`backend/.env` was committed to this **public** repository. It has been
untracked (`git rm --cached backend/.env`) so it will no longer be committed,
and `.gitignore` already ignores `.env` / `*.env`.

**Untracking does NOT remove the secrets from git history.** Because the repo is
public, every value that was ever in `backend/.env` must be treated as
compromised and rotated.

## Required: rotate every exposed secret
Regenerate/replace these in their respective dashboards, then update your local
`backend/.env` (never commit it):

- [ ] `DATABASE_URL` — change the Postgres role password
- [ ] `JWT_SECRET` and `JWT_REFRESH_SECRET` — set new random values
      (rotating these invalidates existing tokens — expected)
- [ ] `PAYSTACK_SECRET_KEY` (+ public key) — roll keys in the Paystack dashboard
- [ ] `FIREBASE_PRIVATE_KEY` / service account — generate a new service account
      key in Firebase console and revoke the old one
- [ ] `CLOUDINARY_API_KEY` / `CLOUDINARY_API_SECRET` — regenerate in Cloudinary

Generate strong secrets locally, e.g.:
```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

## Recommended: scrub git history
Rotation is the priority. Optionally also purge the file from history so the old
values aren't served from the public repo. This **rewrites history** and needs a
force-push plus re-clones by any collaborators — coordinate before doing it:

```bash
# with git-filter-repo (preferred)
git filter-repo --path backend/.env --invert-paths
# or BFG:  bfg --delete-files .env
git push --force --all
```

## Going forward
- Keep real values only in the local, git-ignored `backend/.env`.
- `backend/.env.example` documents the required keys with placeholder values.
- Deployment platforms should inject env vars via their own secret stores.

# Deploying the MacroVault PWA (personal use)

The app to host is the **`web_preview/`** folder (static files: `index.html`,
`manifest.webmanifest`, `sw.js`, icons). No build step.

## Option A — GitHub + Cloudflare Pages (auto-deploys on every change) ✅ recommended

**You do (once):**
1. Create an empty repo at <https://github.com/new> (e.g. `macrovault`, private). Don't add a README.
2. Tell Claude the repo URL (or run the push yourself — commands below).
3. At <https://dash.cloudflare.com> → **Workers & Pages → Create → Pages → Connect to Git** → pick the repo, then set:
   - **Framework preset:** None
   - **Build command:** *(leave empty)*
   - **Build output directory:** `web_preview`
   - Save & Deploy.

**Push commands** (Claude runs these once the repo exists, or you can):
```bash
cd ~/Projects/macrovault
git remote add origin https://github.com/<you>/macrovault.git
git branch -M main
git push -u origin main
```

After that: every `git push` → Cloudflare rebuilds → your installed app updates. No re-signing, ever.

## Option B — One command, no GitHub (manual re-deploy each change)

```bash
cd ~/Projects/macrovault
npx wrangler pages deploy web_preview --project-name macrovault
```
First run opens a browser to log into your Cloudflare account. Re-run the same command to push updates.

## Put it on your phone
Open the deployed URL in **Safari** → Share → **Add to Home Screen**. Done — permanent icon, full screen, offline-capable.

# 🚀 End-to-End Deployment Automation

**Status:** ✅ FULLY AUTOMATED  
**Trigger:** `git push` to `main` branch  
**Time to Live:** ~5 minutes (build + deploy + health check)

---

## How It Works

### Pipeline Overview

```
Code Push (main) 
    ↓
GitHub Actions Triggered
    ↓
docker-push.yml (2-3 min)
    ├─ Checkout code
    ├─ Build Docker image
    ├─ Push to GHCR (ghcr.io/fractional-pm/creative-platform-api)
    └─ ✅ Complete
    ↓
deploy.yml (2-3 min) [AUTOMATIC]
    ├─ SSH into VPS
    ├─ Git pull latest code
    ├─ docker-compose build
    ├─ docker-compose up -d
    ├─ Wait 30 seconds
    ├─ Run health check
    └─ ✅ LIVE at http://agennext.com:3001/health
```

**Total Time:** ~5 minutes from `git push` to production deployment  
**Zero Manual Steps Required** ✨

---

## Setup Required (One Time Only)

### Step 1: Add GitHub Secret for VPS Password

Go to: https://github.com/fractional-pm/creative-platform/settings/secrets/actions

Click **New repository secret** and add:

```
Name:  VPS_PASSWORD
Value: [your VPS password for almalinux user]
```

This secret is used only by the deploy workflow to SSH into the VPS.

### Step 2: Verify Workflows Are Enabled

Go to: https://github.com/fractional-pm/creative-platform/actions

Ensure both workflows are enabled:
- ✅ `Build and Push Docker Image to GHCR`
- ✅ `Auto Deploy to VPS`

### Step 3: That's It! 🎉

Deployment automation is now active.

---

## Using Automated Deployment

### To Deploy New Code

Simply push to main:

```bash
git add .
git commit -m "your message"
git push origin main
```

**That's all.** The rest is automatic.

### Watch Deployment Progress

1. **GitHub Actions Dashboard:**
   - https://github.com/fractional-pm/creative-platform/actions
   - See real-time logs for both workflows

2. **Build Status:**
   - Shows when Docker image is building
   - Shows when image is pushed to GHCR

3. **Deploy Status:**
   - Shows SSH connection to VPS
   - Shows docker-compose build/up
   - Shows health check result

---

## What Gets Automated

### ✅ On Every Push to Main

1. **docker-push.yml triggers automatically:**
   - Checks out latest code
   - Builds optimized Docker image
   - Pushes to GHCR with tags: `latest`, `main`, `sha-<commit-hash>`

2. **deploy.yml triggers automatically after build:**
   - Waits for GHCR push to complete
   - SSHs into `almalinux@agennext.com`
   - Pulls latest code from GitHub
   - Rebuilds Docker image
   - Restarts services with docker-compose
   - Waits 30 seconds for stabilization
   - Runs health check on API
   - Reports success/failure

---

## Monitoring & Verification

### Health Check

After deployment completes, check:

```bash
curl http://agennext.com:3001/health
```

Expected response:
```json
{
  "status": "OK",
  "timestamp": "2026-06-25T12:34:56Z"
}
```

### Service Status

Check all services:

```bash
ssh almalinux@agennext.com 'cd ~/creative-platform && docker-compose ps'
```

Expected output: All services running (STATUS: `Up`)

### Logs

Stream API logs in real-time:

```bash
ssh almalinux@agennext.com 'cd ~/creative-platform && docker-compose logs -f api'
```

Stream deployment logs:

```bash
# GitHub Actions logs
https://github.com/fractional-pm/creative-platform/actions
# Click on latest workflow run → deploy job
```

### Endpoints After Deployment

- **Health Check:** http://agennext.com:3001/health
- **API Base:** http://agennext.com:3001/api/v1/
- **Grafana Dashboard:** http://agennext.com:3000
- **Prometheus Metrics:** http://agennext.com:9090

---

## Deployment Triggers

Deployment only runs when **BOTH** conditions are met:

1. **Branch:** Push is to `main` branch
2. **Files Changed:** Changes in:
   - `src/api/**` (API code)
   - `db/**` (database files)
   - `docker-compose.yml`
   - `deploy/**` (deployment config)
   - `.github/workflows/deploy.yml`

This means:
- ✅ Push to `src/api/main.go` → Deploy
- ✅ Push to `db/schema.sql` → Deploy
- ✅ Push to `docker-compose.yml` → Deploy
- ❌ Push to `.gitignore` only → Skip (no deploy needed)
- ❌ Push to README.md only → Skip (no deploy needed)

---

## What Runs on VPS During Deployment

The deploy workflow executes on the VPS:

```bash
cd ~/creative-platform

# 1. Update code
git pull origin main

# 2. Build API image
docker-compose build --no-cache api

# 3. Start services
docker-compose -f docker-compose.yml -f deploy/docker-compose.production.yml up -d

# 4. Wait for services to stabilize
sleep 30

# 5. Run health check
curl http://localhost:3001/health

# 6. Display results
docker-compose ps
```

If health check fails, deployment stops with error message and logs.

---

## Rollback (If Needed)

If a deployment fails or you need to rollback:

```bash
ssh almalinux@agennext.com

cd ~/creative-platform

# View recent commits
git log --oneline -5

# Checkout previous version
git checkout <previous-commit-sha>

# Rebuild and restart
docker-compose down
docker-compose build --no-cache api
docker-compose -f docker-compose.yml -f deploy/docker-compose.production.yml up -d

# Verify
curl http://localhost:3001/health
```

---

## Troubleshooting

### Deployment Failed - What to Check

1. **Check GitHub Actions logs:**
   - https://github.com/fractional-pm/creative-platform/actions
   - Click failed workflow
   - Scroll to "Deploy to VPS via SSH" step
   - Read error message

2. **Check VPS Status:**
   ```bash
   ssh almalinux@agennext.com 'cd ~/creative-platform && docker-compose ps'
   ```

3. **Check VPS Logs:**
   ```bash
   ssh almalinux@agennext.com 'cd ~/creative-platform && docker-compose logs api --tail=50'
   ```

### Common Issues

**Issue:** `SSH authentication failed`
- **Solution:** Verify `VPS_PASSWORD` secret is set in GitHub
- Check VPS accepts SSH password auth (not key-only)

**Issue:** `Health check failed`
- **Solution:** Check API logs: `docker-compose logs api`
- Verify database is running: `docker-compose ps postgres`
- Check environment variables in `.env.production`

**Issue:** `docker-compose command not found`
- **Solution:** SSH into VPS and verify: `docker-compose version`
- May need to reinstall: Run `deploy/setup-vps.sh`

---

## Preventing Accidental Deployments

### Strategy 1: Use Feature Branches

```bash
# Create feature branch
git checkout -b feature/my-change

# Make changes and push
git push origin feature/my-change

# Deploy only when ready (via PR → main)
# Create PR, get reviewed, merge to main
# → Automatic deployment triggers
```

### Strategy 2: Environment Checks

Edit `.github/workflows/deploy.yml` to add manual approval:

```yaml
deploy:
  runs-on: ubuntu-latest
  environment: production  # Requires manual approval
  steps:
    # ... rest of steps
```

Then configure at: https://github.com/fractional-pm/creative-platform/settings/environments

---

## Disabling Automation (If Needed)

### Temporarily Disable Deploy Workflow

1. Go to: https://github.com/fractional-pm/creative-platform/actions
2. Click "Auto Deploy to VPS"
3. Click "..." → "Disable workflow"
4. Re-enable when ready

### Temporarily Disable Docker Push Workflow

1. Go to: https://github.com/fractional-pm/creative-platform/actions
2. Click "Build and Push Docker Image to GHCR"
3. Click "..." → "Disable workflow"
4. Re-enable when ready

---

## Performance Metrics

| Stage | Time | Details |
|-------|------|---------|
| Checkout | ~10s | Clone repo |
| Docker Build | 60-90s | Compile Go API |
| GHCR Push | 30-60s | Upload image |
| VPS SSH | ~5s | Connect to VPS |
| VPS Git Pull | ~2s | Update code |
| VPS Docker Build | 30-60s | Rebuild on VPS |
| Services Startup | 30s | Wait for stabilization |
| Health Check | ~1s | Test /health endpoint |
| **Total** | **~5-6 min** | **End-to-end** |

---

## Cost Considerations

### GitHub Actions

- **Free tier:** 2,000 minutes/month
- **This workflow:** ~6 minutes per deployment
- **Capacity:** ~330 deployments/month on free tier

### VPS Deployment

- No additional cost (runs on existing VPS)
- Docker Compose pulls image from GHCR during build

---

## Next Steps

1. ✅ Set `VPS_PASSWORD` secret in GitHub
2. ✅ Verify both workflows are enabled
3. ✅ Make a test commit and push to main
4. ✅ Watch deployment in GitHub Actions
5. ✅ Verify API is live at http://agennext.com:3001/health

---

## 🎉 You're Done!

**Your deployment pipeline is now fully automated.**

From this point forward:
- Push code to main
- Wait 5 minutes
- API is live in production

No manual SSH, no manual docker-compose, no manual steps. Everything is automatic.

---

**Questions?** Check GitHub Actions logs for detailed error messages and deployment status.

**Last Updated:** 2026-06-25  
**Status:** ✅ PRODUCTION READY

# GitHub Authentication Setup

To push OpenAutonomyX to GitHub, you need to authenticate. Choose one method:

## Method 1: GitHub Personal Access Token (Recommended for HTTPS)

### Step 1: Create GitHub Token
1. Go to: https://github.com/settings/tokens/new
2. Login to your GitHub account
3. Select **Tokens (classic)** in the left menu
4. Click **Generate new token (classic)**
5. Give it a name: `openautonomyx-push`
6. Select scope: **repo** (full control of private repositories)
7. Click **Generate token**
8. **Copy the token** (starts with `ghp_`) - you'll only see it once!

### Step 2: Store Credentials
```bash
# Navigate to the repo
cd /Users/chinmaypanda/CustomApps

# Set up git to store credentials
git config --global credential.helper store

# Push (will prompt for username/password)
git push -u origin main

# When prompted:
# Username: <your GitHub username>
# Password: <paste the token you copied>

# The credentials will be saved for future pushes
```

### Step 3: Verify
```bash
# Check that the credentials are stored
cat ~/.git-credentials

# This file should contain:
# https://<username>:<token>@github.com

# Test the push
git push
# Should succeed without prompting
```

---

## Method 2: SSH Key Setup (More Secure)

### Step 1: Generate SSH Key
```bash
# Generate a new SSH key
ssh-keygen -t ed25519 -C "thefractionalpm@gmail.com"

# When prompted:
# Enter file: press Enter (default ~/.ssh/id_ed25519)
# Enter passphrase: (optional, can skip by pressing Enter)
# Confirm passphrase: (same as above)
```

### Step 2: Add Key to GitHub
1. Copy your public key:
```bash
cat ~/.ssh/id_ed25519.pub
```

2. Go to: https://github.com/settings/ssh/new
3. Paste the public key
4. Give it a title: `openautonomyx-laptop`
5. Click **Add SSH key**

### Step 3: Update Remote URL
```bash
# Change from HTTPS to SSH
git remote set-url origin git@github.com:openautonomyx/openautonomyx.git

# Verify the change
git remote -v

# Should show:
# origin  git@github.com:openautonomyx/openautonomyx.git (fetch)
# origin  git@github.com:openautonomyx/openautonomyx.git (push)
```

### Step 4: Push
```bash
git push -u origin main
```

---

## Method 3: Using gh CLI (Easiest)

### Step 1: Install GitHub CLI
```bash
# macOS
brew install gh

# Or download from https://github.com/cli/cli/releases
```

### Step 2: Authenticate
```bash
gh auth login

# Follow the prompts:
# - GitHub.com or GitHub Enterprise: GitHub.com
# - Protocol: HTTPS
# - Authenticate: Paste an authentication token or choose to login in browser
```

### Step 3: Push
```bash
git push -u origin main

# GitHub CLI handles authentication automatically
```

---

## Verify Deployment

Once pushed, verify your repository is live:

```bash
# Check if repository exists and is public
curl -s https://api.github.com/repos/openautonomyx/openautonomyx | grep '"private"'
# Should return: "private": false

# Check if GitHub Pages is live
curl -I https://openautonomyx.github.io

# Check if commits are visible
open https://github.com/openautonomyx/openautonomyx

# Check if docs are deployed
open https://openautonomyx.github.io
```

---

## Troubleshooting

### "fatal: could not read Username for 'https://github.com'"
→ Use SSH (Method 2) or gh CLI (Method 3)

### "Permission denied (publickey)"
→ Ensure SSH key is added to GitHub (https://github.com/settings/ssh)

### "fatal: remote origin already exists"
→ Remote is already configured, just push:
```bash
git push -u origin main
```

### Token keeps getting rejected
→ Make sure you're using the full token (not just the first few chars)
→ Check for trailing spaces when pasting

### Want to revoke a token?
→ Go to https://github.com/settings/tokens and click **Delete**

---

## Quick Commands

```bash
# View current authentication method
git remote -v

# Change to SSH
git remote set-url origin git@github.com:openautonomyx/openautonomyx.git

# Change to HTTPS
git remote set-url origin https://github.com/openautonomyx/openautonomyx.git

# Push all commits
git push -u origin main

# Check push status
git status

# View remote branches
git branch -r
```

---

**After authentication, your platform will be live at:**
- 🌐 **GitHub Repository:** https://github.com/openautonomyx/openautonomyx
- 📖 **Documentation/Marketing:** https://openautonomyx.github.io
- 📦 **NPM Package:** https://www.npmjs.com/package/openautonomyx (after `npm publish`)

**Questions?** See [DEPLOYMENT.md](DEPLOYMENT.md) for full deployment guide.

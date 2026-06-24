# 🌐 Domain Binding & DNS Configuration Guide

**Complete guide for binding agennext.com domain to VPS deployment**

---

## 📋 Quick Reference

| Record Type | Name | Value | TTL | Purpose |
|-------------|------|-------|-----|---------|
| **A** | agennext.com | YOUR_VPS_IP | 3600 | Root domain → VPS |
| **A** | www | YOUR_VPS_IP | 3600 | www subdomain → VPS |
| **CNAME** | api | agennext.com | 3600 | API subdomain (optional) |
| **CNAME** | admin | agennext.com | 3600 | Admin panel (optional) |
| **MX** | @ | mail.agennext.com | 3600 | Email routing (if needed) |
| **TXT** | @ | v=spf1 ... | 3600 | SPF record (if needed) |
| **TXT** | _acme-challenge | (auto by certbot) | 60 | SSL certificate verification |

---

## 🚀 Step-by-Step Domain Binding

### Step 1: Get Your VPS IP Address

```bash
# SSH into VPS
ssh almalinux@agennext.com

# Get the public IP
curl -s https://api.ipify.org
# Output: 192.0.2.123 (example)

# Or from within VPS
hostname -I
# Output: 10.0.0.5 192.0.2.123 (internal and public)

# Save this IP for DNS records
export VPS_IP="192.0.2.123"
```

### Step 2: Access Your Domain Registrar

Common registrars:
- **Godaddy** (godaddy.com)
- **Namecheap** (namecheap.com)
- **Route53** (AWS)
- **Cloudflare** (cloudflare.com)
- **Google Domains** (domains.google.com)
- **Bluehost** (bluehost.com)

**Login and navigate to:**
```
DNS Settings → Manage DNS Records → DNS Zone
```

### Step 3: Configure DNS Records

#### A Record (Root Domain)
```
Name: agennext.com (or @ depending on UI)
Type: A
Value: 192.0.2.123 (your VPS IP)
TTL: 3600 (1 hour)
Priority: N/A

✅ This makes agennext.com point to your VPS
```

#### A Record (www Subdomain)
```
Name: www
Type: A
Value: 192.0.2.123 (your VPS IP)
TTL: 3600
Priority: N/A

✅ This makes www.agennext.com point to your VPS
```

#### CNAME Records (Optional Subdomains)
```
# API subdomain
Name: api
Type: CNAME
Value: agennext.com
TTL: 3600

# Admin subdomain
Name: admin
Type: CNAME
Value: agennext.com
TTL: 3600

# Dashboard
Name: dashboard
Type: CNAME
Value: agennext.com
TTL: 3600
```

#### TXT Records (Email - Optional)
```
# SPF record (if sending emails)
Name: @ (or agennext.com)
Type: TXT
Value: v=spf1 include:sendgrid.net ~all
TTL: 3600

# DKIM record (if using SendGrid)
Name: sendgrid._domainkey
Type: CNAME
Value: sendgrid.net
TTL: 3600

# DMARC record
Name: _dmarc
Type: TXT
Value: v=DMARC1; p=quarantine; rua=mailto:admin@agennext.com
TTL: 3600
```

### Step 4: Wait for DNS Propagation

```bash
# DNS changes take 15 min - 48 hours to propagate
# Check propagation status

# Method 1: Online tool
# Visit: https://www.whatsmydns.net/?q=agennext.com

# Method 2: Using nslookup
nslookup agennext.com
# Should resolve to: 192.0.2.123

# Method 3: Using dig
dig agennext.com +short
# Output: 192.0.2.123

# Method 4: Using host
host agennext.com
# Output: agennext.com has address 192.0.2.123

# Monitor propagation
watch -n 5 "dig agennext.com +short"
# Runs every 5 seconds until it resolves
```

### Step 5: Verify Domain Resolution

```bash
# Test from your local machine
ping agennext.com
# Output: PING agennext.com (192.0.2.123) 56(84) bytes of data

# Test HTTPS connection
curl -I https://agennext.com
# Should return 200 OK with valid certificate

# Test www subdomain
curl -I https://www.agennext.com
# Should also work (redirects to main domain)

# Verify all subdomains
curl -I https://api.agennext.com
curl -I https://admin.agennext.com
curl -I https://dashboard.agennext.com
```

---

## 🔐 SSL Certificate with cert-manager

### Automatic HTTPS Setup

Once domain is bound:

```bash
# 1. SSH into VPS
ssh almalinux@agennext.com

# 2. Request certificate (if not done by deployment script)
sudo certbot certonly --nginx \
  -d agennext.com \
  -d www.agennext.com \
  -d api.agennext.com \
  -d admin.agennext.com \
  --email admin@agennext.com \
  --non-interactive \
  --agree-tos

# 3. Verify certificate
openssl x509 -enddate -noout -in /etc/letsencrypt/live/agennext.com/fullchain.pem
# Output: notAfter=Jun 24 12:34:56 2027 GMT

# 4. Nginx automatically uses certificate
sudo systemctl reload nginx

# 5. Test HTTPS
curl -I https://agennext.com
# Should return: HTTP/2 200 with valid cert
```

### Certificate Renewal (Automatic)

```bash
# Systemd timer handles renewal automatically
systemctl status certbot-renew.timer
# Should show: active (running)

# View renewal schedule
systemctl list-timers certbot-renew.timer

# Manual renewal (if needed)
sudo certbot renew --verbose

# Dry run (test without actual renewal)
sudo certbot renew --dry-run
```

---

## 🛠️ Advanced DNS Configuration

### Using Cloudflare (Recommended)

Cloudflare provides:
- ✅ Free DNS hosting
- ✅ DDoS protection
- ✅ SSL/TLS termination
- ✅ Caching
- ✅ Analytics

**Setup:**
```bash
# 1. Create Cloudflare account
# https://dash.cloudflare.com/

# 2. Add site
# Click "Add a site"
# Enter: agennext.com

# 3. Update domain's nameservers
# At your registrar, change nameservers to:
# nameserver1.cloudflare.com
# nameserver2.cloudflare.com
# (Check Cloudflare for exact values)

# 4. Add DNS records in Cloudflare dashboard
# Same A/CNAME records as above
# Cloudflare UI is more user-friendly

# 5. Enable SSL
# Cloudflare → SSL/TLS → Full (Strict)
# This ensures HTTPS between Cloudflare and your origin
```

### Using AWS Route53

```bash
# 1. Create hosted zone
aws route53 create-hosted-zone \
  --name agennext.com \
  --caller-reference "$(date +%s)"

# 2. Get nameservers
aws route53 get-hosted-zone --id ZONE_ID

# 3. Update registrar with AWS nameservers

# 4. Create A record
aws route53 change-resource-record-sets \
  --hosted-zone-id ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "agennext.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "192.0.2.123"}]
      }
    }]
  }'

# 5. Create www CNAME
aws route53 change-resource-record-sets \
  --hosted-zone-id ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "www.agennext.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "192.0.2.123"}]
      }
    }]
  }'
```

### Using Google Domains

```
1. Go to Google Domains console
2. Click agennext.com
3. Left sidebar → DNS → Custom Records
4. Add A record: agennext.com → YOUR_VPS_IP
5. Add A record: www → YOUR_VPS_IP
6. TTL: 3600
7. Click "Create DNS record"
8. Wait 15 minutes to 2 hours for propagation
```

---

## 🔍 DNS Troubleshooting

### Domain Not Resolving

```bash
# Check DNS propagation
# Global checker: https://www.whatsmydns.net/?q=agennext.com

# Check from different nameservers
nslookup agennext.com 8.8.8.8    # Google DNS
nslookup agennext.com 1.1.1.1    # Cloudflare DNS
nslookup agennext.com 208.67.222.222  # OpenDNS

# Clear local DNS cache
# macOS:
sudo dscacheutil -flushcache

# Linux:
sudo systemctl restart systemd-resolved

# Windows:
ipconfig /flushdns

# Try again after cache clear
ping agennext.com
```

### HTTPS Certificate Error

```bash
# If getting certificate error:

# 1. Check certificate is installed
ls -la /etc/letsencrypt/live/agennext.com/

# 2. Verify Nginx is using certificate
sudo grep ssl_certificate /etc/nginx/conf.d/creative-platform.conf

# 3. Test certificate validity
openssl s_client -connect agennext.com:443 -showcerts

# 4. Reload Nginx
sudo systemctl reload nginx

# 5. Clear browser cache and retry
# Use incognito/private window to bypass cache
```

### API Not Accessible

```bash
# Test each layer

# 1. DNS resolution
dig agennext.com
# Should return your VPS IP

# 2. Network connectivity
ping agennext.com
# Should get replies

# 3. HTTP connectivity
curl -v http://agennext.com
# Should connect (might redirect to HTTPS)

# 4. HTTPS connectivity
curl -v https://agennext.com
# Should return 200 OK

# 5. API endpoint
curl https://agennext.com/api/v1/health
# Should return health status JSON

# 6. Check firewall
sudo firewall-cmd --list-all
# Verify ports 80, 443 are open

# 7. Check Nginx is running
sudo systemctl status nginx
# Should show: active (running)

# 8. Check API is running
docker ps | grep api
# Should show: creative-platform-api running

# 9. Check logs
docker logs -f api
# Look for startup errors
```

### Subdomains Not Working

```bash
# For api.agennext.com

# 1. Verify DNS record
dig api.agennext.com
# Should resolve to same IP as main domain

# 2. Test connectivity
curl -I https://api.agennext.com
# Should return 200

# 3. Check Nginx config includes subdomain
grep -A5 "server_name" /etc/nginx/conf.d/creative-platform.conf
# Should include: api.agennext.com

# 4. If using CNAME, verify CNAME record
dig api.agennext.com CNAME
# Should show: api.agennext.com CNAME agennext.com

# 5. Reload Nginx
sudo systemctl reload nginx
```

---

## 📊 DNS Monitoring

### Check DNS Health

```bash
# Monitor DNS response times
dig agennext.com +stats
# Output includes: Query time: 45 msec

# Check all DNS records
dig agennext.com ANY
# Shows all records for domain

# Check specific record type
dig agennext.com A        # A record
dig agennext.com CNAME    # CNAME records
dig agennext.com MX       # Mail records
dig agennext.com TXT      # TXT records
dig agennext.com NS       # Nameserver records

# Monitor DNS propagation to multiple servers
for ns in 8.8.8.8 1.1.1.1 208.67.222.222; do
  echo "=== $ns ==="
  dig @$ns agennext.com +short
done
```

### Set Up Monitoring

```yaml
# Prometheus config for DNS monitoring
scrape_configs:
  - job_name: 'dns'
    static_configs:
      - targets: ['agennext.com']
    metric_path: '/probe'
    params:
      module: [dns_tcp]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: localhost:9115
```

---

## 🔄 DNS Update Procedure

### When Moving to New VPS

```bash
# 1. Get new VPS IP
NEW_IP="203.0.113.42"

# 2. Update DNS A records
# At your registrar:
# agennext.com A record: OLD_IP → NEW_IP
# www.agennext.com A record: OLD_IP → NEW_IP

# 3. TTL strategy (optional)
# Lower TTL to 60 seconds BEFORE migration
# This speeds up propagation
# Restore to 3600 after migration

# 4. Monitor propagation
watch -n 5 "dig agennext.com +short"
# Wait until all servers return NEW_IP

# 5. Verify old server still works (during transition)
# Some clients might still hit old IP due to caching

# 6. After propagation complete (2-24h)
# Keep both servers running for 24 hours
# Then decommission old server
```

---

## 📋 DNS Configuration Checklist

### Basic Setup
- [ ] Got VPS IP address
- [ ] Logged into domain registrar
- [ ] Created A record for root domain
- [ ] Created A record for www subdomain
- [ ] DNS propagated (test with `dig`)
- [ ] Domain resolves to VPS IP
- [ ] Can ping domain
- [ ] Can curl domain (HTTP)
- [ ] Can curl domain (HTTPS)

### SSL/TLS
- [ ] Certificate requested with certbot
- [ ] Certificate installed in /etc/letsencrypt/
- [ ] Nginx configured for HTTPS
- [ ] HTTP redirects to HTTPS
- [ ] HSTS header enabled
- [ ] Certificate auto-renewal working
- [ ] Cert expiry alert set

### Subdomains
- [ ] api subdomain resolves
- [ ] admin subdomain resolves
- [ ] dashboard subdomain resolves
- [ ] All subdomains have HTTPS

### Email (Optional)
- [ ] MX record configured (if email needed)
- [ ] SPF record configured
- [ ] DKIM record configured
- [ ] DMARC record configured
- [ ] Email delivery working

### Monitoring
- [ ] DNS health check running
- [ ] Certificate expiry alerts set
- [ ] DNS query latency monitored
- [ ] DNS propagation monitored

---

## 🚀 Complete Deployment with Domain Binding

```bash
# 1. Deploy platform to VPS (includes cert-manager setup)
VPS_PASSWORD='your-password' bash deploy/deploy-to-vps.sh
# ✅ Services running
# ✅ API listening on :3001
# ✅ Nginx configured (waiting for domain)
# ✅ Certbot ready

# 2. Get VPS IP
SSH_RESULT=$(ssh almalinux@agennext.com "curl -s https://api.ipify.org")
echo "VPS IP: $SSH_RESULT"

# 3. Add DNS records at your registrar
# agennext.com A → $SSH_RESULT
# www A → $SSH_RESULT
# Wait 15 minutes for propagation

# 4. Verify domain resolution
dig agennext.com +short
# Should return your VPS IP

# 5. Request SSL certificate
ssh almalinux@agennext.com << 'EOF'
sudo certbot certonly --nginx \
  -d agennext.com \
  -d www.agennext.com \
  --email admin@agennext.com \
  --non-interactive \
  --agree-tos

sudo systemctl reload nginx
EOF

# 6. Test everything
curl -I https://agennext.com
# HTTP/2 200 with valid certificate

curl https://agennext.com/api/v1/health
# Should return health status

# 7. Mark deployment complete
echo "✅ Platform live at https://agennext.com"
```

---

## 📞 Support & Resources

- **Registrar Support**
  - Godaddy: support.godaddy.com
  - Namecheap: namecheap.com/support
  - Route53: docs.aws.amazon.com/route53
  - Cloudflare: support.cloudflare.com

- **DNS Tools**
  - DNS Propagation Checker: whatsmydns.net
  - DNS Lookup: mxtoolbox.com
  - Certificate Checker: sslshopper.com
  - SSL Test: ssllabs.com/ssltest

- **Certbot Documentation**
  - Official: certbot.eff.org/docs
  - Nginx plugin: certbot.eff.org/docs/using.html#nginx

---

**Status:** ✅ **DOMAIN BINDING READY**

**Follow steps above to bind agennext.com to your VPS!**

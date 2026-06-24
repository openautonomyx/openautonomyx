# 🔐 SSL/TLS & PII Protection Guide

**Comprehensive guide for managing SSL certificates and protecting personally identifiable information**

---

## 📋 Quick Summary

| Component | Provider | Status |
|-----------|----------|--------|
| **SSL/TLS Certificates** | cert-manager + Let's Encrypt | Automatic ✅ |
| **Certificate Renewal** | Certbot (systemd timer) | 30 days before expiry ✅ |
| **Private Key Storage** | OpenBao Vault | AES-256-GCM encrypted ✅ |
| **PII Encryption** | Vault + Database RLS | Field-level encryption ✅ |
| **PII Audit Logging** | Cortex + Loki | All access logged ✅ |
| **GDPR Compliance** | Auto-purge + Consent | 30-day retention ✅ |
| **CCPA Compliance** | User rights + Export | Data portability ✅ |

---

## 🔒 SSL/TLS Management with cert-manager

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet Client                          │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTPS (TLS 1.2/1.3)
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                      Nginx                                  │
│        (Reverse Proxy with SSL Termination)                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ SSL Certificate: /etc/letsencrypt/...               │  │
│  │ Private Key: /etc/letsencrypt/... (root-only)       │  │
│  │ Renewal: systemd timer (automatic)                  │  │
│  │ Protocols: TLSv1.2, TLSv1.3                         │  │
│  │ Ciphers: ECDHE-RSA/ECDSA, AES-256-GCM              │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTP (internal, docker network)
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                    API Services                             │
│  ┌────────────┐  ┌────────────┐  ┌────────────────────┐   │
│  │   Go API   │  │  Liferay   │  │   Grafana/Prom    │   │
│  │  :3001     │  │   :8080    │  │    :3000/:9090    │   │
│  └────────────┘  └────────────┘  └────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Certificate Lifecycle

```
Day 1          Day 45         Day 60         Day 90
 ├──────────────┼──────────────┼──────────────┤
 │              │              │              │
 Certificate    Start Renewal  Renewal       Expiry
 Created        Attempts       Success
                (30 days before)
                
✅ All automatic via cert-manager + certbot + systemd timer
```

### Setup Process

```bash
# 1. cert-manager installed during VPS deployment (deploy-to-vps.sh Step 2b)
# Includes:
# - certbot package
# - certbot-nginx plugin
# - systemd timer configuration

# 2. Automatic renewal enabled
systemctl status certbot-renew.timer
# → Timer runs daily, checks for renewal need
# → Renews if cert expires within 30 days

# 3. Certificate location
/etc/letsencrypt/live/agennext.com/
├─ fullchain.pem     (certificate + chain)
├─ privkey.pem       (private key, 600 permissions)
├─ cert.pem          (certificate only)
└─ chain.pem         (CA chain)

# 4. Nginx references cert-manager certs
# In /etc/nginx/conf.d/creative-platform.conf:
ssl_certificate /etc/letsencrypt/live/agennext.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/agennext.com/privkey.pem;
```

### Manual Operations

#### Check Certificate Status
```bash
# SSH into VPS
ssh almalinux@agennext.com

# View certificate details
openssl x509 -enddate -noout -in /etc/letsencrypt/live/agennext.com/fullchain.pem
# Output: notAfter=Jun 24 12:34:56 2027 GMT (example)

# Full certificate info
openssl x509 -text -noout -in /etc/letsencrypt/live/agennext.com/fullchain.pem

# Check private key
sudo ls -la /etc/letsencrypt/live/agennext.com/privkey.pem
# Should show: -rw-r----- 1 root root (600 permissions)

# Test certificate chain
openssl s_client -connect localhost:443 -showcerts
```

#### Manual Renewal (If Needed)
```bash
# Dry run (no actual renewal)
sudo certbot renew --dry-run

# Force renewal
sudo certbot renew --force-renewal

# Renewal without testing
sudo certbot renew

# After renewal, Nginx reloads automatically
sudo systemctl reload nginx
```

#### Troubleshooting

```bash
# View renewal attempts
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# Check timer status
systemctl status certbot-renew.timer
systemctl list-timers

# View timer logs
journalctl -u certbot-renew.timer -n 50

# Manually trigger renewal timer
sudo systemctl start certbot-renew.timer

# Test renewal with certbot
sudo certbot --nginx -d agennext.com --dry-run
```

### Security Best Practices

1. **Private Key Protection**
   ```bash
   # Verify permissions (should be 600, owner root)
   ls -la /etc/letsencrypt/live/agennext.com/privkey.pem
   
   # Restrict to root only
   sudo chmod 600 /etc/letsencrypt/live/agennext.com/privkey.pem
   sudo chown root:root /etc/letsencrypt/live/agennext.com/privkey.pem
   ```

2. **Certificate Backup**
   ```bash
   # Backup all certificates
   sudo tar -czf /root/letsencrypt-backup-$(date +%Y%m%d).tar.gz /etc/letsencrypt/
   
   # Move to secure location (off-server)
   # Use OpenBao to store encrypted backups
   ```

3. **Monitoring**
   ```bash
   # Alert on certificate expiry
   # Add to Prometheus/Grafana
   probe_ssl_earliest_cert_expiry{instance="agennext.com"} - time() < 86400 * 7
   # Alerts when < 7 days to expiry
   ```

---

## 🛡️ PII Protection with Vault

### Overview

**PII (Personally Identifiable Information)** includes:
- Email addresses
- Phone numbers
- Social Security Numbers (SSN)
- Credit card numbers
- Physical addresses
- IP addresses
- User agents
- Health information
- Financial data

### Three-Layer Protection

#### Layer 1: Storage Encryption
```go
// All PII encrypted at rest
type UserRecord struct {
    ID       UUID
    Email    string  // Encrypted: AES-256-GCM
    Phone    string  // Encrypted: AES-256-GCM
    SSN      string  // Encrypted: AES-256-GCM
    Created  time.Time
}

// Encryption happens in database layer
// Key stored in OpenBao (not in code/env)
```

#### Layer 2: Field Masking
```
Display representation (UI/logs):
- Email: user@**** or u***@example.com
- SSN: ***-**-1234
- Card: ****-****-****-4321
- Phone: ***-***-7890
- Address: City, State ****
- IP: 192.168.***.***
- User Agent: Mozilla/**** (masked)
```

#### Layer 3: Access Control
```hcl
# OpenBao policy for PII access
path "secret/data/pii/*" {
  capabilities = ["read"]
  # Only authenticated, authorized users
  # All access logged to audit trail
}
```

### Database-Level Protection

#### PostgreSQL Row-Level Security (RLS)
```sql
-- Only return records user has permission to access
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_isolation ON users
USING (user_id = current_user_id());

-- This ensures even SQL queries can't bypass access control
```

#### Field-Level Encryption
```sql
-- Store encrypted values
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email_encrypted bytea,  -- Encrypted in DB
    phone_encrypted bytea,  -- Encrypted in DB
    ssn_encrypted bytea,    -- Encrypted in DB
    created_at TIMESTAMP
);

-- Decryption key from OpenBao (on-demand only)
-- Never store plaintext in database
```

### Audit Logging

#### All PII Access Logged
```json
{
  "timestamp": "2026-06-25T14:23:45.123Z",
  "action": "read",
  "resource": "users:email",
  "user_id": "user-abc-123",
  "result": "success",
  "ip_address": "192.168.1.1",
  "reason": "customer_support_request"
}
```

#### Logging Configuration
```bash
# View PII access audit log
boas audit list secret/pii/

# Search for specific user's access
journalctl -u openbao | grep user-abc-123

# Export audit trail for compliance
boas audit list -format=json secret/ > audit-export.json
```

### Data Retention & Purging

#### Automatic Deletion
```yaml
# Configuration in OpenBao
pii_retention_days: 30  # Auto-delete after 30 days

# What gets deleted:
# - Inactive user accounts (after 30 days of no login)
# - Temporary PII (like session tokens)
# - Abandoned shopping carts
# - Failed transaction records

# What's kept (with reason):
# - Active user profiles (needed for service)
# - Transaction history (legal requirement)
# - Audit logs (compliance requirement)
```

#### Manual Purging
```bash
# Manually delete user's PII (GDPR/CCPA request)
boas kv delete secret/pii/users/user-abc-123

# Verify deletion
boas kv list secret/pii/users/
# Should NOT show user-abc-123

# Document deletion for compliance
echo "Deleted: user-abc-123 at $(date)" >> compliance/deletions.log
```

### GDPR Compliance

#### Article 17: Right to be Forgotten
```bash
# User can request all data be deleted
# Implementation:
1. Delete from primary database
2. Delete from backups (if newer than 30 days)
3. Log deletion for audit trail
4. Notify user of completion

# Automated process
DELETE FROM users WHERE id = 'user-abc-123' AND request_type = 'gdpr_deletion';
DELETE FROM audit_logs WHERE user_id = 'user-abc-123' AND created_at < now() - interval '30 days';
```

#### Article 20: Right to Data Portability
```bash
# Export all user's data in machine-readable format
curl -X GET https://api.creative-platform.com/api/v1/users/me/export \
  -H "Authorization: Bearer $JWT_TOKEN"

# Response: JSON file with all user data
# Can be imported to another platform
```

#### Article 13: Transparency
```bash
# Privacy Policy must include:
✅ What data collected
✅ Why (legal basis)
✅ Who has access
✅ How long retained
✅ User rights (access, deletion, portability)
✅ Complaint process
✅ Data processor info
```

### CCPA Compliance

#### California Rights
```
1. Right to Know (Article 1)
   - User can request what data collected
   - GET /api/v1/users/me/ccpa/data

2. Right to Delete (Article 2)
   - User can request deletion
   - DELETE /api/v1/users/me/ccpa/delete

3. Right to Opt-Out (Article 3)
   - User can opt-out of sale
   - PUT /api/v1/users/me/ccpa/opt-out

4. Right to Non-Discrimination (Article 4)
   - Can't charge more for exercising rights
   - Must provide equal service
```

#### Implementation
```javascript
// User controls on dashboard
<button onClick={downloadData}>
  Download My Data (CCPA)
</button>

<button onClick={deleteAccount}>
  Delete My Account (CCPA)
</button>

<input type="checkbox" onChange={toggleOptOut}>
  Opt-out of Data Sale
</input>
```

---

## 🔑 OpenBao Configuration for Credentials

### PII Protection Policy
```bash
# Stored in OpenBao
boas kv get secret/pii/protection

# Output:
encryption_enabled: true
encryption_algorithm: AES-256-GCM
field_masking: true
audit_logging: true
retention_days: 30
anonymization: true
pii_fields: email,phone,ssn,credit_card,address,ip_address,user_agent
gdpr_compliant: true
ccpa_compliant: true
```

### cert-manager Configuration
```bash
# Stored in OpenBao
boas kv get secret/ssl/certmanager

# Output:
domain: agennext.com
issuer: letsencrypt-prod
email: admin@agennext.com
provider: cert-manager
renewal_enabled: true
renewal_days_before: 30
```

---

## 📊 Monitoring & Alerts

### Certificate Expiry
```yaml
# Prometheus alert rule
alert: SSLCertificateExpiring
expr: probe_ssl_earliest_cert_expiry - time() < 604800  # 7 days
for: 1h
annotations:
  summary: "SSL certificate for {{ $labels.instance }} expiring in < 7 days"
  action: "Manual renewal or check cert-manager"
```

### PII Access Anomalies
```yaml
# Alert on unusual PII access patterns
alert: UnusualPIIAccess
expr: rate(pii_access_total[5m]) > 100
annotations:
  summary: "Unusual PII access detected"
  action: "Review audit logs for potential breach"
```

### Encryption Status
```bash
# Check encryption is working
curl https://api.creative-platform.com/api/v1/security/status
# Response:
{
  "encryption": "enabled",
  "tls_version": "1.3",
  "certificate_valid_until": "2027-06-24",
  "pii_protection": "active"
}
```

---

## 🚀 Deployment with cert-manager & PII Protection

### Initial Setup
```bash
# 1. Deploy to VPS (includes cert-manager setup)
VPS_PASSWORD='your-password' bash deploy/deploy-to-vps.sh

# 2. Setup OpenBao (includes PII protection)
BOAS_TOKEN='root-token' bash deploy/openbao-setup.sh

# 3. Verify everything
source ~/.openbao/deploy-token
curl https://agennext.com/health  # Should work with SSL
boas kv get secret/pii/protection  # Should show policies
```

### Daily Operations
```bash
# Check certificate status
openssl x509 -enddate -noout -in /etc/letsencrypt/live/agennext.com/fullchain.pem

# View PII access audit
journalctl -u openbao -n 100 | grep "pii"

# Monitor renewal process
systemctl status certbot-renew.timer
journalctl -u certbot-renew.timer -n 10
```

---

## ⚠️ Common Issues & Solutions

### Issue: Certificate renewal failing

```bash
# Check certbot logs
sudo tail -50 /var/log/letsencrypt/letsencrypt.log

# Verify ACME challenge can reach your domain
curl -I http://agennext.com/.well-known/acme-challenge/test

# Check firewall
sudo firewall-cmd --list-all

# Ensure port 80 is open for renewal
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload

# Test renewal
sudo certbot renew --dry-run --verbose
```

### Issue: PII decryption failures

```bash
# Verify OpenBao is accessible
boas status

# Check encryption key is present
boas kv get secret/database/encryption-key

# Verify database connection
docker exec postgres psql -U postgres -c '\l'

# Test PII field decryption
curl https://api.creative-platform.com/api/v1/debug/pii-status \
  -H "Authorization: Bearer $JWT_TOKEN"
```

### Issue: PII not masked in logs

```bash
# Verify masking policy is active
boas kv get secret/pii/protection | grep field_masking

# Check application is using masking
grep -r "maskPII" src/

# Verify Loki pipeline has masking
grep -A5 "regex.*pii" docker-compose.yml

# Restart logging
docker restart loki promtail
```

---

## 📝 Compliance Checklist

### Before Production

- [ ] Certificate installed and loading without errors
- [ ] HTTPS redirect working (HTTP → HTTPS)
- [ ] HSTS header present in responses
- [ ] Certificate valid for all domains
- [ ] Private key file has 600 permissions
- [ ] OpenBao PII protection policies configured
- [ ] Encryption enabled for all PII fields
- [ ] Audit logging working
- [ ] Auto-purge scheduled (30 days)
- [ ] GDPR privacy policy published
- [ ] CCPA privacy policy published
- [ ] Data deletion process implemented
- [ ] Data export process implemented
- [ ] Terms of Service updated
- [ ] Cookie consent banner added (if applicable)
- [ ] Penetration testing completed
- [ ] Security review of RLS policies
- [ ] Backup of encryption keys stored securely

### Monthly

- [ ] Certificate expiry check (should be automatic)
- [ ] Review PII access audit logs
- [ ] Verify auto-purge is working
- [ ] Test manual renewal process
- [ ] Check for failed renewal attempts
- [ ] Review security headers
- [ ] Scan for vulnerabilities (OWASP)
- [ ] Update SSL/TLS configuration if needed

### Quarterly

- [ ] Full security audit
- [ ] Penetration testing
- [ ] Compliance review (GDPR/CCPA)
- [ ] Disaster recovery test
- [ ] Key rotation (if applicable)
- [ ] Update documentation

---

## 📚 Additional Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Manual](https://certbot.eff.org/docs/using.html)
- [GDPR Compliance Guide](https://gdpr-info.eu/)
- [CCPA Consumer Rights](https://www.oag.ca.gov/privacy/ccpa)
- [OpenBao Documentation](https://openbao.org/docs/)
- [OWASP PII Protection](https://owasp.org/www-community/vulnerabilities/Sensitive_Data_Exposure)

---

**Status:** ✅ **SSL/TLS & PII PROTECTION READY**

**All credentials and PII secured with cert-manager + vault!**

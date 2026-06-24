# 🎯 Customer Onboarding Flow (Liferay-Native)

**Complete onboarding from signup → first approval workflow**

**Architecture:** Liferay manages multi-tenancy, our API orchestrates workflows

---

## 🏗️ Onboarding Architecture

```
┌──────────────────────────────────────────────────────────┐
│         Customer Signs Up (External Website)             │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ↓
┌──────────────────────────────────────────────────────────┐
│     Liferay DXP (Multi-Tenant Management)                │
├──────────────────────────────────────────────────────────┤
│ • Create new Site/Organization                          │
│ • Set up users and roles                                │
│ • Configure permissions                                 │
│ • Create content structure                              │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ↓
┌──────────────────────────────────────────────────────────┐
│    Your Go API (Onboarding Service)                      │
├──────────────────────────────────────────────────────────┤
│ • Verify Liferay setup                                  │
│ • Create tenant record                                  │
│ • Initialize approval workflows                         │
│ • Set up webhooks                                       │
│ • Send welcome email                                    │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ↓
┌──────────────────────────────────────────────────────────┐
│   Orkes Workflows (Setup automation)                     │
├──────────────────────────────────────────────────────────┤
│ • Create approval workflow for tenant                    │
│ • Invite initial reviewers                              │
│ • Schedule onboarding email sequence                     │
│ • Set up monitoring                                     │
└────────────────┬─────────────────────────────────────────┘
                 │
                 ↓
┌──────────────────────────────────────────────────────────┐
│   Tenant is Ready (Customer can start creating content)  │
└──────────────────────────────────────────────────────────┘
```

---

## 📝 Detailed Onboarding Steps

### Step 1: Customer Registration

**Where:** External website / signup form  
**What happens:**

```bash
POST /signup
{
  "company_name": "Acme Corp",
  "email": "admin@acme.com",
  "plan": "professional",
  "industry": "media",
  "expected_users": 50,
  "contact_name": "John Doe",
  "phone": "+1-555-0123"
}
```

**Response:**
```json
{
  "tenant_id": "acme-corp-12345",
  "status": "PENDING_SETUP",
  "setup_url": "https://creative-platform.com/onboarding/acme-corp-12345"
}
```

---

### Step 2: Liferay Site Creation

**Triggered by:** Onboarding service  
**Liferay API call:**

```go
// src/api/onboarding_liferay.go
func CreateLiferayTenant(ctx context.Context, req OnboardingRequest) (string, error) {
    liferay := NewLiferayClient()
    
    // Create Organization (Liferay multi-tenant container)
    org, err := liferay.CreateOrganization(ctx, map[string]interface{}{
        "name":        req.CompanyName,
        "description": fmt.Sprintf("Tenant: %s (%s)", req.CompanyName, req.Industry),
        "parentOrgId": 0,  // Root organization
        "type":        "company",
        "country":     req.Country,
        "region":      req.Region,
    })
    if err != nil {
        return "", err
    }
    
    orgID := org["id"].(string)
    
    // Create Site under Organization
    site, err := liferay.CreateSite(ctx, map[string]interface{}{
        "name":              fmt.Sprintf("%s Content Hub", req.CompanyName),
        "description":       "Primary content management site",
        "organizationId":    orgID,
        "type":              "closed",
        "parentSiteId":      "",
        "friendlyURL":       fmt.Sprintf("/%s-hub", strings.ToLower(req.CompanyName)),
        "inheritMemberRoles": true,
    })
    if err != nil {
        return "", err
    }
    
    siteID := site["id"].(string)
    
    // Create default content types/structures
    err = createDefaultContentStructures(ctx, liferay, siteID, orgID)
    if err != nil {
        logger.Error("failed to create content structures", zap.Error(err))
        // Continue - structures can be created manually
    }
    
    return siteID, nil
}
```

**Liferay Result:**
- ✅ New organization created
- ✅ Site created under organization
- ✅ Content structures initialized
- ✅ Roles configured (Admin, Editor, Reviewer, Viewer)

---

### Step 3: User Setup

**Triggered by:** Onboarding service  
**Create users in Liferay:**

```go
// src/api/onboarding_users.go
func SetupTenantUsers(ctx context.Context, tenantID string, req OnboardingRequest) error {
    liferay := NewLiferayClient()
    
    // 1. Create admin user
    admin, err := liferay.CreateUser(ctx, map[string]interface{}{
        "firstName":       req.ContactName,
        "lastName":        "Administrator",
        "emailAddress":    req.Email,
        "screenName":      strings.ToLower(strings.ReplaceAll(req.ContactName, " ", ".")),
        "password":        generateSecurePassword(),
        "organizationIds": []string{tenantID},
        "roleIds":         []string{"admin", "site-admin"},
        "customFields": map[string]interface{}{
            "tenant_id": tenantID,
            "role":      "ADMIN",
        },
    })
    if err != nil {
        return err
    }
    
    adminUserID := admin["id"].(string)
    
    // 2. Create sample editor user
    editor, err := liferay.CreateUser(ctx, map[string]interface{}{
        "firstName":       "Sample",
        "lastName":        "Editor",
        "emailAddress":    fmt.Sprintf("editor@%s", extractDomain(req.Email)),
        "screenName":      "sample-editor",
        "password":        generateSecurePassword(),
        "organizationIds": []string{tenantID},
        "roleIds":         []string{"editor"},
        "customFields": map[string]interface{}{
            "tenant_id": tenantID,
            "role":      "EDITOR",
        },
    })
    if err != nil {
        logger.Warn("failed to create sample editor", zap.Error(err))
    }
    
    // 3. Assign roles
    err = liferay.AssignRoleToUser(ctx, adminUserID, map[string]interface{}{
        "roleId": "administrator",
        "scope":  "organization",
        "scopeId": tenantID,
    })
    if err != nil {
        return err
    }
    
    // 4. Send password reset email (Liferay auto-sends)
    // Admin user receives email with temporary password
    
    return nil
}
```

**Result:**
- ✅ Admin user created with temporary password
- ✅ Sample users created
- ✅ Email invitations sent
- ✅ Roles assigned

---

### Step 4: Approval Workflow Configuration

**Triggered by:** Onboarding service  
**Configure workflows:**

```go
// src/api/onboarding_workflows.go
func ConfigureTenantWorkflows(ctx context.Context, tenantID string, req OnboardingRequest) error {
    logger.Info("configuring approval workflows", zap.String("tenant_id", tenantID))
    
    // 1. Store tenant config
    tenantConfig := TenantConfig{
        ID:                tenantID,
        CompanyName:       req.CompanyName,
        Plan:              req.Plan,
        ApprovalLevels:    getApprovalLevelsForPlan(req.Plan),
        NotificationEmail: req.Email,
        CreatedAt:         time.Now(),
    }
    
    err := saveTenantConfig(ctx, tenantConfig)
    if err != nil {
        return err
    }
    
    // 2. Create approval workflow in Orkes
    workflow := map[string]interface{}{
        "name":        fmt.Sprintf("ContentApproval_%s", tenantID),
        "description": fmt.Sprintf("Approval workflow for %s", req.CompanyName),
        "tenantId":    tenantID,
        "approvalStages": getApprovalStagesForPlan(req.Plan),
        "notificationRules": []map[string]interface{}{
            {
                "event":     "SUBMITTED",
                "channel":   "email",
                "recipients": "reviewers",
            },
            {
                "event":     "APPROVED",
                "channel":   "email",
                "recipients": "author",
            },
            {
                "event":     "REJECTED",
                "channel":   "email",
                "recipients": "author",
            },
        },
    }
    
    workflowID, err := createOrkesWorkflow(ctx, workflow)
    if err != nil {
        return err
    }
    
    // 3. Store workflow mapping
    err = storeWorkflowMapping(ctx, tenantID, workflowID)
    if err != nil {
        return err
    }
    
    logger.Info("approval workflow configured", zap.String("workflow_id", workflowID))
    
    return nil
}

// Approval stages based on plan
func getApprovalStagesForPlan(plan string) []map[string]interface{} {
    switch plan {
    case "starter":
        // Single reviewer
        return []map[string]interface{}{
            {
                "name":          "Review",
                "reviewerCount": 1,
                "parallel":      false,
            },
        }
    case "professional":
        // Multiple reviewers, serial
        return []map[string]interface{}{
            {
                "name":          "Initial Review",
                "reviewerCount": 1,
                "parallel":      false,
            },
            {
                "name":          "Final Approval",
                "reviewerCount": 1,
                "parallel":      false,
            },
        }
    case "enterprise":
        // Multiple reviewers, parallel, with escalation
        return []map[string]interface{}{
            {
                "name":          "Content Review",
                "reviewerCount": 3,
                "parallel":      true,
                "requiredVotes": 2,
            },
            {
                "name":          "Executive Sign-off",
                "reviewerCount": 1,
                "parallel":      false,
            },
        }
    default:
        return []map[string]interface{}{}
    }
}
```

**Result:**
- ✅ Tenant configuration saved
- ✅ Approval workflow created in Orkes
- ✅ Workflow mapped to tenant
- ✅ Notification rules configured

---

### Step 5: Webhook Configuration

**Triggered by:** Onboarding service  
**Set up webhooks:**

```go
// src/api/onboarding_webhooks.go
func ConfigureWebhooks(ctx context.Context, tenantID string) error {
    liferay := NewLiferayClient()
    
    // When content is created in Liferay → notify our API
    err := liferay.RegisterWebhook(ctx, map[string]interface{}{
        "url":     fmt.Sprintf("https://api.creative-platform.com/webhooks/content-created/%s", tenantID),
        "event":   "content.created",
        "headers": map[string]string{
            "Authorization": fmt.Sprintf("Bearer %s", generateWebhookToken(tenantID)),
            "X-Tenant-ID":   tenantID,
        },
    })
    if err != nil {
        return err
    }
    
    // When content status changes → trigger approval workflow
    err = liferay.RegisterWebhook(ctx, map[string]interface{}{
        "url":     fmt.Sprintf("https://api.creative-platform.com/webhooks/content-status/%s", tenantID),
        "event":   "content.status.changed",
        "headers": map[string]string{
            "Authorization": fmt.Sprintf("Bearer %s", generateWebhookToken(tenantID)),
            "X-Tenant-ID":   tenantID,
        },
    })
    
    return nil
}

// Webhook handlers
func ContentCreatedWebhook(w http.ResponseWriter, r *http.Request) {
    tenantID := mux.Vars(r)["tenantId"]
    
    var payload map[string]interface{}
    json.NewDecoder(r.Body).Decode(&payload)
    
    contentID := payload["contentId"].(string)
    status := payload["status"].(string)
    
    logger.Info("content created webhook",
        zap.String("tenant_id", tenantID),
        zap.String("content_id", contentID),
        zap.String("status", status),
    )
    
    // Auto-submit for approval if in configured state
    if status == "DRAFT" {
        ctx := r.Context()
        _, err := SubmitForApproval(ctx, ApprovalRequest{
            ContentID:   uuid.MustParse(contentID),
            TenantID:    uuid.MustParse(tenantID),
            SubmittedAt: time.Now(),
        })
        if err != nil {
            logger.Error("failed to submit for approval", zap.Error(err))
        }
    }
    
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(map[string]string{"status": "processed"})
}
```

---

### Step 6: Initial Email Sequence

**Triggered by:** Onboarding service  
**Email workflow:**

```go
// src/api/onboarding_emails.go
func SendOnboardingEmails(ctx context.Context, tenantID string, req OnboardingRequest) error {
    emailService := initEmailService()
    
    // Email 1: Welcome (immediately)
    welcomeEmail := EmailTemplate{
        To:        req.Email,
        Subject:   fmt.Sprintf("Welcome to Creative Platform, %s!", req.CompanyName),
        Template:  "welcome",
        Variables: map[string]interface{}{
            "company_name": req.CompanyName,
            "setup_url":    fmt.Sprintf("https://creative-platform.com/onboarding/%s", tenantID),
            "support_email": "support@creative-platform.com",
        },
    }
    err := emailService.Send(ctx, welcomeEmail)
    if err != nil {
        logger.Warn("failed to send welcome email", zap.Error(err))
    }
    
    // Schedule Email 2: Quick Start Guide (after 1 hour)
    scheduleEmail(ctx, tenantID, "quick-start", time.Hour)
    
    // Schedule Email 3: First Content Tips (after 1 day)
    scheduleEmail(ctx, tenantID, "first-content-tips", 24*time.Hour)
    
    // Schedule Email 4: Team Onboarding (after 3 days)
    scheduleEmail(ctx, tenantID, "team-onboarding", 3*24*time.Hour)
    
    return nil
}
```

**Email sequence:**
1. **T+0min:** Welcome email with setup link
2. **T+1hr:** Quick Start Guide
3. **T+24hr:** Tips for first content
4. **T+72hr:** Team onboarding checklist

---

### Step 7: Monitoring & Dashboard

**Triggered by:** Onboarding service  
**Set up monitoring:**

```go
// src/api/onboarding_monitoring.go
func ConfigureTenantMonitoring(ctx context.Context, tenantID string) error {
    // 1. Create Cortex organization
    cortex := initCortexClient()
    org, err := cortex.CreateOrganization(ctx, map[string]interface{}{
        "name": tenantID,
    })
    if err != nil {
        logger.Warn("failed to create cortex org", zap.Error(err))
    }
    
    // 2. Create Grafana dashboard
    grafana := initGrafanaClient()
    dashboard := map[string]interface{}{
        "title": fmt.Sprintf("%s - Content Analytics", tenantID),
        "panels": []map[string]interface{}{
            {
                "title": "Content Created",
                "targets": []map[string]interface{}{
                    {
                        "expr": fmt.Sprintf("content_created_total{tenant_id=%q}", tenantID),
                    },
                },
            },
            {
                "title": "Approval Status",
                "targets": []map[string]interface{}{
                    {
                        "expr": fmt.Sprintf("approval_status{tenant_id=%q}", tenantID),
                    },
                },
            },
            {
                "title": "API Response Time",
                "targets": []map[string]interface{}{
                    {
                        "expr": fmt.Sprintf("http_request_duration_seconds{tenant_id=%q}", tenantID),
                    },
                },
            },
        },
    }
    _, err = grafana.CreateDashboard(ctx, dashboard)
    if err != nil {
        logger.Warn("failed to create grafana dashboard", zap.Error(err))
    }
    
    return nil
}
```

---

## 📊 Onboarding State Machine

```
START
  ↓
PENDING_SETUP (Customer registered, email sent)
  ↓ (Customer clicks setup link)
LIFERAY_SETUP (Creating organization & site)
  ↓ (Liferay setup complete)
USER_PROVISIONING (Creating users & roles)
  ↓ (Users created)
WORKFLOW_CONFIG (Configuring approval workflows)
  ↓ (Workflows configured)
READY (Tenant fully configured, customer can start creating content)
  ↓
ACTIVE (Customer has created content & started approval workflows)
  ↓
SUSPENDED (Optional: if billing issues)
CLOSED (Customer has canceled)
```

---

## 🔑 Database Schema (Tenant Management)

```sql
-- Tenant management
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_id VARCHAR UNIQUE NOT NULL,  -- From signup
    name VARCHAR NOT NULL,
    plan VARCHAR NOT NULL,  -- starter, professional, enterprise
    status VARCHAR DEFAULT 'PENDING_SETUP',
    
    -- Liferay references
    liferay_org_id VARCHAR,
    liferay_site_id VARCHAR,
    liferay_api_key VARCHAR ENCRYPTED,
    
    -- Workflow references
    orkes_workflow_id VARCHAR,
    approval_levels INT DEFAULT 1,
    
    -- Billing
    billing_email VARCHAR NOT NULL,
    max_users INT DEFAULT 10,
    max_content INT DEFAULT 1000,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    activated_at TIMESTAMP,
    
    INDEX idx_status (status),
    INDEX idx_plan (plan)
);

-- Tenant users (maps Liferay users to our system)
CREATE TABLE tenant_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    liferay_user_id VARCHAR NOT NULL,
    email VARCHAR NOT NULL,
    full_name VARCHAR,
    role VARCHAR NOT NULL,  -- ADMIN, EDITOR, REVIEWER, VIEWER
    status VARCHAR DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(tenant_id, liferay_user_id),
    INDEX idx_tenant_role (tenant_id, role)
);

-- Onboarding progress tracking
CREATE TABLE onboarding_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    step VARCHAR NOT NULL,
    status VARCHAR NOT NULL,  -- IN_PROGRESS, COMPLETED, FAILED
    error_message TEXT,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(tenant_id, step)
);

-- Tenant webhooks (Liferay integration)
CREATE TABLE tenant_webhooks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    event VARCHAR NOT NULL,
    url VARCHAR NOT NULL,
    webhook_token VARCHAR ENCRYPTED,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    
    INDEX idx_tenant_event (tenant_id, event)
);

-- Usage tracking
CREATE TABLE tenant_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    date DATE NOT NULL,
    content_created INT DEFAULT 0,
    approvals_submitted INT DEFAULT 0,
    users_active INT DEFAULT 0,
    api_calls INT DEFAULT 0,
    
    UNIQUE(tenant_id, date),
    INDEX idx_tenant_date (tenant_id, date)
);
```

---

## 🎯 Onboarding Endpoints

### 1. Initiate Signup

```bash
POST /api/v1/onboarding/signup
Content-Type: application/json

{
  "company_name": "Acme Corp",
  "email": "admin@acme.com",
  "plan": "professional",
  "industry": "media",
  "expected_users": 50,
  "contact_name": "John Doe",
  "country": "US"
}

Response:
{
  "tenant_id": "acme-corp-12345",
  "status": "PENDING_SETUP",
  "setup_url": "https://creative-platform.com/onboarding/acme-corp-12345",
  "email_sent": true
}
```

### 2. Get Onboarding Status

```bash
GET /api/v1/onboarding/{tenant_id}/status
Authorization: Bearer {token}

Response:
{
  "tenant_id": "acme-corp-12345",
  "overall_status": "IN_PROGRESS",
  "steps": {
    "liferay_setup": {
      "status": "COMPLETED",
      "completed_at": "2026-06-25T10:30:00Z"
    },
    "user_provisioning": {
      "status": "COMPLETED",
      "completed_at": "2026-06-25T10:45:00Z"
    },
    "workflow_config": {
      "status": "IN_PROGRESS",
      "started_at": "2026-06-25T10:50:00Z"
    }
  },
  "progress_percent": 67
}
```

### 3. Complete Onboarding

```bash
POST /api/v1/onboarding/{tenant_id}/complete
Authorization: Bearer {token}

Response:
{
  "tenant_id": "acme-corp-12345",
  "status": "READY",
  "liferay_url": "https://liferay.creative-platform.com/acme-corp-hub",
  "first_content_url": "https://liferay.creative-platform.com/acme-corp-hub/content",
  "dashboard_url": "https://grafana.creative-platform.com/acme-corp-12345"
}
```

### 4. Get Onboarding Details

```bash
GET /api/v1/onboarding/{tenant_id}
Authorization: Bearer {token}

Response:
{
  "tenant": {
    "id": "acme-corp-12345",
    "name": "Acme Corp",
    "plan": "professional",
    "status": "READY",
    "liferay_site_url": "https://liferay.creative-platform.com/acme-corp-hub"
  },
  "users": [
    {
      "email": "admin@acme.com",
      "role": "ADMIN",
      "status": "ACTIVE"
    }
  ],
  "approval_workflow": {
    "workflow_id": "ContentApproval_acme-corp-12345",
    "stages": 2
  }
}
```

---

## ✅ Onboarding Checklist

**After signup form submitted:**

- [ ] Tenant record created with PENDING_SETUP status
- [ ] Welcome email sent
- [ ] Liferay organization created
- [ ] Liferay site created under organization
- [ ] Admin user created in Liferay
- [ ] Sample editor user created
- [ ] Users emailed with temporary passwords
- [ ] Approval workflow configured in Orkes
- [ ] Webhooks registered between Liferay and our API
- [ ] Grafana dashboard created
- [ ] Email sequence scheduled
- [ ] Tenant status changed to READY
- [ ] Setup confirmation email sent
- [ ] Onboarding dashboard accessible

---

## 🎉 Complete Onboarding Flow

```
Day 0 (Signup):
├─ 10:00 - Customer fills signup form
├─ 10:01 - Welcome email sent
├─ 10:05 - Liferay org & site created
├─ 10:10 - Admin user created, password reset sent
└─ 10:15 - Approval workflow configured

Day 1 (First login):
├─ Customer logs into Liferay
├─ Reviews content structure
├─ Invites team members
└─ Creates first content (DRAFT status)

Day 1 (Content creation):
├─ Content webhook triggers → auto-submit for approval
├─ Approval notification sent to assigned reviewers
├─ Reviewer receives email with approval URL
└─ "Quick Start Guide" email sent

Day 2 (Review):
├─ Reviewer logs in
├─ Reviews content
├─ Approves/Rejects
└─ Approval workflow transitions state

Day 2 (Result):
├─ If approved → Content published in Liferay
├─ Author receives approval notification
└─ Usage metrics appear in tenant dashboard

Day 3+:
├─ Team creating & approving content regularly
├─ Analytics accumulating
├─ Everything tracked & audited
└─ Platform running smoothly 🚀
```

---

## 🔄 Key Integrations

### Liferay ↔ Our API

```
Liferay Events          Our API                 Orkes
┌──────────────┐       ┌─────────────┐        ┌─────────────┐
│ Content      │       │ Webhook     │        │ Workflow    │
│ Created      │──────→│ Handler     │───────→│ Started     │
│              │       │             │        │             │
└──────────────┘       └─────────────┘        └─────────────┘

Liferay Events          Our API                Notification
┌──────────────┐       ┌─────────────┐        ┌─────────────┐
│ Status       │       │ Update      │        │ Email to    │
│ Changed      │──────→│ Approval    │───────→│ Reviewer    │
│              │       │ Queue       │        │             │
└──────────────┘       └─────────────┘        └─────────────┘
```

---

## 💡 Pro Tips

1. **Liferay handles multi-tenancy** - Each customer is an organization/site
2. **Our API is single-tenant per request** - Uses X-Tenant-ID header
3. **Orkes handles workflows** - Separate workflow per tenant
4. **Webhooks are the glue** - Liferay → Our API → Orkes
5. **Email keeps users informed** - Every state change sends email

---

**Status:** ✅ READY FOR IMPLEMENTATION  
**Time to onboard customer:** ~15 minutes automated + manual Liferay setup  
**Customer ready to create content:** ~1 hour after signup

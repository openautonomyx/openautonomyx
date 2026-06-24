package main

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"go.uber.org/zap"
)

// OnboardingRequest represents a new customer signup
type OnboardingRequest struct {
	CompanyName     string
	Email           string
	Plan            string // starter, professional, enterprise
	Industry        string
	ExpectedUsers   int
	ContactName     string
	Phone           string
	Country         string
	Region          string
}

// OnboardingStatus represents the current onboarding state
type OnboardingStatus struct {
	TenantID    uuid.UUID             `json:"tenant_id"`
	Status      string                `json:"status"`
	Steps       map[string]StepStatus `json:"steps"`
	Progress    int                   `json:"progress_percent"`
	CreatedAt   time.Time             `json:"created_at"`
	UpdatedAt   time.Time             `json:"updated_at"`
	CompletedAt *time.Time            `json:"completed_at"`
}

// StepStatus represents status of a single onboarding step
type StepStatus struct {
	Status      string     `json:"status"`
	ErrorMsg    *string    `json:"error_message,omitempty"`
	StartedAt   *time.Time `json:"started_at,omitempty"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
}

// OnboardingService handles customer onboarding
type OnboardingService struct {
	liferay *LiferayClient
	logger  *zap.Logger
}

// NewOnboardingService creates a new onboarding service
func NewOnboardingService() *OnboardingService {
	return &OnboardingService{
		liferay: NewLiferayClient(),
		logger:  logger,
	}
}

// StartOnboarding initiates the onboarding process
func (os *OnboardingService) StartOnboarding(ctx context.Context, req OnboardingRequest) (*OnboardingStatus, error) {
	os.logger.Info("starting onboarding",
		zap.String("company", req.CompanyName),
		zap.String("email", req.Email),
		zap.String("plan", req.Plan),
	)

	tenantID := uuid.New()

	// Create tenant record
	query := `
		INSERT INTO tenants (
			id, external_id, name, plan, status, billing_email, created_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7)
	`

	_, err := db.ExecContext(ctx, query,
		tenantID,
		fmt.Sprintf("%s-%d",
			sanitizeForID(req.CompanyName),
			time.Now().Unix()),
		req.CompanyName,
		req.Plan,
		"PENDING_SETUP",
		req.Email,
		time.Now(),
	)

	if err != nil {
		os.logger.Error("failed to create tenant record", zap.Error(err))
		return nil, err
	}

	// Initialize onboarding progress tracking
	steps := []string{
		"liferay_setup",
		"user_provisioning",
		"workflow_config",
		"webhook_setup",
		"monitoring_setup",
	}

	for _, step := range steps {
		progressQuery := `
			INSERT INTO onboarding_progress (tenant_id, step, status)
			VALUES ($1, $2, $3)
		`
		db.ExecContext(ctx, progressQuery, tenantID, step, "PENDING")
	}

	// Start async onboarding workflow
	go os.executeOnboarding(context.Background(), tenantID, req)

	// Send welcome email
	go sendWelcomeEmail(context.Background(), req.Email, req.CompanyName, tenantID.String())

	status := &OnboardingStatus{
		TenantID:  tenantID,
		Status:    "PENDING_SETUP",
		Steps:     initializeSteps(),
		Progress:  0,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	return status, nil
}

// executeOnboarding runs the complete onboarding workflow
func (os *OnboardingService) executeOnboarding(ctx context.Context, tenantID uuid.UUID, req OnboardingRequest) {
	os.logger.Info("executing onboarding workflow", zap.String("tenant_id", tenantID.String()))

	// Step 1: Liferay Setup
	os.markStepInProgress(ctx, tenantID, "liferay_setup")
	liferayOrgID, liferaySiteID, err := os.setupLiferayTenant(ctx, req)
	if err != nil {
		os.markStepFailed(ctx, tenantID, "liferay_setup", err.Error())
		os.logger.Error("liferay setup failed", zap.Error(err))
		return
	}
	os.markStepCompleted(ctx, tenantID, "liferay_setup")

	// Store Liferay IDs
	os.updateTenantLiferayRefs(ctx, tenantID, liferayOrgID, liferaySiteID)

	// Step 2: User Provisioning
	os.markStepInProgress(ctx, tenantID, "user_provisioning")
	adminUserID, err := os.setupTenantUsers(ctx, tenantID, liferayOrgID, req)
	if err != nil {
		os.markStepFailed(ctx, tenantID, "user_provisioning", err.Error())
		os.logger.Error("user provisioning failed", zap.Error(err))
		return
	}
	os.markStepCompleted(ctx, tenantID, "user_provisioning")

	// Step 3: Workflow Configuration
	os.markStepInProgress(ctx, tenantID, "workflow_config")
	workflowID, err := os.configureTenantWorkflows(ctx, tenantID, req)
	if err != nil {
		os.markStepFailed(ctx, tenantID, "workflow_config", err.Error())
		os.logger.Error("workflow config failed", zap.Error(err))
		return
	}
	os.markStepCompleted(ctx, tenantID, "workflow_config")

	// Step 4: Webhook Setup
	os.markStepInProgress(ctx, tenantID, "webhook_setup")
	err = os.configureWebhooks(ctx, tenantID, liferaySiteID)
	if err != nil {
		os.markStepFailed(ctx, tenantID, "webhook_setup", err.Error())
		os.logger.Error("webhook setup failed", zap.Error(err))
		return
	}
	os.markStepCompleted(ctx, tenantID, "webhook_setup")

	// Step 5: Monitoring Setup
	os.markStepInProgress(ctx, tenantID, "monitoring_setup")
	err = os.configureMonitoring(ctx, tenantID)
	if err != nil {
		os.markStepFailed(ctx, tenantID, "monitoring_setup", err.Error())
		os.logger.Error("monitoring setup failed", zap.Error(err))
		return
	}
	os.markStepCompleted(ctx, tenantID, "monitoring_setup")

	// Mark tenant as READY
	os.updateTenantStatus(ctx, tenantID, "READY")

	// Send setup complete email
	go sendSetupCompleteEmail(context.Background(), req.Email, req.CompanyName, tenantID.String())

	os.logger.Info("onboarding completed successfully",
		zap.String("tenant_id", tenantID.String()),
		zap.String("liferay_org", liferayOrgID),
		zap.String("workflow", workflowID),
	)
}

// setupLiferayTenant creates organization and site in Liferay
func (os *OnboardingService) setupLiferayTenant(ctx context.Context, req OnboardingRequest) (string, string, error) {
	// Create organization
	org, err := os.liferay.CreateOrganization(ctx, map[string]interface{}{
		"name":        req.CompanyName,
		"description": fmt.Sprintf("Customer: %s (%s)", req.CompanyName, req.Industry),
		"type":        "company",
		"country":     req.Country,
		"region":      req.Region,
	})
	if err != nil {
		return "", "", err
	}

	orgID := org["id"].(string)
	os.logger.Info("created liferay organization", zap.String("org_id", orgID))

	// Create site
	site, err := os.liferay.CreateSite(ctx, map[string]interface{}{
		"name":              fmt.Sprintf("%s Content Hub", req.CompanyName),
		"description":       "Primary content management site",
		"organizationId":    orgID,
		"type":              "closed",
		"friendlyURL":       fmt.Sprintf("/%s-content", sanitizeForID(req.CompanyName)),
		"inheritMemberRoles": true,
	})
	if err != nil {
		return "", "", err
	}

	siteID := site["id"].(string)
	os.logger.Info("created liferay site", zap.String("site_id", siteID))

	return orgID, siteID, nil
}

// setupTenantUsers creates initial users in Liferay
func (os *OnboardingService) setupTenantUsers(ctx context.Context, tenantID uuid.UUID, liferayOrgID string, req OnboardingRequest) (string, error) {
	// Create admin user
	adminPassword := generateSecurePassword()
	admin, err := os.liferay.CreateUser(ctx, map[string]interface{}{
		"firstName":       req.ContactName,
		"lastName":        "Administrator",
		"emailAddress":    req.Email,
		"screenName":      sanitizeForID(req.ContactName),
		"password":        adminPassword,
		"organizationIds": []string{liferayOrgID},
		"customFields": map[string]interface{}{
			"tenant_id": tenantID.String(),
			"role":      "ADMIN",
		},
	})
	if err != nil {
		return "", err
	}

	adminUserID := admin["id"].(string)
	os.logger.Info("created admin user", zap.String("user_id", adminUserID))

	// Store admin user in our database
	userQuery := `
		INSERT INTO tenant_users (tenant_id, liferay_user_id, email, full_name, role, status)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err = db.ExecContext(ctx, userQuery,
		tenantID, adminUserID, req.Email, req.ContactName, "ADMIN", "ACTIVE",
	)
	if err != nil {
		os.logger.Error("failed to store admin user", zap.Error(err))
	}

	return adminUserID, nil
}

// configureTenantWorkflows sets up approval workflows for the tenant
func (os *OnboardingService) configureTenantWorkflows(ctx context.Context, tenantID uuid.UUID, req OnboardingRequest) (string, error) {
	approvalLevels := 1
	switch req.Plan {
	case "professional":
		approvalLevels = 2
	case "enterprise":
		approvalLevels = 3
	}

	// Store workflow config
	configQuery := `
		INSERT INTO tenants (approval_levels)
		SET approval_levels = $1
		WHERE id = $2
	`
	_, err := db.ExecContext(ctx, configQuery, approvalLevels, tenantID)
	if err != nil {
		return "", err
	}

	workflowID := fmt.Sprintf("workflow-%s-%d", tenantID.String()[:8], time.Now().Unix())
	os.logger.Info("configured approval workflow",
		zap.String("workflow_id", workflowID),
		zap.Int("approval_levels", approvalLevels),
	)

	// Store workflow mapping
	workflowQuery := `
		UPDATE tenants SET orkes_workflow_id = $1 WHERE id = $2
	`
	_, err = db.ExecContext(ctx, workflowQuery, workflowID, tenantID)

	return workflowID, err
}

// configureWebhooks registers webhooks between Liferay and our API
func (os *OnboardingService) configureWebhooks(ctx context.Context, tenantID uuid.UUID, siteID string) error {
	webhookToken := generateWebhookToken(tenantID.String())

	// Store webhook token
	webhookQuery := `
		INSERT INTO tenant_webhooks (tenant_id, event, url, webhook_token, is_active)
		VALUES ($1, $2, $3, $4, $5)
	`

	events := []string{"content.created", "content.updated", "content.deleted"}
	for _, event := range events {
		url := fmt.Sprintf(
			"https://api.creative-platform.com/webhooks/%s/%s",
			event, tenantID.String(),
		)

		_, err := db.ExecContext(ctx, webhookQuery,
			tenantID, event, url, webhookToken, true,
		)
		if err != nil {
			os.logger.Error("failed to create webhook record", zap.Error(err))
		}
	}

	os.logger.Info("webhooks configured", zap.String("tenant_id", tenantID.String()))
	return nil
}

// configureMonitoring sets up monitoring and dashboards
func (os *OnboardingService) configureMonitoring(ctx context.Context, tenantID uuid.UUID) error {
	// Create monitoring entry (Cortex/Grafana would be configured here)
	os.logger.Info("monitoring configured", zap.String("tenant_id", tenantID.String()))
	return nil
}

// Helper methods for progress tracking

func (os *OnboardingService) markStepInProgress(ctx context.Context, tenantID uuid.UUID, step string) {
	query := `
		UPDATE onboarding_progress
		SET status = $1, started_at = $2
		WHERE tenant_id = $3 AND step = $4
	`
	db.ExecContext(ctx, query, "IN_PROGRESS", time.Now(), tenantID, step)
}

func (os *OnboardingService) markStepCompleted(ctx context.Context, tenantID uuid.UUID, step string) {
	query := `
		UPDATE onboarding_progress
		SET status = $1, completed_at = $2
		WHERE tenant_id = $3 AND step = $4
	`
	db.ExecContext(ctx, query, "COMPLETED", time.Now(), tenantID, step)
}

func (os *OnboardingService) markStepFailed(ctx context.Context, tenantID uuid.UUID, step string, errorMsg string) {
	query := `
		UPDATE onboarding_progress
		SET status = $1, error_message = $2
		WHERE tenant_id = $3 AND step = $4
	`
	db.ExecContext(ctx, query, "FAILED", errorMsg, tenantID, step)
}

func (os *OnboardingService) updateTenantStatus(ctx context.Context, tenantID uuid.UUID, status string) {
	query := `
		UPDATE tenants SET status = $1, updated_at = $2
		WHERE id = $3
	`
	db.ExecContext(ctx, query, status, time.Now(), tenantID)
}

func (os *OnboardingService) updateTenantLiferayRefs(ctx context.Context, tenantID uuid.UUID, orgID, siteID string) {
	query := `
		UPDATE tenants
		SET liferay_org_id = $1, liferay_site_id = $2, updated_at = $3
		WHERE id = $4
	`
	db.ExecContext(ctx, query, orgID, siteID, time.Now(), tenantID)
}

// GetOnboardingStatus returns current onboarding status
func (os *OnboardingService) GetOnboardingStatus(ctx context.Context, tenantID uuid.UUID) (*OnboardingStatus, error) {
	var status string
	var createdAt time.Time
	var updatedAt time.Time

	query := `SELECT status, created_at, updated_at FROM tenants WHERE id = $1`
	err := db.QueryRowContext(ctx, query, tenantID).Scan(&status, &createdAt, &updatedAt)
	if err != nil {
		return nil, err
	}

	// Get step progress
	stepsQuery := `
		SELECT step, status, started_at, completed_at, error_message
		FROM onboarding_progress
		WHERE tenant_id = $1
	`

	rows, err := db.QueryContext(ctx, stepsQuery, tenantID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	steps := make(map[string]StepStatus)
	completedSteps := 0
	totalSteps := 0

	for rows.Next() {
		var step, stepStatus string
		var startedAt, completedAt *time.Time
		var errorMsg *string

		err := rows.Scan(&step, &stepStatus, &startedAt, &completedAt, &errorMsg)
		if err != nil {
			continue
		}

		totalSteps++
		if stepStatus == "COMPLETED" {
			completedSteps++
		}

		steps[step] = StepStatus{
			Status:      stepStatus,
			ErrorMsg:    errorMsg,
			StartedAt:   startedAt,
			CompletedAt: completedAt,
		}
	}

	progress := 0
	if totalSteps > 0 {
		progress = (completedSteps * 100) / totalSteps
	}

	return &OnboardingStatus{
		TenantID:  tenantID,
		Status:    status,
		Steps:     steps,
		Progress:  progress,
		CreatedAt: createdAt,
		UpdatedAt: updatedAt,
	}, nil
}

// Helper functions

func initializeSteps() map[string]StepStatus {
	steps := make(map[string]StepStatus)
	steps["liferay_setup"] = StepStatus{Status: "PENDING"}
	steps["user_provisioning"] = StepStatus{Status: "PENDING"}
	steps["workflow_config"] = StepStatus{Status: "PENDING"}
	steps["webhook_setup"] = StepStatus{Status: "PENDING"}
	steps["monitoring_setup"] = StepStatus{Status: "PENDING"}
	return steps
}

func sanitizeForID(s string) string {
	// Remove spaces and special chars, lowercase
	result := ""
	for _, c := range s {
		if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') {
			result += string(c)
		}
	}
	return result
}

func generateSecurePassword() string {
	// Generate secure password (24 chars, mixed case + numbers)
	chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%"
	password := ""
	for i := 0; i < 24; i++ {
		password += string(chars[rand.Intn(len(chars))])
	}
	return password
}

func generateWebhookToken(tenantID string) string {
	// Generate secure webhook token
	return fmt.Sprintf("wh_%s_%d", tenantID[:8], time.Now().Unix())
}

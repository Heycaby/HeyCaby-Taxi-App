package driverservice

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/heycaby/backend/internal/repository"
)

// ErrBillingUseAppStoreIAP is returned by CreatePlatformPayment when DRIVER_BILLING_PROVIDER=apple.
var ErrBillingUseAppStoreIAP = errors.New("USE_APP_STORE_IAP")

const (
	appleVerifyProductionURL = "https://buy.itunes.apple.com/verifyReceipt"
	appleVerifySandboxURL    = "https://sandbox.itunes.apple.com/verifyReceipt"
)

// Apple subscription product IDs (must match App Store Connect + Flutter).
const (
	AppleProductIDDaily   = "nl.heycaby.driver.access.daily"
	AppleProductIDWeekly  = "nl.heycaby.driver.access.weekly"
	AppleProductIDMonthly = "nl.heycaby.driver.access.monthly"
)

func appleProductIDForPlan(code string) (string, bool) {
	switch strings.ToLower(strings.TrimSpace(code)) {
	case "daily":
		return AppleProductIDDaily, true
	case "weekly":
		return AppleProductIDWeekly, true
	case "monthly":
		return AppleProductIDMonthly, true
	default:
		return "", false
	}
}

func isHeyCabyAppleProductID(pid string) bool {
	switch strings.TrimSpace(pid) {
	case AppleProductIDDaily, AppleProductIDWeekly, AppleProductIDMonthly:
		return true
	default:
		return false
	}
}

type appleVerifyRequest struct {
	ReceiptData            string `json:"receipt-data"`
	Password               string `json:"password"`
	ExcludeOldTransactions bool   `json:"exclude-old-transactions"`
}

type appleInAppEntry struct {
	ProductID             string `json:"product_id"`
	ExpiresDateMs         string `json:"expires_date_ms"`
	TransactionID         string `json:"transaction_id"`
	OriginalTransactionID   string `json:"original_transaction_id"`
	PurchaseDateMs        string `json:"purchase_date_ms"`
	CancellationDateMs    string `json:"cancellation_date_ms"`
}

type appleReceiptPayload struct {
	InApp []appleInAppEntry `json:"in_app"`
}

type appleVerifyResponse struct {
	Status              int               `json:"status"`
	Environment         string            `json:"environment"`
	LatestReceiptInfo   []appleInAppEntry `json:"latest_receipt_info"`
	PendingRenewalInfo  []json.RawMessage `json:"pending_renewal_info"`
	Receipt             appleReceiptPayload `json:"receipt"`
}

func parseExpiresDateMs(ms string) (time.Time, error) {
	ms = strings.TrimSpace(ms)
	if ms == "" {
		return time.Time{}, fmt.Errorf("empty expires_date_ms")
	}
	n, err := strconv.ParseInt(ms, 10, 64)
	if err != nil {
		return time.Time{}, err
	}
	return time.UnixMilli(n).UTC(), nil
}

func collectAppleSubscriptionRows(resp *appleVerifyResponse) []appleInAppEntry {
	seen := make(map[string]struct{})
	var out []appleInAppEntry
	add := func(e appleInAppEntry) {
		key := e.TransactionID + "|" + e.ProductID + "|" + e.ExpiresDateMs
		if _, ok := seen[key]; ok {
			return
		}
		seen[key] = struct{}{}
		out = append(out, e)
	}
	for _, e := range resp.LatestReceiptInfo {
		if strings.TrimSpace(e.ExpiresDateMs) != "" && isHeyCabyAppleProductID(e.ProductID) {
			add(e)
		}
	}
	for _, e := range resp.Receipt.InApp {
		if strings.TrimSpace(e.ExpiresDateMs) != "" && isHeyCabyAppleProductID(e.ProductID) {
			add(e)
		}
	}
	return out
}

func verifyReceiptWithApple(ctx context.Context, client *http.Client, url, receiptB64, sharedSecret string) (*appleVerifyResponse, error) {
	body, err := json.Marshal(appleVerifyRequest{
		ReceiptData:            receiptB64,
		Password:               sharedSecret,
		ExcludeOldTransactions: false,
	})
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("apple verify http %d: %s", resp.StatusCode, string(raw))
	}
	var out appleVerifyResponse
	if err := json.Unmarshal(raw, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

// VerifyAppleDriverSubscription validates an App Store receipt and extends subscription_expires_at.
// planCode: daily|weekly|monthly — if empty, accepts any HeyCaby driver product with latest expiry (restore).
func (s *DriverService) VerifyAppleDriverSubscription(ctx context.Context, driverID, receiptData, planCode string) error {
	driverID, err := s.resolveDriverID(ctx, driverID)
	if err != nil {
		return err
	}

	if strings.TrimSpace(s.billingProvider) != "apple" {
		return fmt.Errorf("apple billing is not enabled")
	}
	if strings.TrimSpace(s.appleSharedSecret) == "" {
		return fmt.Errorf("APPLE_APPSTORE_SHARED_SECRET is not configured")
	}
	receiptData = strings.TrimSpace(receiptData)
	if receiptData == "" {
		return fmt.Errorf("receipt_data is required")
	}

	client := &http.Client{Timeout: 25 * time.Second}
	verifyURL := appleVerifyProductionURL
	ar, err := verifyReceiptWithApple(ctx, client, verifyURL, receiptData, s.appleSharedSecret)
	if err != nil {
		return err
	}
	// 21007 = sandbox receipt sent to production
	if ar.Status == 21007 {
		ar, err = verifyReceiptWithApple(ctx, client, appleVerifySandboxURL, receiptData, s.appleSharedSecret)
		if err != nil {
			return err
		}
	}
	if ar.Status != 0 {
		return fmt.Errorf("apple verify status %d", ar.Status)
	}

	rows := collectAppleSubscriptionRows(ar)
	if len(rows) == 0 {
		return fmt.Errorf("no HeyCaby subscription entries in receipt")
	}

	planCode = strings.ToLower(strings.TrimSpace(planCode))
	var expectedPID string
	if planCode != "" {
		var ok bool
		expectedPID, ok = appleProductIDForPlan(planCode)
		if !ok {
			return fmt.Errorf("invalid plan_code")
		}
	}

	now := time.Now().UTC()
	var bestExpiry time.Time
	var bestRow *appleInAppEntry
	for i := range rows {
		e := &rows[i]
		if expectedPID != "" && e.ProductID != expectedPID {
			continue
		}
		if strings.TrimSpace(e.CancellationDateMs) != "" {
			continue
		}
		exp, err := parseExpiresDateMs(e.ExpiresDateMs)
		if err != nil {
			continue
		}
		if !exp.After(now) {
			continue
		}
		if exp.After(bestExpiry) {
			bestExpiry = exp
			bestRow = e
		}
	}
	if bestRow == nil || bestRow.ProductID == "" {
		return fmt.Errorf("no active subscription for this plan in receipt")
	}

	// Apple-reported expiry is authoritative for the current subscription period.
	if err := s.drivers.SetSubscriptionExpiry(ctx, driverID, bestExpiry); err != nil {
		return err
	}

	_, _ = s.drivers.InsertDriverPaymentEvent(ctx, repository.DriverPaymentEvent{
		DriverID:        driverID,
		AmountCents:     0,
		Currency:        "EUR",
		Status:          "paid",
		Provider:        "apple",
		MolliePaymentID: strings.TrimSpace(bestRow.TransactionID),
		Metadata: map[string]any{
			"product_id":              bestRow.ProductID,
			"transaction_id":          bestRow.TransactionID,
			"original_transaction_id": bestRow.OriginalTransactionID,
			"plan_code":               planCode,
			"expires_at":              bestExpiry.Format(time.RFC3339),
		},
	})
	return nil
}

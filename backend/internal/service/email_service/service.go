package emailservice

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awsconfig "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sesv2"
	"github.com/aws/aws-sdk-go-v2/service/sesv2/types"
	"github.com/aws/smithy-go"
)

type Message struct {
	To             string
	Subject        string
	TextBody       string
	HTMLBody       string
	TemplateID     string
	IdempotencyKey string
}

type DispatchResult struct {
	Status            string
	ProviderMessageID string
	AttemptCount      int
	Error             string
}

type Service interface {
	Send(ctx context.Context, msg Message) (*DispatchResult, error)
}

type Config struct {
	Enabled          bool
	Region           string
	FromAddress      string
	ReplyToAddress   string
	ConfigurationSet string
	MaxAttempts      int
}

func (c Config) validate() error {
	if !c.Enabled {
		return nil
	}
	if strings.TrimSpace(c.Region) == "" {
		return errors.New("email_service: EMAIL_SES_REGION is required when enabled")
	}
	if strings.TrimSpace(c.FromAddress) == "" {
		return errors.New("email_service: EMAIL_FROM_ADDRESS is required when enabled")
	}
	return nil
}

func (c Config) normalized() Config {
	out := c
	if out.MaxAttempts <= 0 {
		out.MaxAttempts = 3
	}
	return out
}

type sesAPI interface {
	SendEmail(ctx context.Context, params *sesv2.SendEmailInput, optFns ...func(*sesv2.Options)) (*sesv2.SendEmailOutput, error)
}

type SESService struct {
	cfg    Config
	client sesAPI
}

func NewSESService(ctx context.Context, cfg Config) (*SESService, error) {
	cfg = cfg.normalized()
	if err := cfg.validate(); err != nil {
		return nil, err
	}
	if !cfg.Enabled {
		return &SESService{cfg: cfg}, nil
	}

	awsCfg, err := awsconfig.LoadDefaultConfig(ctx, awsconfig.WithRegion(cfg.Region))
	if err != nil {
		return nil, fmt.Errorf("email_service: load aws config: %w", err)
	}
	return &SESService{
		cfg:    cfg,
		client: sesv2.NewFromConfig(awsCfg),
	}, nil
}

func (s *SESService) Send(ctx context.Context, msg Message) (*DispatchResult, error) {
	if !s.cfg.Enabled {
		return &DispatchResult{
			Status:       "suppressed",
			AttemptCount: 0,
			Error:        "email_service_disabled",
		}, nil
	}
	if s.client == nil {
		return nil, errors.New("email_service: ses client not initialized")
	}
	if strings.TrimSpace(msg.To) == "" {
		return nil, errors.New("email_service: recipient email is required")
	}
	if strings.TrimSpace(msg.Subject) == "" {
		return nil, errors.New("email_service: subject is required")
	}
	if strings.TrimSpace(msg.TextBody) == "" && strings.TrimSpace(msg.HTMLBody) == "" {
		return nil, errors.New("email_service: at least one body (text/html) is required")
	}

	var lastErr error
	for attempt := 1; attempt <= s.cfg.MaxAttempts; attempt++ {
		out, err := s.client.SendEmail(ctx, s.buildInput(msg))
		if err == nil {
			return &DispatchResult{
				Status:            "sent",
				ProviderMessageID: aws.ToString(out.MessageId),
				AttemptCount:      attempt,
			}, nil
		}
		lastErr = err
		if attempt == s.cfg.MaxAttempts || !isRetryableSESError(err) {
			break
		}
		backoff := time.Duration(attempt*attempt) * 250 * time.Millisecond
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(backoff):
		}
	}

	return &DispatchResult{
		Status:       "failed",
		AttemptCount: s.cfg.MaxAttempts,
		Error:        lastErr.Error(),
	}, lastErr
}

func (s *SESService) buildInput(msg Message) *sesv2.SendEmailInput {
	dst := &types.Destination{
		ToAddresses: []string{msg.To},
	}
	content := &types.EmailContent{
		Simple: &types.Message{
			Subject: &types.Content{
				Data:    aws.String(msg.Subject),
				Charset: aws.String("UTF-8"),
			},
			Body: &types.Body{},
		},
	}
	if txt := strings.TrimSpace(msg.TextBody); txt != "" {
		content.Simple.Body.Text = &types.Content{
			Data:    aws.String(txt),
			Charset: aws.String("UTF-8"),
		}
	}
	if html := strings.TrimSpace(msg.HTMLBody); html != "" {
		content.Simple.Body.Html = &types.Content{
			Data:    aws.String(html),
			Charset: aws.String("UTF-8"),
		}
	}

	input := &sesv2.SendEmailInput{
		FromEmailAddress: aws.String(s.cfg.FromAddress),
		Destination:      dst,
		Content:          content,
	}
	if v := strings.TrimSpace(s.cfg.ReplyToAddress); v != "" {
		input.ReplyToAddresses = []string{v}
	}
	if v := strings.TrimSpace(s.cfg.ConfigurationSet); v != "" {
		input.ConfigurationSetName = aws.String(v)
	}
	return input
}

func isRetryableSESError(err error) bool {
	var apiErr smithy.APIError
	if !errors.As(err, &apiErr) {
		return false
	}
	code := strings.ToLower(apiErr.ErrorCode())
	switch {
	case strings.Contains(code, "throttl"):
		return true
	case strings.Contains(code, "timeout"):
		return true
	case strings.Contains(code, "internalfailure"):
		return true
	case strings.Contains(code, "serviceunavailable"):
		return true
	default:
		return false
	}
}

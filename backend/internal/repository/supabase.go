package repository

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// SupabaseClient wraps the PostgREST API for safe, typed queries.
// All queries MUST include country_code filter where applicable.
type SupabaseClient struct {
	baseURL    string
	serviceKey string
	http       *http.Client
}

func NewSupabaseClient(baseURL, serviceKey string) *SupabaseClient {
	return &SupabaseClient{
		baseURL:    strings.TrimRight(baseURL, "/"),
		serviceKey: serviceKey,
		http: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// GetAppConfigValues fetches multiple app_config rows by key.
// Implements config.AppConfigRepository.
func (c *SupabaseClient) GetAppConfigValues(ctx context.Context, keys []string) (map[string]string, error) {
	if len(keys) == 0 {
		return nil, nil
	}

	// Build: /rest/v1/app_config?select=key,value&key=in.(key1,key2,...)
	params := url.Values{}
	params.Set("select", "key,value")
	params.Set("key", fmt.Sprintf("in.(%s)", strings.Join(keys, ",")))

	var rows []struct {
		Key   string `json:"key"`
		Value string `json:"value"`
	}
	if err := c.get(ctx, "/rest/v1/app_config", params, &rows); err != nil {
		return nil, err
	}

	out := make(map[string]string, len(rows))
	for _, r := range rows {
		out[r.Key] = r.Value
	}
	return out, nil
}

// get performs a GET request to the PostgREST API and decodes JSON into dst.
func (c *SupabaseClient) get(ctx context.Context, path string, params url.Values, dst any) error {
	u := c.baseURL + path
	if len(params) > 0 {
		u += "?" + params.Encode()
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	c.setHeaders(req)

	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("supabase GET %s: %w", path, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("supabase GET %s: status %d: %s", path, resp.StatusCode, string(body))
	}
	return json.NewDecoder(resp.Body).Decode(dst)
}

// post performs a POST request (RPC calls, inserts).
func (c *SupabaseClient) post(ctx context.Context, path string, body any, dst any) error {
	b, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("marshal body: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+path, bytes.NewReader(b))
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	c.setHeaders(req)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("supabase POST %s: %w", path, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("supabase POST %s: status %d: %s", path, resp.StatusCode, string(body))
	}
	if dst != nil {
		return json.NewDecoder(resp.Body).Decode(dst)
	}
	return nil
}

// patch performs a PATCH request (row updates via PostgREST).
func (c *SupabaseClient) patch(ctx context.Context, path string, body any) error {
	b, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("marshal body: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPatch, c.baseURL+path, bytes.NewReader(b))
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	c.setHeaders(req)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("supabase PATCH %s: %w", path, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("supabase PATCH %s: status %d: %s", path, resp.StatusCode, string(body))
	}
	return nil
}

func (c *SupabaseClient) setHeaders(req *http.Request) {
	req.Header.Set("apikey", c.serviceKey)
	req.Header.Set("Authorization", "Bearer "+c.serviceKey)
	req.Header.Set("Accept", "application/json")
}

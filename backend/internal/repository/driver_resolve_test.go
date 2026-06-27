package repository

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestResolveDriverIDByUserID(t *testing.T) {
	const authUID = "c45374dd-347c-4f98-8fff-77e1a1e7741d"
	const driverID = "e2db2518-6a93-4828-8e51-e895040c4959"

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Query().Get("id") == "eq."+authUID:
			w.Header().Set("Content-Type", "application/json")
			_, _ = w.Write([]byte("[]"))
		case r.URL.Query().Get("user_id") == "eq."+authUID:
			w.Header().Set("Content-Type", "application/json")
			_ = json.NewEncoder(w).Encode([]map[string]string{{"id": driverID}})
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()

	client := NewSupabaseClient(srv.URL, "service-key")
	repo := NewDriverRepository(client)

	got, err := repo.ResolveDriverID(context.Background(), authUID)
	if err != nil {
		t.Fatalf("ResolveDriverID: %v", err)
	}
	if got != driverID {
		t.Fatalf("expected driver id %s, got %s", driverID, got)
	}
}

func TestResolveDriverIDDirect(t *testing.T) {
	const driverID = "e2db2518-6a93-4828-8e51-e895040c4959"

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("id") != "eq."+driverID {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode([]map[string]string{{"id": driverID}})
	}))
	defer srv.Close()

	client := NewSupabaseClient(srv.URL, "service-key")
	repo := NewDriverRepository(client)

	got, err := repo.ResolveDriverID(context.Background(), driverID)
	if err != nil {
		t.Fatalf("ResolveDriverID: %v", err)
	}
	if got != driverID {
		t.Fatalf("expected %s, got %s", driverID, got)
	}
}

func TestResolveDriverIDNotFound(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte("[]"))
	}))
	defer srv.Close()

	client := NewSupabaseClient(srv.URL, "service-key")
	repo := NewDriverRepository(client)

	_, err := repo.ResolveDriverID(context.Background(), "missing-user")
	if err == nil {
		t.Fatal("expected error")
	}
	if !errors.Is(err, ErrDriverNotFound) {
		t.Fatalf("expected ErrDriverNotFound, got %v", err)
	}
}

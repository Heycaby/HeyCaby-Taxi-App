package driverservice

import (
	"testing"
	"time"

	"github.com/heycaby/backend/internal/repository"
)

func ptrTime(t time.Time) *time.Time { return &t }

func TestBuildReadinessChecklistNLAllComplete(t *testing.T) {
	now := time.Now().UTC()
	exp := now.AddDate(0, 6, 0)
	c := &repository.DriverCompliance{
		ProfilePhotoURL:           "https://example.com/p.jpg",
		VehiclePhotoURLs:          []string{"https://example.com/v.jpg"},
		TermsAcceptedAt:           &now,
		IndemnificationReadAt:     &now,
		IndemnificationQuizPassed: true,
		KvkNumber:                 "12345678",
		KvkAddress:                "Dam 1, Amsterdam",
		ChauffeurspasNumber:       "12345678901",
		ChauffeurspasExpiry:       &exp,
		TaxiInsuranceProvider:     "InsCo",
		TaxiInsurancePolicyNumber: "POL-99",
		TaxiInsurancePhotoURL:     "https://example.com/ins.jpg",
		TaxiInsuranceExpiry:       &exp,
		VehiclePlate:              "AB-12-CD",
		RijbewijsVerified:         true,
	}
	items := buildReadinessChecklist(c, "NL")
	missing := missingFromChecklist(items)
	if len(missing) != 0 {
		t.Fatalf("expected no missing, got %v", missing)
	}
}

func TestBuildReadinessChecklistNLMissingTermsAndQuiz(t *testing.T) {
	now := time.Now().UTC()
	exp := now.AddDate(0, 6, 0)
	c := &repository.DriverCompliance{
		ProfilePhotoURL:           "https://example.com/p.jpg",
		VehiclePhotoURLs:          []string{"https://example.com/v.jpg"},
		TermsAcceptedAt:           nil,
		IndemnificationReadAt:     nil,
		IndemnificationQuizPassed: false,
		KvkNumber:                 "12345678",
		KvkAddress:                "Dam 1",
		ChauffeurspasNumber:       "12345678901",
		ChauffeurspasExpiry:       &exp,
		TaxiInsuranceProvider:     "InsCo",
		TaxiInsurancePolicyNumber: "POL-99",
		TaxiInsurancePhotoURL:     "https://example.com/ins.jpg",
		TaxiInsuranceExpiry:       &exp,
		VehiclePlate:              "AB-12-CD",
		RijbewijsVerified:         true,
	}
	items := buildReadinessChecklist(c, "NL")
	missing := missingFromChecklist(items)
	if len(missing) < 2 {
		t.Fatalf("expected multiple missing keys, got %v", missing)
	}
}

func TestNLRijbewijsMustBeVerified(t *testing.T) {
	now := time.Now().UTC()
	exp := now.AddDate(0, 6, 0)
	c := &repository.DriverCompliance{
		ProfilePhotoURL:           "https://example.com/p.jpg",
		VehiclePhotoURLs:          []string{"https://example.com/v.jpg"},
		TermsAcceptedAt:           &now,
		IndemnificationReadAt:     &now,
		IndemnificationQuizPassed: true,
		KvkNumber:                 "12345678",
		KvkAddress:                "Dam 1",
		ChauffeurspasNumber:       "12345678901",
		ChauffeurspasExpiry:       &exp,
		TaxiInsuranceProvider:     "InsCo",
		TaxiInsurancePolicyNumber: "POL-99",
		TaxiInsurancePhotoURL:     "https://example.com/ins.jpg",
		TaxiInsuranceExpiry:       &exp,
		VehiclePlate:              "AB-12-CD",
		RijbewijsVerified:         false,
	}
	items := buildReadinessChecklist(c, "NL")
	missing := missingFromChecklist(items)
	found := false
	for _, k := range missing {
		if k == "rijbewijs_verified" {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("expected rijbewijs_verified in missing, got %v", missing)
	}
}

func TestNlTaxiInsuranceIncompleteWithoutPhoto(t *testing.T) {
	now := time.Now().UTC()
	c := &repository.DriverCompliance{
		TaxiInsuranceProvider:     "InsCo",
		TaxiInsurancePolicyNumber: "POL-99",
		TaxiInsurancePhotoURL:     "",
		TaxiInsuranceExpiry:       &now,
	}
	if nlTaxiInsuranceComplete(c) {
		t.Fatal("expected incomplete without photo URL")
	}
}

func TestMissingRequiredV2OnlyPlateTermsQuiz(t *testing.T) {
	now := time.Now().UTC()
	c := &repository.DriverCompliance{
		TermsAcceptedAt:           &now,
		IndemnificationReadAt:     &now,
		IndemnificationQuizPassed: true,
		KvkNumber:                 "",
		ChauffeurspasNumber:       "",
		TaxiInsuranceProvider:     "",
		VehiclePlate:              "",
		RijbewijsVerified:         false,
	}
	items := annotateChecklistDeferredV2(buildReadinessChecklist(c, "NL"), 0)
	missing := missingRequiredV2(items)
	if len(missing) != 1 || missing[0] != "vehicle_plate" {
		t.Fatalf("expected only vehicle_plate missing, got %v", missing)
	}
}

func TestMissingRequiredV2NoneWhenMinimumMet(t *testing.T) {
	now := time.Now().UTC()
	c := &repository.DriverCompliance{
		TermsAcceptedAt:           &now,
		IndemnificationReadAt:     &now,
		IndemnificationQuizPassed: true,
		VehiclePlate:              "AB-12-CD",
		RijbewijsVerified:         false,
		KvkNumber:                 "",
	}
	items := buildReadinessChecklist(c, "NL")
	missing := missingRequiredV2(items)
	if len(missing) != 0 {
		t.Fatalf("expected no V2 required missing, got %v", missing)
	}
}

func TestAnnotateChecklistDeferredV2AddsNote(t *testing.T) {
	items := []ReadinessItem{
		{Key: "kvk_number", Complete: false, Note: ""},
		{Key: "vehicle_plate", Complete: false, Note: ""},
	}
	out := annotateChecklistDeferredV2(items, 0)
	if out[0].Note == "" {
		t.Fatal("expected deferred note on kvk_number")
	}
	if out[1].Note != "" {
		t.Fatal("required incomplete item should not get deferred note")
	}
}

func TestOnboardingV2RequiredKeysAtMilestone20(t *testing.T) {
	keys := onboardingV2RequiredKeysFor(20)
	for _, k := range []string{"vehicle_plate", "kvk_number", "chauffeurspas"} {
		if _, ok := keys[k]; !ok {
			t.Fatalf("expected %s required at 20 rides", k)
		}
	}
	if _, ok := keys["taxi_insurance"]; ok {
		t.Fatal("insurance should not be required at exactly 20 rides")
	}
}

func TestOnboardingV2RequiredKeysAtMilestone50(t *testing.T) {
	keys := onboardingV2RequiredKeysFor(50)
	for _, k := range []string{"taxi_insurance", "rijbewijs_verified"} {
		if _, ok := keys[k]; !ok {
			t.Fatalf("expected %s required at 50 rides", k)
		}
	}
}

func TestOnboardingV2NextMilestone(t *testing.T) {
	if onboardingV2NextMilestone(0) != 20 {
		t.Fatal("expected next milestone 20")
	}
	if onboardingV2NextMilestone(25) != 50 {
		t.Fatal("expected next milestone 50")
	}
	if onboardingV2NextMilestone(50) != 0 {
		t.Fatal("expected no next milestone after 50")
	}
}

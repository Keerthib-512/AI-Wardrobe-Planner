#!/bin/bash
# One-time setup: creates a dedicated service account GitHub Actions will use
# to deploy to Cloud Run, and grants it exactly the permissions it needs.
# Run this once, locally, with the same gcloud account used for the manual deploy.
set -e
 
PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
CICD_SA="github-cicd@${PROJECT_ID}.iam.gserviceaccount.com"
 
echo "Project: $PROJECT_ID"
 
# 1. Create the service account GitHub Actions will authenticate as.
gcloud iam service-accounts create github-cicd \
  --display-name="GitHub Actions CI/CD"
 
# 2. Let it deploy new revisions to Cloud Run.
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${CICD_SA}" \
  --role="roles/run.admin"
 
# 3. Let it trigger the Cloud Build that `gcloud run deploy --source .` runs
#    under the hood (builds the container from the Dockerfile).
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${CICD_SA}" \
  --role="roles/cloudbuild.builds.editor"
 
# 4. Let it push the built image to Artifact Registry.
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${CICD_SA}" \
  --role="roles/artifactregistry.writer"
 
# 5. Let it "act as" the Cloud Run runtime service account — required to
#    deploy a service that itself runs as another identity.
gcloud iam service-accounts add-iam-policy-binding \
  "${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --member="serviceAccount:${CICD_SA}" \
  --role="roles/iam.serviceAccountUser"
 
# 6. Create a key file. GitHub will use this to authenticate as the
#    service account (see note below on a keyless alternative).
gcloud iam service-accounts keys create github-cicd-key.json \
  --iam-account="${CICD_SA}"
 
echo ""
echo "Done. Now add two repo secrets on GitHub:"
echo "  Settings -> Secrets and variables -> Actions -> New repository secret"
echo ""
echo "  GCP_PROJECT_ID = ${PROJECT_ID}"
echo "  GCP_SA_KEY     = <paste the full contents of github-cicd-key.json>"
echo ""
echo "Then delete github-cicd-key.json locally once it's pasted into GitHub — don't commit it."
echo ""
echo "Note: a JSON key is the simplest way to demo this, but it's a long-lived"
echo "credential. For anything beyond a class project, swap this for Workload"
echo "Identity Federation (google-github-actions/auth supports it directly) —"
echo "it authenticates GitHub Actions to GCP with no stored key at all."
 

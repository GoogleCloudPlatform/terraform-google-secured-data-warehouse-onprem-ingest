/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

resource "google_project_iam_member" "bq_project_dlp_admin" {
  project = var.bq_project_id
  role    = "roles/dlp.admin"
  member  = "serviceAccount:${var.terraform_service_account}"
}

resource "google_project_iam_member" "dlp_project_dlp_admin" {
  project = var.dlp_project_id
  role    = "roles/dlp.admin"
  member  = "serviceAccount:${var.terraform_service_account}"
}

resource "google_project_service_identity" "dlp_identity_sa" {
  provider = google-beta

  project = var.dlp_project_id
  service = "dlp.googleapis.com"
}

resource "google_project_iam_member" "dlp_admin_service_agent" {
  project = var.dlp_project_id
  role    = "roles/dlp.admin"
  member  = "serviceAccount:${google_project_service_identity.dlp_identity_sa.email}"
}

resource "google_project_iam_member" "bq_admin_service_agent" {
  project = var.bq_project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${google_project_service_identity.dlp_identity_sa.email}"
}

resource "time_sleep" "iam_propagation" {
  create_duration = "120s"

  depends_on = [
    google_project_iam_member.bq_project_dlp_admin,
    google_project_iam_member.dlp_project_dlp_admin,
    google_project_iam_member.dlp_admin_service_agent,
    google_project_iam_member.bq_admin_service_agent
  ]
}

resource "google_data_loss_prevention_job_trigger" "dlp_job_trigger" {
  parent       = "projects/${var.dlp_project_id}/locations/${var.dlp_location}"
  description  = "DLP trigger to scan the entire BigQuery table."
  display_name = "dlp_scanner_job_trigger"

  triggers {
    schedule {
      recurrence_period_duration = "${var.dlp_recurrence_period_duration}s"
    }
  }

  inspect_job {
    inspect_template_name = var.dlp_inspect_template_id
    actions {
      save_findings {
        output_config {
          table {
            project_id = var.dlp_project_id
            dataset_id = var.dlp_output_dataset
          }
        }
      }
    }

    storage_config {
      big_query_options {
        table_reference {
          project_id = var.bq_project_id
          dataset_id = var.bq_dataset_id
          table_id   = var.bq_table_id
        }
        sample_method = "" # forces a full table scan
      }
    }
  }

  depends_on = [
    time_sleep.iam_propagation
  ]
}

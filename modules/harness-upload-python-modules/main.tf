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

resource "null_resource" "upload_modules" {

  triggers = {
    project_id                = var.project_id
    repository_id             = var.python_repository_id
    location                  = var.location
    terraform_service_account = var.service_account_email
  }

  provisioner "local-exec" {
    when    = create
    command = <<EOF
     gcloud builds submit \
     --project=${var.project_id} \
     --gcs-source-staging-dir="gs://${var.cloudbuild_bucket_name}/source" \
     --config ${path.module}/files/cloudbuild.yaml \
     --impersonate-service-account=${var.service_account_email} \
     --substitutions=_REPOSITORY_ID=${var.python_repository_id},_DEFAULT_REGION=${var.location} \
     ${path.module}/files
EOF

  }
}

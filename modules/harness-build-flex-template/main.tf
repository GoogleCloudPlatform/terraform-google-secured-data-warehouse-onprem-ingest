/**
 * Copyright 2023-2025 Google LLC
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

locals {
  image_name              = "pubsub-dataflow-bigquery-flex"
  flex_template_image_tag = "${var.docker_repository_url}/samples/${local.image_name}:latest"
  template_gs_path        = "gs://${var.flex_template_bucket_name}/flex-template-samples/${local.image_name}.json"
}

resource "null_resource" "python_pubsub_dataflow_bq_flex_template" {

  triggers = {
    project_id                = var.project_id
    terraform_service_account = var.service_account_email
    template_image_tag        = local.flex_template_image_tag
    template_gs_path          = local.template_gs_path
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOF
      gcloud builds submit \
        --project=${var.project_id} \
        --gcs-source-staging-dir="gs://${var.cloudbuild_bucket_name}/source" \
        --config ${path.module}/pubsub_dataflow_bigquery/cloudbuild.yaml \
        --service-account=projects/${var.project_id}/serviceAccounts/${var.service_account_email} \
        --substitutions="_PROJECT=${var.project_id},_FLEX_TEMPLATE_IMAGE_TAG=${local.flex_template_image_tag},_PIP_INDEX_URL=${var.pip_index_url},_TEMPLATE_GS_PATH=${local.template_gs_path}" \
        ${path.module}/pubsub_dataflow_bigquery
EOF

  }
}

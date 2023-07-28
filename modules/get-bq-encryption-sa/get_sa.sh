#!/bin/bash

# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Exit if any of the intermediate steps fail
set -e

# Extract arguments from the input.
eval "$(jq -r '@sh "project_id=\(.project_id) terraform_service_account=\(.terraform_service_account)"')"

# Get the service account for a project used for BigQuery interactions with Google Cloud KMS
# Disabling SC2154: 'variable is referenced but not assigned' because the values are read with the eval command
# shellcheck disable=SC2154
curl -s "https://bigquery.googleapis.com/bigquery/v2/projects/${project_id}/serviceAccount" \
--header "Authorization: Bearer $(gcloud auth print-access-token --verbosity error --impersonate-service-account="${terraform_service_account}")" \
--header "Accept: application/json"

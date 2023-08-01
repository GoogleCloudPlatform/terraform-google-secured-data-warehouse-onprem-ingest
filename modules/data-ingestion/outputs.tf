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

output "data_ingestion_bucket_name" {
  description = "The name of the bucket created for data ingestion pipeline."
  value       = module.data_ingestion_bucket.bucket.name
}

output "data_ingestion_dataflow_bucket_name" {
  description = "The name of the bucket created for dataflow in the data ingestion pipeline."
  value       = module.dataflow_bucket.bucket.name
}

output "data_ingestion_cloudfunction_bucket_name" {
  description = "The name of the bucket created for cloud function in the data ingestion pipeline."
  value       = module.cloudfunction_bucket.bucket.name
}

output "data_ingestion_topic_name" {
  description = "The topic created for data ingestion pipeline."
  value       = module.data_ingestion_topic.topic
}

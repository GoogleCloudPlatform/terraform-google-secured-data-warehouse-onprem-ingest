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

import os
from google.cloud import bigquery
from logger_config import configure_logger, update_correlation_id

LOGGER = configure_logger('main')


def csv_loader(data, context):

    update_correlation_id()
    DATASET_PROJECT = os.environ['DATASET_PROJECT_ID']
    client = bigquery.Client(project=DATASET_PROJECT)
    dataset_id = os.environ['DATASET']
    table_id = os.environ['TABLE']
    dataset_ref = client.dataset(dataset_id)

    job_config = bigquery.LoadJobConfig()
    table_ref = dataset_ref.table(table_id)
    table = client.get_table(table_ref)

    job_config.schema = table.schema
    job_config.skip_leading_rows = 1
    job_config.source_format = bigquery.SourceFormat.CSV
    job_config.write_disposition = bigquery.WriteDisposition.WRITE_APPEND
    job_config.schema_update_options = [
        bigquery.SchemaUpdateOption.ALLOW_FIELD_ADDITION,
        bigquery.SchemaUpdateOption.ALLOW_FIELD_RELAXATION
    ]
    # get the URI for uploaded CSV in GCS from 'data'
    uri = 'gs://' + os.environ['BUCKET'] + '/' + data['name']
    # lets do this
    load_job = client.load_table_from_uri(
        uri,
        table,
        job_config=job_config)
    LOGGER.info('Starting job {}'.format(load_job.job_id))
    LOGGER.info('File name: {}'.format(data['name']))
    load_job.result()  # wait for table load to complete.
    LOGGER.info('Job finished.')

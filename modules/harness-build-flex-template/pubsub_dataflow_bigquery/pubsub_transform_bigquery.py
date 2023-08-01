# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from __future__ import absolute_import

import argparse
import json
import logging

import apache_beam as beam
import apache_beam.transforms.window as window
from apache_beam.options.pipeline_options import PipelineOptions


def run(argv=None, save_main_session=True):
    """Build and run the pipeline."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--output_table',
        required=True,
        help=(
            'Output BigQuery table for results specified as: '
            'PROJECT:DATASET.TABLE or DATASET.TABLE.'
        )
    )
    parser.add_argument(
        '--bq_schema',
        required=True,
        help=(
            'Output BigQuery table schema specified as string with format: '
            'FIELD_1:STRING,FIELD_2:STRING,...'
        )
    )
    parser.add_argument(
        "--window_interval_sec",
        default=30,
        type=int,
        help=(
            'Window interval in seconds for grouping incoming messages.'
        )
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        '--input_topic',
        help=(
            'Input PubSub topic of the form '
            '"projects/<PROJECT>/topics/<TOPIC>".'
            'A temporary subscription will be created from '
            'the specified topic.'
        )
    )
    group.add_argument(
        '--input_subscription',
        help=(
            'Input PubSub subscription of the form '
            '"projects/<PROJECT>/subscriptions/<SUBSCRIPTION>."'
        )
    )
    known_args, pipeline_args = parser.parse_known_args(argv)

    options = PipelineOptions(
        pipeline_args,
        save_main_session=True,
        streaming=True
    )

    with beam.Pipeline(options=options) as p:

        # Read from PubSub into a PCollection.
        # If input_subscription provided, it will be used.
        # If input_subscription not provided, input_topic will be used.
        # If input_topic provided, a temporary subscription will be created
        # from the specified topic.
        if known_args.input_subscription:
            messages = (
                p
                | 'Read from Pub/Sub' >>
                beam.io.ReadFromPubSub(
                    subscription=known_args.input_subscription
                ).with_output_types(bytes)
                | 'UTF-8 bytes to string' >>
                beam.Map(lambda msg: msg.decode("utf-8"))
                | 'Parse JSON payload' >>
                beam.Map(json.loads)
                | 'Flatten lists' >>
                beam.FlatMap(normalize_data)
                | 'Apply window' >> beam.WindowInto(
                    window.FixedWindows(known_args.window_interval_sec, 0)
                )
            )
        else:
            messages = (
                p
                | 'Read from Pub/Sub' >>
                beam.io.ReadFromPubSub(
                    topic=known_args.input_topic
                ).with_output_types(bytes)
                | 'UTF-8 bytes to string' >>
                beam.Map(lambda msg: msg.decode("utf-8"))
                | 'Parse JSON payload' >>
                beam.Map(json.loads)
                | 'Flatten lists' >>
                beam.FlatMap(normalize_data)
                | 'Apply window' >> beam.WindowInto(
                    window.FixedWindows(known_args.window_interval_sec, 0)
                )
            )

        transformed_messages = (
            messages
            | 'Data transformation' >> beam.Map(transform_data)
            )

        # Write to BigQuery.
        transformed_messages | 'Write to BQ' >> beam.io.WriteToBigQuery(
            known_args.output_table,
            schema=known_args.bq_schema,
            create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED
        )


def normalize_data(data):
    """
    The template reads a json from PubSub that can be a single object
    or a List of objects. This function is used by a FlatMap transformation
    to normalize the input in to individual objects.
    See:
     - https://beam.apache.org/documentation/transforms/python/elementwise/flatmap/
    """  # noqa
    if isinstance(data, list):
        return data
    return [data]


def transform_data(message):
    """
    The "message" input is a json object representing the data
    read from the Pub/Sub subscription or topic.
    Replace this code example with your own data transformation.
    """
    message['Issue_Date'] = message['Issue_Date'].replace("/", "-")
    return message


if __name__ == '__main__':
    logging.getLogger().setLevel(logging.INFO)
    run()

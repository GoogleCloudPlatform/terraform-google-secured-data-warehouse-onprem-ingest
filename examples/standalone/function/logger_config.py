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

import logging
import sys
import os
from uuid import uuid4
from pythonjsonlogger import jsonlogger

VERSION = os.getenv('VERSION', "1.0")
LOGGER_LEVEL = logging.getLevelName(os.getenv('LOGGER_LEVEL', "INFO"))
LOGGER_FORMAT = '%(module)s - %(levelname)s - %(message)s'

full_correlation_id = None
short_correlation_id = None


class _MaxLevelFilter(object):
    def __init__(self, highest_log_level):
        self._highest_log_level = highest_log_level

    def filter(self, log_record):
        return log_record.levelno <= self._highest_log_level


class _StackdriverJsonFormatter(jsonlogger.JsonFormatter, object):
    def __init__(self, fmt=LOGGER_FORMAT, style='%', *args, **kwargs):
        jsonlogger.JsonFormatter.__init__(self, fmt=fmt, *args, **kwargs)

    def process_log_record(self, log_record, **kwargs):
        log_record['severity'] = log_record['levelname']
        log_record['correlation_id'] = full_correlation_id
        del log_record['levelname']
        log_record['message'] = "[{}-v{}] - {} - {} - {} - {}".format(
            'csv_loader',
            VERSION,
            log_record['severity'],
            short_correlation_id,
            log_record['module'],
            log_record['message']
        )
        for key, value in kwargs.items():
            log_record.append(key)
            log_record[key] = kwargs[value]
        return super(_StackdriverJsonFormatter,
                     self).process_log_record(log_record)


LOGGER_FORMATTER = _StackdriverJsonFormatter()


def configure_logger(module_name):
    # A handler for low level logs that should be sent to STDOUT
    info_handler = logging.StreamHandler(sys.stdout)
    info_handler.setLevel(logging.DEBUG)
    info_handler.addFilter(_MaxLevelFilter(logging.WARNING))
    info_handler.setFormatter(LOGGER_FORMATTER)

    # A handler for high level logs that should be sent to STDERR
    error_handler = logging.StreamHandler(sys.stderr)
    error_handler.setLevel(logging.ERROR)
    error_handler.setFormatter(LOGGER_FORMATTER)

    logger = logging.getLogger(module_name)
    logger.setLevel(LOGGER_LEVEL)
    logger.addHandler(info_handler)
    logger.addHandler(error_handler)
    return logger


def update_correlation_id():
    global full_correlation_id
    global short_correlation_id
    full_correlation_id = uuid4().hex
    short_correlation_id = full_correlation_id[:8]

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

# Install mock tinkey command for testing
set -e
set -u

cd /workspace/test/setup/tinkey-mock
go build -buildvcs=false .

# Install the mock for tinkey in the path
install -o 0 -g 0 -m 0755 ./tinkey-mock /usr/bin/
install -o 0 -g 0 -m 0755 ./tinkey /usr/bin/

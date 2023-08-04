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

set -e
set -u

file_name=$(cat - | jq '.key_file' --raw-output)
encryptedKeyset=$(jq '.encryptedKeyset' --raw-output < "$file_name" | base64 - --decode --wrap 0 | od -An --format=o1 - | tr -d '\n' | sed -e 's/\s/\\\\/g')
jq -n --arg encryptedKeyset "$encryptedKeyset" '{"encryptedKeyset":"'"$encryptedKeyset"'"}'

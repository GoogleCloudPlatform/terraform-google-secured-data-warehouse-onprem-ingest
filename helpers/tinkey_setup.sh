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

# Tinkey documentation:
# https://github.com/google/tink/blob/master/docs/TINKEY.md

function check_java() {
    printf "Checking Java..."
    java_bin=$(command -v java)
    if [[ -z "${java_bin}" ]]; then
        printf "\nJava must be installed before proceeding with Tinkey setup.\n"
        exit 1
    else
        printf "\nJava already installed at %s\n" "${java_bin}"
    fi
}

function check_tinkey() {
    printf "\nChecking Tinkey..."
    t_sh=$(command -v tinkey)
    t_jar=$(command -v tinkey_deploy.jar)
    if [[ -n "$t_sh" && -n "$t_jar" ]]; then
        printf "\nTinkey already installed at %s\n" "${t_sh}"
        exit 1
    else
         printf "\nTinkey not installed.\n"
    fi
}

function install_tinkey() {
    tinkey_version="${TINKEY_VERSION:-"1.7.0"}"
    temp_folder="tinkey-${tinkey_version}"
    tinkey_directory="${TINKEY_DIRECTORY:-"/usr/bin"}"

    printf "\nCreating temporary folder %s" "${temp_folder}"
    mkdir -p "${temp_folder}"
    cd "${temp_folder}" || { printf "Failure to 'cd' to temporary directory %s" "${temp_folder}"; return; }

    printf "\nDownloading Tinkey version %s\n\n", "${tinkey_version}"
    wget -c "https://storage.googleapis.com/tinkey/tinkey-${tinkey_version}.tar.gz" -nv -O - | tar -xz

    printf "\nInstalling Tinkey version %s on directory %s\n", "${tinkey_version}", "${tinkey_directory}"
    sudo install -v tinkey tinkey_deploy.jar "${tinkey_directory}"

    printf "\nDeleting temporary folder %s\n", "${temp_folder}"
    cd ..
    rm -rf "${temp_folder}"
}

function print_usage() {
    printf "Tinkey tool setup. See https://github.com/google/tink/blob/master/docs/TINKEY.md"
    printf "\nusage: tinkey_setup.sh [ -h ] [ -v=VERSION ] [ -d=DIRECTORY ]"
    printf "\n  -h              print this message"
    printf "\n  -d=DIRECTORY    custom installation directory. Default: /usr/bin\n"
    printf "\n  -v=VERSION      custom Tinkey version. Default: 1.7.0\n"
}

while getopts ":d:v:h" arg; do
  case ${arg} in
    h) print_usage
       exit 1 ;;
    d) TINKEY_DIRECTORY="${OPTARG}" ;;
    v) TINKEY_VERSION="${OPTARG}" ;;
    \?)
      printf "Invalid option: -%s\n" "${OPTARG}" >&2
      print_usage
      exit 1
      ;;
    :)
      printf "Option -%s requires a parameter\n" "${OPTARG}" >&2
      print_usage
      exit 1
      ;;
  esac
done

check_java
check_tinkey
install_tinkey

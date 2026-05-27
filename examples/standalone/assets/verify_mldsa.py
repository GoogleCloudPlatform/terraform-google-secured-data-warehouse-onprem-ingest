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

from google.cloud import kms
import os
import base64
import subprocess
import time
import random
import string

print("Importing OQS module... (It takes some minutes)")
old_stdout = os.dup(1)
old_stderr = os.dup(2)
black_hole = os.open(os.devnull, os.O_WRONLY)
os.dup2(black_hole, 1)
os.dup2(black_hole, 2)
import oqs
os.dup2(old_stdout, 1)
os.dup2(old_stderr, 2)
os.close(black_hole)
print("OQS module imported.")


def sign_with_cloud_kms(project_id, location_id, key_ring_id, key_id, version_id, message_bytes: bytes):
    """Requests Google KMS to sign the raw message using ML-DSA."""
    client = kms.KeyManagementServiceClient()
    key_version_name = client.crypto_key_version_path(
        project_id, location_id, key_ring_id, key_id, version_id
    )

    request = kms.AsymmetricSignRequest(
        name=key_version_name,
        data=message_bytes
    )

    print(f"Requesting ML-DSA signature for key {key_id} from Cloud KMS...")
    response = client.asymmetric_sign(request=request)
    return response.signature

def get_public_key_from_kms(project_id, location_id, key_ring_id, key_id, version_id):
    """Fetches the public key from KMS to share with the verifier."""
    client = kms.KeyManagementServiceClient()
    key_version_name = client.crypto_key_version_path(
        project_id, location_id, key_ring_id, key_id, version_id
    )

    print(f"Fetching public key for {key_id} from Cloud KMS...")
    response = client.get_public_key(name=key_version_name)
    return response.pem

def verify_locally_with_oqs(message_bytes: bytes, signature_bytes: bytes, public_key_pem: str):
    """Verifies the Cloud KMS signature locally using liboqs."""

    pem_lines = public_key_pem.strip().split('\n')
    if "BEGIN" in pem_lines[0]:
        pem_lines = pem_lines[1:-1]
    raw_pub_key_spki = base64.b64decode(''.join(pem_lines))

    with oqs.Signature("ML-DSA-87") as verifier:
        print(f"DEBUG: Type of verifier object: {type(verifier)}")
        print(f"DEBUG: verifier.details: {verifier.details}")

        expected_public_key_len = verifier.details.get('length_public_key')
        expected_signature_len = verifier.details.get('length_signature')

        if expected_public_key_len is None:
            raise ValueError(f"Could not determine expected public key length from OQS verifier. Check 'length_public_key' in verifier.details: {verifier.details}")
        if expected_signature_len is None:
            raise ValueError(f"Could not determine expected signature length from OQS verifier. Check 'length_signature' in verifier.details: {verifier.details}")

        if len(raw_pub_key_spki) >= expected_public_key_len:
            raw_pub_key_material = raw_pub_key_spki[-expected_public_key_len:]
            print(f"DEBUG: Extracted raw public key material (suffix): {len(raw_pub_key_material)} bytes")
        else:
            print(f"WARNING: raw_pub_key_spki ({len(raw_pub_key_spki)} bytes) is shorter than expected by OQS ({expected_public_key_len} bytes). Using the full SPKI for verification attempt.")
            raw_pub_key_material = raw_pub_key_spki

        is_valid = verifier.verify(message_bytes, signature_bytes, raw_pub_key_material)

        if is_valid:
            print("Success! The ML-DSA signature is valid and authentic.")
        else:
            print("Failure! The signature could not be verified.")

if __name__ == "__main__":
    # --- Configuration ---

    # Get PROJECT_ID directly from gcloud config
    try:
        PROJECT_ID_RAW = subprocess.run(
            ["gcloud", "config", "get-value", "project"],
            capture_output=True, text=True, check=True
        ).stdout
        PROJECT_ID = PROJECT_ID_RAW.strip()
        print(f"DEBUG: PROJECT_ID obtained via gcloud config: {PROJECT_ID}")
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Failed to get PROJECT_ID via gcloud config: {e}")
        print("Please ensure that gcloud CLI is configured and authenticated.")
        exit(1)

    KMS_LOCATION = os.environ.get("REGION", "us-central1")
    print(f"DEBUG: KMS_LOCATION (REGION) being used: {KMS_LOCATION}")

    PQC_SIGNATURE_KEYRING_NAME = "my-pqc-keyring"
    PQC_SIGNATURE_KEY_NAME = "pqc-safe-rsa-key"
    VERSION_ID = "1"

    random_suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
    BUCKET_NAME = f"{PROJECT_ID}-pqc-signed-data-{random_suffix}" # Bucket for data and signature
    MESSAGE_FILENAME = "message.txt"
    SIGNATURE_FILENAME = "message.sig"
    DOWNLOADED_MESSAGE_FILENAME = "downloaded_message.txt"
    DOWNLOADED_SIGNATURE_FILENAME = "downloaded_signature.sig"

    ORIGINAL_DATA_CONTENT = b"This is a quantum-safe integrity protected message."
    print(f"Original message content: '{ORIGINAL_DATA_CONTENT.decode()}'")

    try:
        with open(MESSAGE_FILENAME, "wb") as f:
            f.write(ORIGINAL_DATA_CONTENT)
        print(f"Created local message file: {MESSAGE_FILENAME}")

        signature = sign_with_cloud_kms(
            PROJECT_ID, KMS_LOCATION, PQC_SIGNATURE_KEYRING_NAME, PQC_SIGNATURE_KEY_NAME, VERSION_ID, ORIGINAL_DATA_CONTENT
        )
        print(f"Signature generated (first 32 bytes): {signature[:32].hex()}...")

        with open(SIGNATURE_FILENAME, "wb") as f:
            f.write(signature)
        print(f"Saved local signature file: {SIGNATURE_FILENAME}")

        print(f"Creating Cloud Storage bucket: gs://{BUCKET_NAME}")
        subprocess.run(["gcloud", "storage", "buckets", "create", f"gs://{BUCKET_NAME}", "--project", PROJECT_ID, "--location", "US-CENTRAL1"], check=True, capture_output=True)
        print(f"Bucket gs://{BUCKET_NAME} created.")

        print(f"Uploading {MESSAGE_FILENAME} and {SIGNATURE_FILENAME} to gs://{BUCKET_NAME}")
        subprocess.run(["gcloud", "storage", "cp", MESSAGE_FILENAME, f"gs://{BUCKET_NAME}/{MESSAGE_FILENAME}"], check=True)
        subprocess.run(["gcloud", "storage", "cp", SIGNATURE_FILENAME, f"gs://{BUCKET_NAME}/{SIGNATURE_FILENAME}"], check=True)
        print("Files uploaded to Cloud Storage.")

        print(f"Downloading {MESSAGE_FILENAME} and {SIGNATURE_FILENAME} from gs://{BUCKET_NAME}")
        subprocess.run(["gcloud", "storage", "cp", f"gs://{BUCKET_NAME}/{MESSAGE_FILENAME}", DOWNLOADED_MESSAGE_FILENAME], check=True)
        subprocess.run(["gcloud", "storage", "cp", f"gs://{BUCKET_NAME}/{SIGNATURE_FILENAME}", DOWNLOADED_SIGNATURE_FILENAME], check=True)
        print("Files downloaded from Cloud Storage for verification.")

        with open(DOWNLOADED_MESSAGE_FILENAME, "rb") as f:
            downloaded_message = f.read()
        with open(DOWNLOADED_SIGNATURE_FILENAME, "rb") as f:
            downloaded_signature = f.read()

        pub_key_pem = get_public_key_from_kms(
            PROJECT_ID, KMS_LOCATION, PQC_SIGNATURE_KEYRING_NAME, PQC_SIGNATURE_KEY_NAME, VERSION_ID
        )
        print(f"Public Key (PEM format, first 64 characters): {pub_key_pem[:64]}...")

        print("\n--- Verifying Downloaded Files ---")
        verify_locally_with_oqs(downloaded_message, downloaded_signature, pub_key_pem)

        os.remove(MESSAGE_FILENAME)
        os.remove(SIGNATURE_FILENAME)
        os.remove(DOWNLOADED_MESSAGE_FILENAME)
        os.remove(DOWNLOADED_SIGNATURE_FILENAME)
        print("Cleaned up local files.")

    except subprocess.CalledProcessError as e:
        print(f"\nError during GCloud/GSUtil command execution: {e.cmd}")
        print(f"Stderr: {e.stderr.decode()}")
        print(f"Stdout: {e.stdout.decode()}")
        print("Please check your gcloud/gsutil configuration and permissions for Cloud Storage.")
        print(f"Attempting to delete Cloud Storage bucket: gs://{BUCKET_NAME} in case of error...")
        try:
            subprocess.run(["gcloud", "storage", "rm", "--recursive", f"gs://{BUCKET_NAME}", "--project", PROJECT_ID], check=True, capture_output=True)
            print(f"Bucket gs://{BUCKET_NAME} deleted in error cleanup.")
        except subprocess.CalledProcessError as cleanup_e:
            print(f"WARNING: Could not delete bucket {BUCKET_NAME} during error cleanup. Please delete it manually if necessary.")
            print(f"Stderr (cleanup): {cleanup_e.stderr.decode()}")
    except Exception as e:
        print(f"\nError during PQC signature process: {e.__class__.__name__}: {e}")
        print("Please ensure your KMS key is configured correctly and your user has 'Cloud KMS CryptoKey Signer/Verifier' permissions for the key.")
        print(f"Attempting to delete Cloud Storage bucket: gs://{BUCKET_NAME} in case of error...")
        try:
            subprocess.run(["gcloud", "storage", "rm", "--recursive", f"gs://{BUCKET_NAME}", "--project", PROJECT_ID], check=True, capture_output=True)
            print(f"Bucket gs://{BUCKET_NAME} deleted in error cleanup.")
        except subprocess.CalledProcessError as cleanup_e:
            print(f"WARNING: Could not delete bucket {BUCKET_NAME} during error cleanup. Please delete it manually if necessary.")
            print(f"Stderr (cleanup): {cleanup_e.stderr.decode()}")

    finally:
        time.sleep(5)
        print("\nFinal cleanup attempt for data/signature Cloud Storage bucket (if not already deleted)...")
        try:
            subprocess.run(["gcloud", "storage", "buckets", "describe", f"gs://{BUCKET_NAME}", "--project", PROJECT_ID], check=True, capture_output=True)
            print(f"Bucket {BUCKET_NAME} still exists. Attempting to delete...")
            subprocess.run(["gcloud", "storage", "rm", "--recursive", f"gs://{BUCKET_NAME}", "--project", PROJECT_ID], check=True, capture_output=True)
            print(f"Bucket gs://{BUCKET_NAME} deleted by final cleanup.")
        except subprocess.CalledProcessError as cleanup_e:
            stderr_output = cleanup_e.stderr.decode()
            stdout_output = cleanup_e.stdout.decode()
            if "BucketNotFound" in stderr_output or "BucketNotFound" in stdout_output:
                print(f"Bucket {BUCKET_NAME} already deleted or never existed. No action needed.")
            else:
                print(f"WARNING: Could not delete bucket {BUCKET_NAME} in final cleanup. Please delete it manually if necessary.")
                print(f"Stderr (final cleanup): {stderr_output}")
                print(f"Stdout (final cleanup): {stdout_output}")

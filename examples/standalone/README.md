# Standalone example

This example:
- Presents the deploy of the blueprint for ingesting encrypted data from on-premises environments.
- Uses the [Tink](https://developers.google.com/tink) library to encrypt data "on prem" that will be Uploaded or streamed to BigQuery.
- Demonstrates the usage of BigQuery [AEAD encryption](https://cloud.google.com/bigquery/docs/reference/standard-sql/aead-encryption-concepts) functions to decrypt the on-premises data in BigQuery.

This example also create the resources that are required to deploy the blueprint that are expected to be provided by the user, we call these resources *external harness*.

In the External Harness we have:

- The creation of the three GCP projects needed by the Blueprint:
  - Data Ingestion project.
  - Data Governance project.
  - Data project.
- The creation of an external Artifact Registry project for the dataflow flex templates and the build of the templates themselves, including:
  - A Docker Artifact registry.
  - A Python Artifact registry.
- The creation of a VPC Networks to deploy Dataflow Pipelines in the Data Ingestion project, the network having:
  - A VPC Network with one subnetwork.
  - A set of Firewall rules.
  - The required DNS configuration for Google Private Access.
- The configuration of Log Sinks in all projects with the creation of a related Logging bucket in the Data Governance project.
- The Cloud KMS infrastructure for the creation of a `wrapped_key` and `crypto_key` pair using [Tinkey](https://github.com/google/tink/blob/master/docs/TINKEY.md):
  - A Cloud KMS Keyring.
  - A Cloud KMS key encryption key (KEK).[[1]](#notes)
  - A data encryption key (DEK) for AEAD.


[Custom names](#inputs) can be provided for the four projects created in this example.
If custom names are not provided, the names of the projects will be:

- `ext-harness`
- `sdw-data-ing`
- `sdw-data-gov`
- `sdw-data`

A random suffix will be added to the end of the names to create the project ID to prevent collisions with existing projects.

In the deploy of the Blueprint and the showcase of the usage of `AEAD` and `tink` we have:

- The deploy of the [main module](../../README.md) itself.
- The creation a Dataflow Pipeline that can read form Pub/Sub and write to BigQuery doing an optional transformation on the data.
- The creation of a Data Catalog taxonomy and [policy tags](https://cloud.google.com/bigquery/docs/best-practices-policy-tags) representing security levels.
- The creation of a BigQuery table with [column-level security](https://cloud.google.com/bigquery/docs/column-level-security) enabled using the Data Catalog policy tags for [dynamic data masking](https://cloud.google.com/bigquery/docs/column-data-masking-intro).
- The creation of a BigQuery function and view to show how to use `AEAD` functions to decrypt data.
- The creation of a Cloud Function to create Bigquery [load jobs](https://cloud.google.com/bigquery/docs/batch-loading-data) when files are uploaded to the ingestion bucket.
- A [Big Query subscription](https://cloud.google.com/pubsub/docs/bigquery) to write Pub/Sub messages to the BigQuery table with column-level security.
- A DLP scan in the BigQuery table created.

**Note:** To deploy this example, you must also have an existing project on which to create a service account that will be used to deploy the example.
This service account must be granted the required IAM roles.
The project should not be on the same folder as the projects create in this example, in accordance with the principle of separation of concerns.
You can use the [Project Factory](https://github.com/terraform-google-modules/terraform-google-project-factory) module and the [IAM module](https://github.com/terraform-google-modules/terraform-google-iam) in combination.
These modules can be used to provision a service account with the necessary roles applied.

## Google Cloud Locations

This example will be deployed at the `us-east4` location.
To deploy in another location, change the local `location` in the example [main.tf](./main.tf#L18) file.
By default, the *Secured Data Warehouse* module has an [Organization Policy](https://cloud.google.com/resource-manager/docs/organization-policy/defining-locations)
that only allows the creation of resource in `us-locations`.
To deploy in other locations, update the input [trusted_locations](../../README.md#inputs) in the [main module](./main.tf#L39) call.

## Usage

- Rename the `tfvars` file by running `mv terraform.example.tfvars terraform.tfvars` and update `terraform.tfvars` with values from your environment.

  ```bash
  mv terraform.example.tfvars terraform.tfvars
  ```

- Before running the standalone example, make sure you have `Java` and `Tinkey` installed locally.
  To do so, use the [Tinkey Setup Helper](../../helpers/tinkey_setup.sh) by running the command below inside the standalone folder:

  ```bash
  ../../helpers/tinkey_setup.sh
  ```

- Run `terraform init` to get the plugins.

  ```bash
  terraform init
  ```

- Run `terraform plan` and review the plan.

  ```bash
  terraform plan
  ```

- Run `terraform apply` to apply the infrastructure build.

  ```bash
  terraform apply
  ```

### Troubleshooting

If you encounter problems in the `apply` execution check the [Troubleshooting Guide](../../docs/TROUBLESHOOTING.md).

### Clean up

- Run `terraform destroy` to clean up your environment.
The input `delete_contents_on_destroy` must have been set to `true` in the original `apply` for the `terraform destroy` command to work.

  ```bash
  terraform destroy
  ```

### Deploy new Dataflow Jobs

To deploy new Dataflow jobs in the infrastructure created by this example, follow the instructions in the [deploying dataflow jobs](../../docs/deploying_dataflow_jobs.md) documentation.

Use the subnetwork in the output `data_ingestion_subnets_self_link` to deploy new Dataflow jobs.

Note: If you are using Google Cloud Console to deploy Dataflow jobs, to [disable public IPs](https://cloud.google.com/dataflow/docs/guides/routes-firewall#turn_off_external_ip_address), use the optional parameter "Worker IP Address Configuration" set to `Private`.


### Perimeter members list

To be able to see the resources protected by the VPC Service Controls [Perimeters](https://cloud.google.com/vpc-service-controls/docs/service-perimeters) in the Google Cloud Console
you must add your user in the variable `perimeter_additional_members` in the `terraform.tfvars` file.

### Sample Data

The sample data used in this example are a [csv file](./assets/cc_10000_records.csv) and a [json file](./assets/cc_100_records.json) with fake credit card data.
The csv file has 10k records and the json file has 100 records.

Each record has these values:

- Card_Type_Code.
- Card_Type_Full_Name.
- Issuing_Bank.
- Card_Number.
- Card_Holders_Name.
- CVV_CVV2.
- Issue_Date.
- Expiry_Date.
- Billing_Date.
- Card_PIN.
- Credit_Limit.

The harness will encrypt the following fields in this file:

  - Card_Number.
  - Card_Holders_Name.
  - CVV_CVV2.
  - Expiry_Date.
  - Card_PIN.
  - Credit_Limit.

Advanced Encryption Standard Galois/Counter Mode (AES256_GCM) is used by the [Tink](https://developers.google.com/tink) library to encrypt the data.

### Taxonomy used

This example creates a Data Catalog taxonomy to enable [BigQuery column-level access controls](https://cloud.google.com/bigquery/docs/column-level-security-intro) and data masking.

The taxonomy has one level: **Sensitive**

- **1_Sensitive:** Data not meant to be public.
  - CREDIT_LIMIT.
  - CARD_TYPE_FULL_NAME.
  - CARD_TYPE_CODE.


No user has access to read this data protected with column-level security.
If they need access, they need to be added to the appropriate group: *encrypted reader* or *plain text reader*.

### Sending Data to PubSub Topic

You can use following code to send messages to the pubsub topic deployed by this blueprint. You can review more information on [PubSub Documentation](https://cloud.google.com/pubsub/docs/publisher#gcloud).

```bash
gcloud pubsub topics publish <pubsub_topic_id> --message <json_data>
```

Note that messages sent are validated according to the topic's schema.

## Requirements

These sections describe requirements for running this example.

### Software

Install the following dependencies:

- [Google Cloud SDK](https://cloud.google.com/sdk/install) version 400.0.0 or later.
- [Terraform](https://www.terraform.io/downloads.html) version 1.3.1 or later.
- [jq](https://stedolan.github.io/jq/) version 1.6 or later.
- [tinkey](https://github.com/google/tink/blob/master/docs/TINKEY.md) version 1.7.0 or later.
- [Golang](https://go.dev/doc/install) version 1.17.0 or later.
- [Java](https://www.oracle.com/java/technologies/downloads/) version 1.8.0_362 or later.

### Cloud SDK configurations

The standalone example uses `tinkey` to generate the wrapped_key that will be used to encrypt "on-premises" data. The `tinkey` tool runs using the [Application Default Credentials](https://cloud.google.com/sdk/gcloud/reference/auth/application-default).

To configure **Application Default Credentials** run:

```bash
gcloud auth application-default login
```

To avoid errors in the deployment, you must also guarantee that the `gcloud command` is not using a project that has been deleted or is unavailable.
We recommend to unset the project:

```bash
gcloud config unset project
```
### Tinkey

Before running the standalone example, make sure you have `Java` and `Tinkey` installed locally.
To do so, use the [Tinkey Setup Helper](../../helpers/tinkey_setup.sh) by running the command below inside the standalone folder:

```bash
../../helpers/tinkey_setup.sh
```

The script will check if Java is installed. If Java is not installed, you must install Java 8 or later before proceeding.

The script will also check if there is a Tinkey version installed:
- If there is a Tinkey version installed, the script will stop the execution.
- If there is not a Tinkey version installed, the script will install Tinkey version [1.7.0](https://github.com/google/tink/blob/1.7/docs/TINKEY.md) in directory `/usr/bin`.

For information about optional parameters that can be provided to the script run:

```bash
../../helpers/tinkey_setup.sh -h
```

### Service Account

To provision the resources of this example, create a privileged service account,
where the service account key cannot be created.
In addition, consider using Cloud Monitoring to alert on this service account's activity.
Grant the following roles to the service account.

- Organization level:
  - Access Context Manager Admin: `roles/accesscontextmanager.policyAdmin`
  - Billing Account User: `roles/billing.user`
  - Organization Policy Administrator: `roles/orgpolicy.policyAdmin`
  - Organization Administrator: `roles/resourcemanager.organizationAdmin`
- Folder Level:
  - Compute Network Admin: `roles/compute.networkAdmin`
  - Compute Security Admin: `roles/compute.securityAdmin`
  - Logging Admin: `roles/logging.admin`
  - Project Creator: `roles/resourcemanager.projectCreator`
  - Project Deleter: `roles/resourcemanager.projectDeleter`
  - Project IAM Admin: `roles/resourcemanager.projectIamAdmin`
  - Service Usage Admin: `roles/serviceusage.serviceUsageAdmin`
  - Serverless VPC Access Admin: `roles/vpcaccess.admin`
  - DNS Administrator: `roles/dns.admin`

**Note:** The billing account used to create the projects may not be under the same organization where the resources are created.
In this case, granting the role **Billing Account User** in the organization will have no effect.
As an alternative to granting the service account the `Billing Account User` role in organization,
it is possible to grant it [directly in the billing account](https://cloud.google.com/billing/docs/how-to/billing-access#update-cloud-billing-permissions).

You can run the following `gcloud` command to assign `Billing Account User` role to the service account.

```bash
export SA_EMAIL=<YOUR-SA-EMAIL>
export BILLING_ACCOUNT=<YOUR-BILLING-ACCOUNT>

gcloud beta billing accounts add-iam-policy-binding "${BILLING_ACCOUNT}" \
--member="serviceAccount:${SA_EMAIL}" \
--role="roles/billing.user"
```

You can use the [Project Factory module](https://github.com/terraform-google-modules/terraform-google-project-factory) and the
[IAM module](https://github.com/terraform-google-modules/terraform-google-iam) in combination to provision a
service account with the necessary roles applied.

The user using this service account must have the necessary roles, `Service Account User` and `Service Account Token Creator`, to [impersonate](https://cloud.google.com/iam/docs/impersonating-service-accounts) the service account.

You can run the following commands to assign roles to the service account:

```bash
export ORG_ID=<YOUR-ORG-ID>
export FOLDER_ID=<YOUR-FOLDER-ID>
export SA_EMAIL=<YOUR-SA-EMAIL>

gcloud organizations add-iam-policy-binding ${ORG_ID} \
--member="serviceAccount:${SA_EMAIL}" \
--role="roles/resourcemanager.organizationAdmin"

gcloud organizations add-iam-policy-binding ${ORG_ID} \
--member="serviceAccount:${SA_EMAIL}" \
--role="roles/accesscontextmanager.policyAdmin"

gcloud organizations add-iam-policy-binding ${ORG_ID} \
--member="serviceAccount:${SA_EMAIL}" \
--role="roles/billing.user"

gcloud organizations add-iam-policy-binding ${ORG_ID} \
--member="serviceAccount:${SA_EMAIL}" \
--role="roles/orgpolicy.policyAdmin"

gcloud resource-manager folders \
add-iam-policy-binding ${FOLDER_ID} \
--member="serviceAccount:${SA_EMAIL}" \
--role="roles/compute.networkAdmin"

gcloud resource-manager folders \
add-iam-policy-binding ${FOLDER_ID} \
--member="serviceAccount:${SA_EMAIL}" \
--role="roles/logging.admin"

gcloud resource-manager folders \
add-iam-policy-binding ${FOLDER_ID} \
--member="serviceAccount:${SA_EMAIL}" \
--role="roles/resourcemanager.projectCreator"

gcloud resource-manager folders \
add-iam-policy-binding ${FOLDER_ID} \
--member="serviceAccount:${SA_EMAIL}" \
--role="roles/resourcemanager.projectDeleter"

gcloud resource-manager folders \
add-iam-policy-binding ${FOLDER_ID} \
--member="serviceAccount:${SA_EMAIL}" \
--role="roles/resourcemanager.projectIamAdmin"

gcloud resource-manager folders \
add-iam-policy-binding ${FOLDER_ID} \
--member="serviceAccount:${SA_EMAIL}" \
--role="roles/serviceusage.serviceUsageAdmin"

gcloud resource-manager folders \
add-iam-policy-binding ${FOLDER_ID} \
--member="serviceAccount:${SA_EMAIL}" \
--role="roles/vpcaccess.admin"

gcloud resource-manager folders \
add-iam-policy-binding ${FOLDER_ID} \
--member="serviceAccount:${SA_EMAIL}" \
--role="roles/dns.admin"

gcloud resource-manager folders \
add-iam-policy-binding ${FOLDER_ID} \
--member="serviceAccount:${SA_EMAIL}" \
--role="roles/compute.securityAdmin"
```

### APIs

The following APIs must be enabled in the project where the service account was created:

- Access Context Manager API: `accesscontextmanager.googleapis.com`
- App Engine Admin API: `appengine.googleapis.com`
- Cloud Billing API: `cloudbilling.googleapis.com`
- Cloud Build API: `cloudbuild.googleapis.com`
- Cloud Key Management Service (KMS) API: `cloudkms.googleapis.com`
- Cloud Pub/Sub API: `pubsub.googleapis.com`
- Cloud Resource Manager API: `cloudresourcemanager.googleapis.com`
- Compute Engine API: `compute.googleapis.com`
- Dataflow API: `dataflow.googleapis.com`
- Identity and Access Management (IAM) API: `iam.googleapis.com`
- BigQuery API: `bigquery.googleapis.com`
- Cloud Data Loss Prevention (DLP) API: `dlp.googleapis.com`

You can run the following `gcloud` command to enable these APIs in the service account project.

```bash
export PROJECT_ID=<SA-PROJECT-ID>

gcloud services enable \
accesscontextmanager.googleapis.com \
appengine.googleapis.com \
bigquery.googleapis.com \
cloudbilling.googleapis.com \
cloudbuild.googleapis.com \
cloudkms.googleapis.com \
pubsub.googleapis.com \
cloudresourcemanager.googleapis.com \
compute.googleapis.com \
dataflow.googleapis.com \
iam.googleapis.com \
dlp.googleapis.com \
--project ${PROJECT_ID}
```

### Notes

1 - The `plaintext_reader_group` provided in the `terraform.tfvars` file will be granted `encrypter/decrypter` permissions on the Cloud KMS key encryption key (KEK) to allow the use with [tinkey](https://github.com/google/tink/blob/master/docs/TINKEY.md). Additionally, the user configured in the [Application Default Credentials](https://cloud.google.com/sdk/gcloud/reference/auth/application-default) should be included in the `plaintext_reader_group` or have other off the band permissions on the key.

### Outputs by personas

These outputs can be interesting for all user:

- Data ingestion dataflow bucket name
- Data project id
- Data governance project id
- Data ingestion project id
- Service account: dataflow controller service account

These outputs can be interesting for data analyst group:

- Bigquery table
- Data project id
- Data ingestion dataflow bucket name
- Taxonomy

These outputs can be interesting for data engineer group:

- Data ingestion topic name
- Pubsub writer service account email
- Storage writer service account email
- Kek wrapping keyring

These outputs can be interesting for network administrator group:

- Data ingestion network name
- Data ingestion network self link
- Data ingestion subnets self link

These outputs can be interesting for security administrator group:

- Cmek bigquery crypto key
- Cmek data ingestion project crypto key
- Cmek data project crypto key
- Data perimeter name
- Data governance perimeter name
- Data ingestion service perimeter name
- Kek wrapping keyring

These outputs can be interesting for security analyst group:

- Centralized logging bucket name
- Taxonomy display name

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| access\_context\_manager\_policy\_id | The id of the default Access Context Manager policy. Can be obtained by running `gcloud access-context-manager policies list --organization YOUR-ORGANIZATION_ID --format="value(name)"`. | `string` | n/a | yes |
| access\_level\_ip\_subnetworks | Condition - A list of CIDR block IP subnetwork specification. May be IPv4 or IPv6. Note that for a CIDR IP address block, the specified IP address portion must be properly truncated (that is, all the host bits must be zero) or the input is considered malformed. For example, "192.0.2.0/24" is accepted but "192.0.2.1/24" is not. Similarly, for IPv6, "2001:db8::/32" is accepted whereas "2001:db8::1/32" is not. The originating IP of a request must be in one of the listed subnets in order for this Condition to be true. If empty, all IP addresses are allowed. | `list(string)` | `[]` | no |
| billing\_account | The billing account id associated with the projects, e.g. XXXXXX-YYYYYY-ZZZZZZ. | `string` | n/a | yes |
| build\_project\_number | The project number of the build project. | `string` | `""` | no |
| data\_analyst\_group | Google Cloud IAM group that analyzes the data in the warehouse. | `string` | n/a | yes |
| data\_engineer\_group | Google Cloud IAM group that sets up and maintains the data pipeline and warehouse. | `string` | n/a | yes |
| data\_governance\_project\_name | Custom project name for the data governance project. | `string` | `""` | no |
| data\_ingestion\_project\_name | Custom project name for the data ingestion project. | `string` | `""` | no |
| data\_project\_name | Custom project name for the data project. | `string` | `""` | no |
| delete\_contents\_on\_destroy | (Optional) If set to true, delete all the tables in the dataset when destroying the resource; otherwise, destroying the resource will fail if tables are present. | `bool` | `false` | no |
| encrypted\_data\_reader\_group | Google Cloud IAM group that analyzes encrypted data. | `string` | n/a | yes |
| folder\_id | The folder to deploy in. | `string` | n/a | yes |
| network\_administrator\_group | Google Cloud IAM group that reviews network configuration. Typically, this includes members of the networking team. | `string` | n/a | yes |
| org\_id | The numeric organization id. | `string` | n/a | yes |
| perimeter\_additional\_members | The list of members to be added on perimeter access. To be able to see the resources protected by the VPC Service Controls add your user must be in this list. The service accounts created by this module do not need to be added to this list. Entries must be in the standard GCP form: `user:email@email.com` or `serviceAccount:my-service-account@email.com`. | `list(string)` | n/a | yes |
| plaintext\_reader\_group | Google Cloud IAM group that analyzes plaintext reader. | `string` | n/a | yes |
| security\_administrator\_group | Google Cloud IAM group that administers security configurations in the organization(org policies, KMS, VPC service perimeter). | `string` | n/a | yes |
| security\_analyst\_group | Google Cloud IAM group that monitors and responds to security incidents. | `string` | n/a | yes |
| template\_project\_name | Custom project name for the template project. | `string` | `""` | no |
| terraform\_service\_account | The email address of the service account that will run the Terraform code. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| bigquery\_job\_id | The Bigquery job ID used to load .csv file. |
| centralized\_logging\_bucket\_name | The name of the bucket created for storage logging. |
| cmek\_data\_bigquery\_crypto\_key | The Customer Managed Crypto Key for the BigQuery service. |
| cmek\_data\_ingestion\_crypto\_key | The Customer Managed Crypto Key for the data ingestion crypto boundary. |
| cmek\_keyring\_name | The Keyring name for the KMS Customer Managed Encryption Keys. |
| csv\_load\_job\_id | The ID of the BigQuery Job to upload the csv file. |
| data\_governance\_perimeter\_name | Access context manager service perimeter name. |
| data\_governance\_project\_id | The ID of the project created for data governance. |
| data\_ingestion\_bucket\_name | The name of the bucket created for the data ingestion pipeline. |
| data\_ingestion\_dataflow\_bucket\_name | The name of the staging bucket created for dataflow in the data ingestion pipeline. |
| data\_ingestion\_network\_name | The name of the data ingestion VPC being created. |
| data\_ingestion\_network\_self\_link | The URI of the data ingestion VPC being created. |
| data\_ingestion\_project\_id | The ID of the project created for the data ingestion pipeline. |
| data\_ingestion\_service\_perimeter\_name | Access context manager service perimeter name. |
| data\_ingestion\_subnets\_self\_link | The self-links of data ingestion subnets being created. |
| data\_ingestion\_topic\_name | The topic created for data ingestion pipeline. |
| data\_perimeter\_name | Access context manager service perimeter name. |
| data\_project\_id | The ID of the project created for datasets and tables. |
| dataflow\_controller\_service\_account\_email | The Dataflow controller service account email. Required to deploy Dataflow jobs. See https://cloud.google.com/dataflow/docs/concepts/security-and-permissions#specifying_a_user-managed_controller_service_account. |
| dlp\_job\_id | The identifier ID for the job trigger. |
| dlp\_job\_name | The resource name of the job trigger. |
| function\_id | An identifier for the Cloud Function resource. |
| kek\_wrapping\_key | The kek wrapping key. |
| kek\_wrapping\_key\_name | The name of kek wrapping key. |
| kek\_wrapping\_keyring | The kek wrapping keyring. |
| kek\_wrapping\_keyring\_name | The name of kek wrapping keyring. |
| pubsub\_writer\_service\_account\_email | The PubSub writer service account email. Should be used to write data to the PubSub topics the data ingestion pipeline reads from. |
| random\_suffix | Suffix used in the name of resources. |
| storage\_writer\_service\_account\_email | The Storage writer service account email. Should be used to write data to the buckets the data ingestion pipeline reads from. |
| subscription\_names | The name list of Pub/Sub subscriptions |
| taxonomy\_display\_name | The name of the taxonomy. |
| taxonomy\_name | The taxonomy name. |
| template\_project\_id | The id of the flex template created. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

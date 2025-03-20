# Secured Data Warehouse On-premisses Data Ingestion Blueprint

[FAQ](./docs/FAQ.md) | [Troubleshooting Guide](./docs/TROUBLESHOOTING.md).

This repository contains Terraform configuration modules that allow Google Cloud customers to import data from an on-premises environment or another cloud into a Secured [BigQuery](https://cloud.google.com/bigquery) warehouse.
This blueprint provides an opinionated architecture and an example on how to:

- Encrypt data located outside of Google Cloud and import it into BigQuery using the [Tink](https://developers.google.com/tink) library.
- Configure VPC Service Controls to secure the data pipeline and access to confidential data.
- Configure separation of duties for personas (Google Groups).
- Set up appropriate security controls (Organization Policies) and Google Cloud Logging to help protect confidential data.
- Use data classification, Data Catalog policy tags, dynamic data masking, and column-level encryption to restrict access to specific columns in the BigQuery data warehouse.

## Disclaimer

When using this blueprint, it is important to understand how you manage [separation of duties](https://cloud.google.com/kms/docs/separation-of-duties. We recommend you remove all primitive `owner` roles in the projects used as inputs for the blueprint main module. The blueprint itself does not need any primitive owner roles for correct operations.
The Blueprint does not proactively remove any pre-existing owner role assignments from pre-existing projects in your organization, as we won’t know your intent for or dependency on these role assignments in your pre-existing workloads. The pre-existing presence of these roles does expand the attack and risk surface of the resulting deployment. Therefore, we highly recommend you review your use of owner roles in these pre-existing cases and see if you can eliminate them to improve your resulting security posture.

You can check the current situation of your project with either of the following methods:

- Using [Security Health Analytics](https://cloud.google.com/security-command-center/docs/concepts-vulnerabilities-findings#security-health-analytics-detectors) (SHA), checking the [KMS vulnerability findings](https://cloud.google.com/security-command-center/docs/concepts-vulnerabilities-findings#kms-findings), for the Detector `KMS_PROJECT_HAS_OWNER`.
  - You can search for the SHA findings with category `KMS_PROJECT_HAS_OWNER` in the Security Command Center in the  Google Cloud Console.
- You can also use Cloud Asset Inventory [search-all-iam-policies](https://cloud.google.com/asset-inventory/docs/searching-iam-policies#search_policies) `gcloud` command doing a [Query by role](https://cloud.google.com/asset-inventory/docs/searching-iam-policies#examples_query_by_role) to search for owner of the project.

See the [terraform-example-foundation](https://github.com/terraform-google-modules/terraform-example-foundation) for additional good practices.

## Usage

Basic usage of this module is as follows:

```hcl
module "secured_data_warehouse" {
  source  = "GoogleCloudPlatform/secured-data-warehouse-onprem-ingest/google"
  version = "~> 0.1"

  org_id                           = ORG_ID
  data_governance_project_id       = DATA_GOVERNANCE_PROJECT_ID
  data_governance_project_number   = DATA_GOVERNANCE_PROJECT_NUMBER
  data_project_id                  = DATA_PROJECT_ID
  data_project_number              = DATA_PROJECT_NUMBER
  data_ingestion_project_id        = DATA_INGESTION_PROJECT_ID
  data_ingestion_project_number    = DATA_INGESTION_PROJECT_NUMBER
  sdx_project_number               = EXTERNAL_TEMPLATE_PROJECT_NUMBER
  terraform_service_account        = TERRAFORM_SERVICE_ACCOUNT
  access_context_manager_policy_id = ACCESS_CONTEXT_MANAGER_POLICY_ID
  bucket_name                      = DATA_INGESTION_BUCKET_NAME
  pubsub_resource_location         = PUBSUB_RESOURCE_LOCATION
  location                         = LOCATION
  trusted_locations                = TRUSTED_LOCATIONS
  dataset_id                       = DATASET_ID
  cmek_keyring_name                = CMEK_KEYRING_NAME
  perimeter_additional_members     = PERIMETER_ADDITIONAL_MEMBERS
  data_engineer_group              = DATA_ENGINEER_GROUP
  data_analyst_group               = DATA_ANALYST_GROUP
  security_analyst_group           = SECURITY_ANALYST_GROUP
  network_administrator_group      = NETWORK_ADMINISTRATOR_GROUP
  security_administrator_group     = SECURITY_ADMINISTRATOR_GROUP
  encrypted_data_reader_group      = ENCRYPTED_DATA_READER_GROUP
  plaintext_reader_group           = PLAINTEXT_READER_GROUP
  delete_contents_on_destroy       = false
}
```

**Note:** There are three inputs related to GCP Locations in the module:

- `pubsub_resource_location`: is used to define which GCP location will be used to [Restrict Pub/Sub resource locations](https://cloud.google.com/pubsub/docs/resource-location-restriction). This policy offers a way to ensure that messages published to a topic are never persisted outside of a Google Cloud regions you specify, regardless of where the publish requests originate. **Zones or multi-region locations are not supported**.
- `location`: is used to define which GCP region will be used for all other resources created: [Cloud Storage buckets](https://cloud.google.com/storage/docs/locations), [BigQuery datasets](https://cloud.google.com/bigquery/docs/locations), and [Cloud KMS key rings](https://cloud.google.com/kms/docs/locations). **Multi-region locations are supported**.
- `trusted_locations`: is a list of locations that are used to set an [Organization Policy](https://cloud.google.com/resource-manager/docs/organization-policy/defining-locations#location_types) that restricts the GCP locations that can be used in the projects of the Secured Data Warehouse. Both `pubsub_resource_location` and `location` must respect this restriction.

A Functional example, deploying the module, the required infrastructure needed by the module,
and data to be ingested is included in the [examples](./examples/) directory.

Additional information related to the inputs and outputs of the module are detailed in the following section.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| access\_context\_manager\_policy\_id | The id of the default Access Context Manager policy. Can be obtained by running `gcloud access-context-manager policies list --organization YOUR-ORGANIZATION_ID --format="value(name)"`. | `string` | `""` | no |
| access\_level\_ip\_subnetworks | Condition - A list of CIDR block IP subnetwork specification. May be IPv4 or IPv6. Note that for a CIDR IP address block, the specified IP address portion must be properly truncated (that is, all the host bits must be zero) or the input is considered malformed. For example, "192.0.2.0/24" is accepted but "192.0.2.1/24" is not. Similarly, for IPv6, "2001:db8::/32" is accepted whereas "2001:db8::1/32" is not. The originating IP of a request must be in one of the listed subnets in order for this Condition to be true. If empty, all IP addresses are allowed. | `list(string)` | `[]` | no |
| add\_project\_to\_data\_governance\_perimeter | If the data governance project should be added to the data governance perimeter. | `bool` | `true` | no |
| add\_project\_to\_data\_ingestion\_perimeter | If the data ingestion project should be added to the data ingestion perimeter. | `bool` | `true` | no |
| add\_project\_to\_data\_perimeter | If the data project should be added to the data perimeter. | `bool` | `true` | no |
| bucket\_class | The storage class for the bucket being provisioned. | `string` | `"STANDARD"` | no |
| bucket\_lifecycle\_rules | List of lifecycle rules to configure. Format is the same as described in provider documentation https://www.terraform.io/docs/providers/google/r/storage_bucket.html#lifecycle_rule except condition.matches\_storage\_class should be a comma delimited string. | <pre>set(object({<br>    action    = any<br>    condition = any<br>  }))</pre> | <pre>[<br>  {<br>    "action": {<br>      "type": "Delete"<br>    },<br>    "condition": {<br>      "age": 30,<br>      "matches_storage_class": "STANDARD",<br>      "with_state": "ANY"<br>    }<br>  }<br>]</pre> | no |
| bucket\_name | The name of the bucket being provisioned. | `string` | n/a | yes |
| cmek\_keyring\_name | The Keyring prefix name for the KMS Customer Managed Encryption Keys being provisioned. | `string` | n/a | yes |
| custom\_restricted\_services | The list of custom Google services to be protected by the VPC-SC perimeters. | `list(string)` | `[]` | no |
| data\_analyst\_group | Google Cloud IAM group that analyzes the data in the warehouse. | `string` | n/a | yes |
| data\_egress\_policies | A list of all [egress policies](https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#egress-rules-reference) for the Data perimeter, each list object has a `from` and `to` value that describes egress\_from and egress\_to. See also [secure data exchange](https://cloud.google.com/vpc-service-controls/docs/secure-data-exchange#allow_access_to_a_google_cloud_resource_outside_the_perimeter) and the [VPC-SC](https://github.com/terraform-google-modules/terraform-google-vpc-service-controls/blob/v3.1.0/modules/regular_service_perimeter/README.md) module. | <pre>list(object({<br>    from = any<br>    to   = any<br>  }))</pre> | `[]` | no |
| data\_engineer\_group | Google Cloud IAM group that sets up and maintains the data pipeline and warehouse. | `string` | n/a | yes |
| data\_governance\_egress\_policies | A list of all [egress policies](https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#egress-rules-reference) for the Data Governance perimeter, each list object has a `from` and `to` value that describes egress\_from and egress\_to. See also [secure data exchange](https://cloud.google.com/vpc-service-controls/docs/secure-data-exchange#allow_access_to_a_google_cloud_resource_outside_the_perimeter) and the [VPC-SC](https://github.com/terraform-google-modules/terraform-google-vpc-service-controls/blob/v3.1.0/modules/regular_service_perimeter/README.md) module. | <pre>list(object({<br>    from = any<br>    to   = any<br>  }))</pre> | `[]` | no |
| data\_governance\_ingress\_policies | A list of all [ingress policies](https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#ingress-rules-reference) for the Data Ingestion perimeter, each list object has a `from` and `to` value that describes egress\_from and egress\_to. See also [secure data exchange](https://cloud.google.com/vpc-service-controls/docs/secure-data-exchange#allow_access_to_a_google_cloud_resource_outside_the_perimeter) and the [VPC-SC](https://github.com/terraform-google-modules/terraform-google-vpc-service-controls/blob/v3.1.0/modules/regular_service_perimeter/README.md) module. | <pre>list(object({<br>    from = any<br>    to   = any<br>  }))</pre> | `[]` | no |
| data\_governance\_perimeter | Existing data governance perimeter to be used instead of the auto-created perimeter. The service account provided in the variable `terraform_service_account` must be in an access level member list for this perimeter **before** this perimeter can be used in this module. | `string` | `""` | no |
| data\_governance\_project\_id | The ID of the project in which the data governance resources will be created. | `string` | n/a | yes |
| data\_governance\_project\_number | The project number in which the data governance resources will be created. | `string` | n/a | yes |
| data\_ingestion\_dataflow\_deployer\_identities | List of members in the standard GCP form: user:{email}, serviceAccount:{email} that will deploy Dataflow jobs in the Data Ingestion project. These identities will be added to the VPC-SC secure data exchange egress rules. | `list(string)` | `[]` | no |
| data\_ingestion\_egress\_policies | A list of all [egress policies](https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#egress-rules-reference) for the Data Ingestion perimeter, each list object has a `from` and `to` value that describes egress\_from and egress\_to. See also [secure data exchange](https://cloud.google.com/vpc-service-controls/docs/secure-data-exchange#allow_access_to_a_google_cloud_resource_outside_the_perimeter) and the [VPC-SC](https://github.com/terraform-google-modules/terraform-google-vpc-service-controls/blob/v3.1.0/modules/regular_service_perimeter/README.md) module. | <pre>list(object({<br>    from = any<br>    to   = any<br>  }))</pre> | `[]` | no |
| data\_ingestion\_ingress\_policies | A list of all [ingress policies](https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#ingress-rules-reference) for the Data Ingestion perimeter, each list object has a `from` and `to` value that describes egress\_from and egress\_to. See also [secure data exchange](https://cloud.google.com/vpc-service-controls/docs/secure-data-exchange#allow_access_to_a_google_cloud_resource_outside_the_perimeter) and the [VPC-SC](https://github.com/terraform-google-modules/terraform-google-vpc-service-controls/blob/v3.1.0/modules/regular_service_perimeter/README.md) module. | <pre>list(object({<br>    from = any<br>    to   = any<br>  }))</pre> | `[]` | no |
| data\_ingestion\_perimeter | Existing data ingestion perimeter to be used instead of the auto-created perimeter. The service account provided in the variable `terraform_service_account` must be in an access level member list for this perimeter **before** this perimeter can be used in this module. | `string` | `""` | no |
| data\_ingestion\_project\_id | The ID of the project in which the data ingestion resources will be created. | `string` | n/a | yes |
| data\_ingestion\_project\_number | The project number in which the data ingestion resources will be created. | `string` | n/a | yes |
| data\_ingress\_policies | A list of all [ingress policies](https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#ingress-rules-reference) for the Data Ingestion perimeter, each list object has a `from` and `to` value that describes egress\_from and egress\_to. See also [secure data exchange](https://cloud.google.com/vpc-service-controls/docs/secure-data-exchange#allow_access_to_a_google_cloud_resource_outside_the_perimeter) and the [VPC-SC](https://github.com/terraform-google-modules/terraform-google-vpc-service-controls/blob/v3.1.0/modules/regular_service_perimeter/README.md) module. | <pre>list(object({<br>    from = any<br>    to   = any<br>  }))</pre> | `[]` | no |
| data\_perimeter | Existing data perimeter to be used instead of the auto-created perimeter. The service account provided in the variable `terraform_service_account` must be in an access level member list for this perimeter **before** this perimeter can be used in this module. | `string` | `""` | no |
| data\_project\_id | Project where the datasets and tables are created. | `string` | n/a | yes |
| data\_project\_number | The project number where the datasets and tables are created. | `string` | n/a | yes |
| dataset\_default\_table\_expiration\_ms | TTL of tables using the dataset in MS. The default value is null. | `number` | `null` | no |
| dataset\_description | Dataset description. | `string` | `"Data dataset"` | no |
| dataset\_id | Unique ID for the dataset being provisioned. | `string` | `"data_dataset"` | no |
| dataset\_name | Friendly name for the dataset being provisioned. | `string` | `"Data dataset"` | no |
| delete\_contents\_on\_destroy | (Optional) If set to true, delete all the tables in the dataset when destroying the resource; otherwise, destroying the resource will fail if tables are present. | `bool` | `false` | no |
| dlp\_output\_dataset | Unique ID for the dataset being provisioned to host Cloud Data Loss Prevention (DLP) BigQuery scan results. | `string` | `"dlp_scanner_output"` | no |
| domains\_to\_allow | The list of domains to allow users from in IAM. Used by Domain Restricted Sharing Organization Policy. Must include the domain of the organization you are deploying the blueprint. To add other domains you must also grant access to these domains to the terraform service account used in the deploy. | `list(string)` | `[]` | no |
| enable\_bigquery\_read\_roles\_in\_data\_ingestion | (Optional) If set to true, it will grant to the dataflow controller service account created in the data ingestion project the necessary roles to read from a bigquery table. | `bool` | `false` | no |
| encrypted\_data\_reader\_group | Google Cloud IAM group that analyzes encrypted data. | `string` | n/a | yes |
| key\_rotation\_period\_seconds | Rotation period for keys. The default value is 30 days. | `string` | `"2592000s"` | no |
| kms\_key\_protection\_level | The protection level to use when creating a key. Possible values: ["SOFTWARE", "HSM"] | `string` | `"HSM"` | no |
| labels | (Optional) Labels attached to Data Warehouse resources. | `map(string)` | `{}` | no |
| location | The location for the KMS Customer Managed Encryption Keys, Cloud Storage Buckets, and Bigquery datasets. This location can be a multi-region. | `string` | `"us-east4"` | no |
| network\_administrator\_group | Google Cloud IAM group that reviews network configuration. Typically, this includes members of the networking team. | `string` | n/a | yes |
| org\_id | GCP Organization ID. | `string` | n/a | yes |
| perimeter\_additional\_members | The list additional members to be added on perimeter access. Prefix user: (user:email@email.com) or serviceAccount: (serviceAccount:my-service-account@email.com) is required. | `list(string)` | `[]` | no |
| plaintext\_reader\_group | Google Cloud IAM group that analyzes plaintext reader. | `string` | n/a | yes |
| pubsub\_resource\_location | The location in which the messages published to Pub/Sub will be persisted. This location cannot be a multi-region. | `string` | `"us-east4"` | no |
| remove\_owner\_role | (Optional) If set to true, remove all owner roles in all projects in case it has been found in some project. | `bool` | `false` | no |
| sdx\_project\_number | The Project Number to configure Secure data exchange with egress rule for dataflow templates. Required if using a dataflow job template from a private storage bucket outside of the perimeter. | `string` | `""` | no |
| security\_administrator\_group | Google Cloud IAM group that administers security configurations in the organization(org policies, KMS, VPC service perimeter). | `string` | n/a | yes |
| security\_analyst\_group | Google Cloud IAM group that monitors and responds to security incidents. | `string` | n/a | yes |
| terraform\_service\_account | The email address of the service account that will run the Terraform code. | `string` | n/a | yes |
| trusted\_locations | This is a list of trusted regions where location-based GCP resources can be created. | `list(string)` | <pre>[<br>  "us-locations"<br>]</pre> | no |
| trusted\_shared\_vpc\_subnetworks | The URI of the trusted Shared VPC subnetworks where resources will be allowed to be deployed. Used by 'Restrict Shared VPC Subnetworks' Organization Policy. Format 'projects/PROJECT\_ID/regions/REGION/subnetworks/SUBNETWORK-NAME'. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| cloudfunction\_controller\_service\_account\_email | The Cloud Function controller service account email. |
| cmek\_data\_bigquery\_crypto\_key | The Customer Managed Crypto Key for the BigQuery service. |
| cmek\_data\_ingestion\_crypto\_key | The Customer Managed Crypto Key for the data ingestion crypto boundary. |
| cmek\_keyring\_name | The Keyring name for the KMS Customer Managed Encryption Keys. |
| cmek\_reidentification\_crypto\_key | The Customer Managed Crypto Key for the crypto boundary. |
| data\_access\_level\_name | Access context manager access level name. |
| data\_governance\_access\_level\_name | Access context manager access level name. |
| data\_governance\_service\_perimeter\_name | Access context manager service perimeter name. |
| data\_ingestion\_access\_level\_name | Access context manager access level name. |
| data\_ingestion\_bucket\_name | The name of the bucket created for the data ingestion pipeline. |
| data\_ingestion\_cloudfunction\_bucket\_name | The name of the bucket created for cloud function in the data ingestion pipeline. |
| data\_ingestion\_dataflow\_bucket\_name | The name of the staging bucket created for dataflow in the data ingestion pipeline. |
| data\_ingestion\_service\_perimeter\_name | Access context manager service perimeter name. |
| data\_ingestion\_topic\_name | The topic created for data ingestion pipeline. |
| data\_service\_perimeter\_name | Access context manager service perimeter name. |
| dataflow\_controller\_service\_account\_email | The Dataflow controller service account email. Required to deploy Dataflow jobs. See https://cloud.google.com/dataflow/docs/concepts/security-and-permissions#specifying_a_user-managed_controller_service_account. |
| dataset | The BigQuery Dataset for the Data project. |
| dataset\_id | The ID of the dataset created for the Data project. |
| dlp\_output\_dataset | The Dataset ID for DLP output data. |
| pubsub\_writer\_service\_account\_email | The PubSub writer service account email. Should be used to write data to the PubSub topics the data ingestion pipeline reads from. |
| storage\_writer\_service\_account\_email | The Storage writer service account email. Should be used to write data to the buckets the data ingestion pipeline reads from. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Requirements

These sections describe requirements for using this blueprint.

**Note:** Please see the [Disclaimer](#disclaimer) regarding **project owners** before creating projects.

### Software

The following dependencies must be available:

- [Google Cloud SDK](https://cloud.google.com/sdk/install) version 357.0.0 or later
- [Terraform](https://www.terraform.io/downloads.html) version 0.13.7 or later
- [Terraform Provider for GCP](https://github.com/terraform-providers/terraform-provider-google) version 4.61 or later
- [Terraform Provider for GCP Beta](https://github.com/terraform-providers/terraform-provider-google-beta) version 4.61 or later

### Security Groups

Provide the following groups for separation of duty.
Each group will be granted roles to perform their tasks.
Add users to the appropriate groups as needed.

- **Data Engineer group**: Google Cloud IAM group that sets up and maintains the data pipeline and warehouse.
- **Data Analyst group**: Google Cloud IAM group that analyzes the data in the warehouse.
- **Security Analyst group**: Google Cloud IAM group that monitors and responds to security incidents.
- **Network Administrator group**: Google Cloud IAM group that reviews network configuration. Typically, this includes members of the networking team.
- **Security Administrator group**: Google Cloud IAM group that administers security configurations in the organization(org policies, KMS, VPC service perimeter).
- **Encrypted Data Reader Group**: Google Cloud IAM group that analyzes encrypted data.
- **Plain Text Reader Group**: Google Cloud IAM group that analyzes plaintext reader.

Groups can be created in the Google [Workspace Admin Console](https://support.google.com/a/answer/9400082?hl=en), in the Google [Cloud Console](https://cloud.google.com/iam/docs/groups-in-cloud-console), or using gcloud identity [groups create](https://cloud.google.com/sdk/gcloud/reference/identity/groups/create) command.

**Note 1:** Groups **Data Engineer** and **Data Analyst** are granted the role "Service Account User" on the [Dataflow controller](https://cloud.google.com/dataflow/docs/concepts/security-and-permissions#specifying_a_user-managed_controller_service_account) service account, the one in the `dataflow_controller_service_account_email` output.
This is required to be able to run dataflow jobs in the Data Ingestion project.

See the [Dataflow Jobs Deployment](./docs/deploying_dataflow_jobs.md) documentation for additional information on deploying Dataflow Jobs.

**Note 2:** The group **Plain Text Reader Group** is the only group tha should be granted access to the KMS keys used to encrypt the data.

### Service Account

To provision the resources of this module, you must create a privileged service account, where the service account key cannot be created.
In addition, consider using Google Cloud Monitoring to alert on this service account's activity.
Grant the following roles to the service account.

- Organization level
  - Access Context Manager Admin: `roles/accesscontextmanager.policyAdmin`
  - Organization Policy Administrator: `roles/orgpolicy.policyAdmin`
  - Organization Administrator: `roles/resourcemanager.organizationAdmin`
- Project level:
  - Data ingestion project
    - App Engine Creator:`roles/appengine.appCreator`
    - Cloud Scheduler Admin:`roles/cloudscheduler.admin`
    - Compute Network Admin:`roles/compute.networkAdmin`
    - Compute Security Admin:`roles/compute.securityAdmin`
    - Dataflow Developer:`roles/dataflow.developer`
    - DNS Administrator:`roles/dns.admin`
    - Project IAM Admin:`roles/resourcemanager.projectIamAdmin`
    - Pub/Sub Admin:`roles/pubsub.admin`
    - Service Account Admin:`roles/iam.serviceAccountAdmin`
    - Service Account Token Creator:`roles/iam.serviceAccountTokenCreator`
    - Service Usage Admin: `roles/serviceusage.serviceUsageAdmin`
    - Storage Admin:`roles/storage.admin`
  - Data governance project
    - Cloud KMS Admin:`roles/cloudkms.admin`
    - Cloud KMS CryptoKey Encrypter:`roles/cloudkms.cryptoKeyEncrypter`
    - DLP De-identify Templates Editor:`roles/dlp.deidentifyTemplatesEditor`
    - DLP Inspect Templates Editor:`roles/dlp.inspectTemplatesEditor`
    - DLP User:`roles/dlp.user`
    - Data Catalog Admin:`roles/datacatalog.admin`
    - Project IAM Admin:`roles/resourcemanager.projectIamAdmin`
    - Secret Manager Admin: `roles/secretmanager.admin`
    - Service Account Admin:`roles/iam.serviceAccountAdmin`
    - Service Account Token Creator:`roles/iam.serviceAccountTokenCreator`
    - Service Usage Admin: `roles/serviceusage.serviceUsageAdmin`
    - Storage Admin:`roles/storage.admin`
  - Data project
    - BigQuery Admin:`roles/bigquery.admin`
    - Compute Network Admin:`roles/compute.networkAdmin`
    - Compute Security Admin:`roles/compute.securityAdmin`
    - DNS Administrator:`roles/dns.admin`
    - Dataflow Developer:`roles/dataflow.developer`
    - Project IAM Admin:`roles/resourcemanager.projectIamAdmin`
    - Service Account Admin:`roles/iam.serviceAccountAdmin`
    - Service Account Token Creator:`roles/iam.serviceAccountTokenCreator`
    - Service Usage Admin: `roles/serviceusage.serviceUsageAdmin`
    - Storage Admin:`roles/storage.admin`

You can use the [Project Factory module](https://github.com/terraform-google-modules/terraform-google-project-factory) and the
[IAM module](https://github.com/terraform-google-modules/terraform-google-iam) in combination to provision.
These modules can be used to provision a service account with the necessary roles applied.

The user who uses this service account must be granted the [IAM roles necessary to impersonate](https://cloud.google.com/iam/docs/service-account-permissions) the service account.

### APIs

Create three projects with the following APIs enabled to host the
resources created by this module:

#### Data ingestion project

- Access Context Manager API: `accesscontextmanager.googleapis.com`
- App Engine Admin API:`appengine.googleapis.com`
- Artifact Registry API:`artifactregistry.googleapis.com`
- BigQuery API:`bigquery.googleapis.com`
- Cloud Billing API:`cloudbilling.googleapis.com`
- Cloud Build API:`cloudbuild.googleapis.com`
- Cloud Key Management Service (KMS) API:`cloudkms.googleapis.com`
- Cloud Resource Manager API:`cloudresourcemanager.googleapis.com`
- Cloud Scheduler API:`cloudscheduler.googleapis.com`
- Compute Engine API:`compute.googleapis.com`
- Google Cloud Data Catalog API:`datacatalog.googleapis.com`
- Dataflow API:`dataflow.googleapis.com`
- Cloud Data Loss Prevention (DLP) API:`dlp.googleapis.com`
- Cloud DNS API:`dns.googleapis.com`
- Identity and Access Management (IAM) API:`iam.googleapis.com`
- Cloud Pub/Sub API:`pubsub.googleapis.com`
- Service Usage API:`serviceusage.googleapis.com`
- Google Cloud Storage JSON API:`storage-api.googleapis.com`

#### Data governance project

- Access Context Manager API: `accesscontextmanager.googleapis.com`
- Cloud Billing API:`cloudbilling.googleapis.com`
- Cloud Key Management Service (KMS) API:`cloudkms.googleapis.com`
- Cloud Resource Manager API:`cloudresourcemanager.googleapis.com`
- Google Cloud Data Catalog API:`datacatalog.googleapis.com`
- Cloud Data Loss Prevention (DLP) API:`dlp.googleapis.com`
- Identity and Access Management (IAM) API:`iam.googleapis.com`
- Service Usage API:`serviceusage.googleapis.com`
- Google Cloud Storage JSON API:`storage-api.googleapis.com`
- Secret Manager API: `secretmanager.googleapis.com`

#### Data project

- Access Context Manager API: `accesscontextmanager.googleapis.com`
- Artifact Registry API:`artifactregistry.googleapis.com`
- BigQuery API:`bigquery.googleapis.com`
- Cloud Billing API:`cloudbilling.googleapis.com`
- Cloud Build API:`cloudbuild.googleapis.com`
- Cloud Key Management Service (KMS) API:`cloudkms.googleapis.com`
- Cloud Resource Manager API:`cloudresourcemanager.googleapis.com`
- Compute Engine API:`compute.googleapis.com`
- Google Cloud Data Catalog API:`datacatalog.googleapis.com`
- Dataflow API:`dataflow.googleapis.com`
- Cloud Data Loss Prevention (DLP) API:`dlp.googleapis.com`
- Cloud DNS API:`dns.googleapis.com`
- Identity and Access Management (IAM) API:`iam.googleapis.com`
- Service Usage API:`serviceusage.googleapis.com`
- Google Cloud Storage JSON API:`storage-api.googleapis.com`

#### The following APIs must be enabled in the project where the service account was created

- Access Context Manager API: `accesscontextmanager.googleapis.com`
- App Engine Admin API: `appengine.googleapis.com`
- Cloud Billing API:`cloudbilling.googleapis.com`
- Cloud Key Management Service (KMS) API:`cloudkms.googleapis.com`
- Cloud Pub/Sub API: `pubsub.googleapis.com`
- Cloud Resource Manager API:`cloudresourcemanager.googleapis.com`
- Compute Engine API:`compute.googleapis.com`
- Dataflow API:`dataflow.googleapis.com`
- Identity and Access Management (IAM) API:`iam.googleapis.com`
- Service Usage API:`serviceusage.googleapis.com`

You can use the [Project Factory module](https://github.com/terraform-google-modules/terraform-google-project-factory) to
provision the projects with the necessary APIs enabled.

## Contributing

Refer to the [contribution guidelines](./CONTRIBUTING.md) for
information on contributing to this module.


## Security Disclosures

Please see our [security disclosure process](./SECURITY.md).

---
This is not an officially supported Google product

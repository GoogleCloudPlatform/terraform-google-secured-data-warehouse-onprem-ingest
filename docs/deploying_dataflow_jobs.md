# Deploying Dataflow jobs

This document provides guidance on how to deploy Dataflow jobs using the infrastructure created by the blueprint.
The blueprint uses uses [VPC Service Controls](https://cloud.google.com/vpc-service-controls/docs/service-perimeters) to protect the Google Services.
For general information related to Dataflow jobs see [Deploying a Pipeline](https://cloud.google.com/dataflow/docs/guides/deploying-a-pipeline).

## User access

The user or service account deploying the Dataflow pipeline must be in the [access level](https://cloud.google.com/access-context-manager/docs/create-basic-access-level#members-example) of the VPC Service Controls perimeter.
Use the input `perimeter_additional_members` to add the user or service account to the perimeter. Groups are not allowed in a VPC Service Controls perimeter.

The blueprint creates an egress rule that allows access to an external repository to fetch Dataflow templates.
To use this egress rule you must:
- Provide the project number of the project that hosts the external repository in the variable `sdx_project_number`
- Add the user or service account deploying the Dataflow job in the variable `data_ingestion_dataflow_deployer_identities`. The terraform service account is automatically added to this rule.

To use external repositories in more then one project, create a copy of the [default egress rule](https://github.com/GoogleCloudPlatform/terraform-google-secured-data-warehouse-onprem-ingest/blob/621bb4bd1f1556e7341951043cda47a4877ecb8b/service_control.tf#L171-L194) providing the project number of the other projects and add the new rule in the variable `data_ingestion_egress_policies`

## APIs

You must enable all the APIs required by the Dataflow job in the Data Ingestion project.
See the list of [APIs](../README.md#apis) enabled by default in the Data Ingestion project in the README file.

## Service Accounts Roles

You must grant all the *additional roles* required by the Data ingestion Dataflow Controller Service Account before deploying the Dataflow job.
Check the current roles associated with the Data ingestion Dataflow Controller Service Account in the files linked below:

- Data ingestion SA [roles](../modules/data-ingestion-sa/main.tf)
- Data ingestion [roles](../modules/data-ingestion/iam.tf)

## Providing a subnetwork

You must provide a [subnetwork](https://cloud.google.com/dataflow/docs/guides/specifying-networks#specifying_a_network_and_a_subnetwork)
to deploy a Dataflow job.

We do not recommend using a [Default Network](https://cloud.google.com/vpc/docs/vpc#default-network) in the Data ingestion project.

If you are using a Shared VPC, you must add the Shared VPC as a Trusted subnetworks using the `trusted_shared_vpc_subnetworks` variable. See the [inputs](../README.md#inputs) section for additional information.

The subnetwork must be configured for [Private Google Access](https://cloud.google.com/vpc/docs/configure-private-google-access).
Make sure you have configured all the [firewall rules](#firewall-rules) and [DNS configurations](#dns-configurations) listed in the sections below.

## Firewall rules

- [All the egress should be denied](https://cloud.google.com/vpc-service-controls/docs/set-up-private-connectivity#configure-firewall).
- [Allow only Restricted API Egress by TPC at 443 port](https://cloud.google.com/vpc-service-controls/docs/set-up-private-connectivity#configure-firewall).
- [Allow only Private API Egress by TPC at 443 port](https://cloud.google.com/vpc-service-controls/docs/set-up-private-connectivity#configure-firewall).
- [Allow ingress Dataflow workers by TPC at ports 12345 and 12346](https://cloud.google.com/dataflow/docs/guides/routes-firewall#example_firewall_ingress_rule).
- [Allow egress Dataflow workers by TPC at ports 12345 and 12346](https://cloud.google.com/dataflow/docs/guides/routes-firewall#example_firewall_egress_rule).

## DNS configurations

- [Restricted Google APIs](https://cloud.google.com/vpc-service-controls/docs/set-up-private-connectivity#configure-routes).
- [Private Google APIs](https://cloud.google.com/vpc/docs/configure-private-google-access).
- [Restricted gcr.io](https://cloud.google.com/vpc-service-controls/docs/set-up-gke#configure-dns).
- [Restricted Artifact Registry](https://cloud.google.com/vpc-service-controls/docs/set-up-gke#configure-dns).

## Temporary and Staging Location

Use the `data_ingestion_dataflow_bucket_name` [output](../README.md#outputs) of the main module as the Temporary and Staging Location bucket when configuring the
[pipeline options](https://cloud.google.com/dataflow/docs/guides/setting-pipeline-options#setting_required_options):

## Dataflow Worker Service Account

Use the  `dataflow_controller_service_account_email` [output](../README.md#outputs) of the main module as the
[Dataflow Controller Service Account](https://cloud.google.com/dataflow/docs/concepts/security-and-permissions#specifying_a_user-managed_worker_service_account):

__Note:__ The user or service account being used to deploy Dataflow Jobs must have `roles/iam.serviceAccountUser` in the **Dataflow Controller Service Account**.

## Customer Managed Encryption Key

Use the `cmek_data_ingestion_crypto_key` [output](../README.md#outputs) of the main module as the [Dataflow KMS Key](https://cloud.google.com/dataflow/docs/guides/customer-managed-encryption-keys):

## Disable Public IPs

[Disabling Public IPs helps to better secure you data processing infrastructure](https://cloud.google.com/dataflow/docs/guides/routes-firewall#turn_off_external_ip_address).
Make sure you have your subnetwork configured as the [Subnetwork section](#subnetwork) details.

## Enable Streaming Engine

Enabling Streaming Engine is important to ensure all the performance benefits of the infrastructure. You can learn more about it in the [documentation](https://cloud.google.com/dataflow/docs/guides/deploying-a-pipeline#streaming-engine).

## Enable Confidential Computing

Enabling Confidential Computing helps to ensure the data can't be read or modified while in use. For more information check [Confidential Computing concepts](https://cloud.google.com/confidential-computing/confidential-vm/docs/confidential-vm-overview).
You can access the list of confidential computing supported machines [here](https://cloud.google.com/confidential-computing/confidential-vm/docs/supported-configurations).

## Deploying Dataflow Flex Jobs

We recommend the usage of [Flex Job Templates](https://cloud.google.com/dataflow/docs/guides/templates/using-flex-templates).
You can learn more about the differences between Classic and Flex Templates [here](https://cloud.google.com/dataflow/docs/concepts/dataflow-templates#evaluating-which-template-type-to-use).

## Deploying with Terraform

Use the `google_dataflow_flex_template_job` [resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dataflow_flex_template_job.html).

### Deploying with `gcloud` Command

Run the following commands to create a Dataflow Flex Job using the **gcloud command**.

```sh

export PROJECT_ID=<PROJECT_ID>
export DATAFLOW_BUCKET=<DATAFLOW_BUCKET>
export DATAFLOW_KMS_KEY=<DATAFLOW_KMS_KEY>
export SERVICE_ACCOUNT_EMAIL=<SERVICE_ACCOUNT_EMAIL>
export SUBNETWORK=<SUBNETWORK_SELF_LINK>

gcloud dataflow flex-template run "TEMPLATE_NAME`date +%Y%m%d-%H%M%S`" \
    --template-file-gcs-location="TEMPLATE_NAME_LOCATION" \
    --project="${PROJECT_ID}" \
    --staging-location="${DATAFLOW_BUCKET}/staging/" \
    --temp-location="${DATAFLOW_BUCKET}/tmp/" \
    --dataflow-kms-key="${DATAFLOW_KMS_KEY}" \
    --service-account-email="${SERVICE_ACCOUNT_EMAIL}" \
    --subnetwork="${SUBNETWORK}" \
    --region="us-east4" \
    --disable-public-ips \
    --enable-streaming-engine

```

For more details about `gcloud dataflow flex-template` see the command [documentation](https://cloud.google.com/sdk/gcloud/reference/dataflow/flex-template/run).

In some parameters, such as a table schema, you may need to use the comma `,`. On these cases you need to use [gcloud topic escaping](https://cloud.google.com/sdk/gcloud/reference/topic/escaping).

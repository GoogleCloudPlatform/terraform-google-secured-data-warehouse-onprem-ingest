// Copyright 2022-2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package standalone

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-google-modules/secured-data-warehouse-onprem-ingest/test/integration/testutils"
	"github.com/tidwall/gjson"
)

func getPolicyID(t *testing.T, orgID string) string {
	gcOpts := gcloud.WithCommonArgs([]string{"--format", "value(name)"})
	op := gcloud.Run(t, fmt.Sprintf("access-context-manager policies list --organization=%s ", orgID), gcOpts)
	return op.String()
}

func getSAToken(t *testing.T, sa string) string {
	cmd := gcloud.Runf(t, "auth print-access-token --impersonate-service-account=%s", sa)
	return strings.TrimSpace(gjson.Get(cmd.String(), "token").String())
}

func getHttpResponse(t *testing.T, method, url, token string, body io.Reader) []byte {
	req, err := http.NewRequest(method, url, body)
	require.NoError(t, err)
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Add("Content-Type", "application/json")

	c := &http.Client{}
	resp, err := c.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	b, err := ioutil.ReadAll(resp.Body)
	require.NoError(t, err)
	return b
}

func TestStandalone(t *testing.T) {
	orgID := utils.ValFromEnv(t, "TF_VAR_org_id")
	policyID := getPolicyID(t, orgID)

	vars := map[string]interface{}{
		"access_context_manager_policy_id": policyID,
	}

	standalone := tft.NewTFBlueprintTest(t,
		tft.WithVars(vars),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 5*time.Minute),
	)

	standalone.DefineVerify(func(assert *assert.Assertions) {

		terraformSa := standalone.GetStringOutput("terraform_service_account")
		dataGovProjectID := standalone.GetStringOutput("data_governance_project_id")
		dataIngProjectID := standalone.GetStringOutput("data_ingestion_project_id")
		dataProjectID := standalone.GetStringOutput("data_project_id")
		templateProjectID := standalone.GetStringOutput("template_project_id")
		dataIngkmsKey := standalone.GetStringOutput("cmek_data_ingestion_crypto_key")
		dataIngBktName := standalone.GetStringOutput("data_ingestion_bucket_name")

		projects := []string{
			dataGovProjectID,
			dataIngProjectID,
			dataProjectID,
			templateProjectID,
		}

		for _, project := range projects {
			opProject := gcloud.Runf(t, "projects describe %s", project)
			assert.Equal(project, opProject.Get("projectId").String(), "should have expected projectID ")
		}

		// Check Logging bucket creation
		argsBktLog := gcloud.WithCommonArgs([]string{"--project", dataGovProjectID, "--json"})
		bktNameLog := standalone.GetStringOutput("centralized_logging_bucket_name")
		opBktLog := gcloud.Run(t, fmt.Sprintf("alpha storage ls --buckets gs://%s --impersonate-service-account=%s", bktNameLog, terraformSa), argsBktLog).Array()
		assert.Equal(bktNameLog, opBktLog[0].Get("metadata.name").String(), fmt.Sprintf("Should have the expected name:%s", bktNameLog))
		assert.Equal("US-EAST4", opBktLog[0].Get("metadata.location").String(), "Should be in the US-EAST4 location.")

		// Check Dataflow bucket creation
		argsBktDF := gcloud.WithCommonArgs([]string{"--project", dataIngProjectID, "--json"})
		bktNameDF := standalone.GetStringOutput("data_ingestion_dataflow_bucket_name")
		opBktDF := gcloud.Run(t, fmt.Sprintf("alpha storage ls --buckets gs://%s --impersonate-service-account=%s", bktNameDF, terraformSa), argsBktDF).Array()
		assert.Equal(bktNameDF, opBktDF[0].Get("metadata.name").String(), fmt.Sprintf("Should have the expected name:%s", bktNameDF))
		assert.Equal("US-EAST4", opBktDF[0].Get("metadata.location").String(), "Should be in the US-EAST4 location.")
		assert.Equal(dataIngkmsKey, opBktDF[0].Get("metadata.encryption.defaultKmsKeyName").String(), fmt.Sprintf("Should have kms key: %s", dataIngkmsKey))

		// Check Data Ingestion bucket creation
		argsBktCsv := gcloud.WithCommonArgs([]string{"--project", dataIngProjectID, "--json"})
		opBktCsv := gcloud.Run(t, fmt.Sprintf("alpha storage ls --buckets gs://%s --impersonate-service-account=%s", dataIngBktName, terraformSa), argsBktCsv).Array()
		assert.Equal(dataIngBktName, opBktCsv[0].Get("metadata.name").String(), fmt.Sprintf("Should have the expected name:%s", dataIngBktName))
		assert.Equal("US-EAST4", opBktCsv[0].Get("metadata.location").String(), "Should be in the US-EAST4 location.")
		assert.Equal(dataIngkmsKey, opBktCsv[0].Get("metadata.encryption.defaultKmsKeyName").String(), fmt.Sprintf("Should have kms key: %s", dataIngkmsKey))

		// Check Data Ingestion Pub/Sub topic creation
		dataIngTopicName := standalone.GetStringOutput("data_ingestion_topic_name")
		opPubsub := gcloud.Runf(t, "pubsub topics describe %s --project=%s --impersonate-service-account=%s", dataIngTopicName, dataIngProjectID, terraformSa)
		expectedTopicName := fmt.Sprintf("projects/%s/topics/%s", dataIngProjectID, dataIngTopicName)
		assert.Equal(expectedTopicName, opPubsub.Get("name").String(), fmt.Sprintf("Should have topic name: %s", expectedTopicName))
		assert.Equal(dataIngkmsKey, opPubsub.Get("kmsKeyName").String(), fmt.Sprintf("Should have kms key: %s", dataIngkmsKey))

		// Check Data Governance KMS resources creation
		kmsKeyRingName := standalone.GetStringOutput("cmek_keyring_name")
		kmsKeyDataBq := standalone.GetStringOutput("cmek_data_bigquery_crypto_key")
		opKMSData := gcloud.Runf(t, "kms keys describe %s --keyring=%s --project=%s --location us-east4 --impersonate-service-account=%s", kmsKeyDataBq, kmsKeyRingName, dataGovProjectID, terraformSa)
		assert.Equal(kmsKeyDataBq, opKMSData.Get("name").String(), fmt.Sprintf("should have key %s", kmsKeyDataBq))

		opKMSIngestion := gcloud.Runf(t, "kms keys describe %s --keyring=%s --project=%s --location us-east4 --impersonate-service-account=%s", dataIngkmsKey, kmsKeyRingName, dataGovProjectID, terraformSa)
		assert.Equal(dataIngkmsKey, opKMSIngestion.Get("name").String(), fmt.Sprintf("Should have key: %s", dataIngkmsKey))

		// Check firewall configuration
		denyAllEgressName := "fw-e-shared-restricted-65535-e-d-all-all-all"
		denyAllEgressRule := gcloud.Runf(t, "compute firewall-rules describe %s --project %s", denyAllEgressName, dataIngProjectID)
		assert.Equal(denyAllEgressName, denyAllEgressRule.Get("name").String(), fmt.Sprintf("Firewall rule %s should exist", denyAllEgressName))
		assert.Equal("EGRESS", denyAllEgressRule.Get("direction").String(), fmt.Sprintf("Firewall rule %s direction should be EGRESS", denyAllEgressName))
		assert.True(denyAllEgressRule.Get("logConfig.enable").Bool(), fmt.Sprintf("Firewall rule %s should have log configuration enabled", denyAllEgressName))
		assert.Equal("0.0.0.0/0", denyAllEgressRule.Get("destinationRanges").Array()[0].String(), fmt.Sprintf("Firewall rule %s destination ranges should be 0.0.0.0/0", denyAllEgressName))
		assert.Equal(1, len(denyAllEgressRule.Get("denied").Array()), fmt.Sprintf("Firewall rule %s should have only one denied", denyAllEgressName))
		assert.Equal(1, len(denyAllEgressRule.Get("denied.0").Map()), fmt.Sprintf("Firewall rule %s should have only one denied only with no ports", denyAllEgressName))
		assert.Equal("all", denyAllEgressRule.Get("denied.0.IPProtocol").String(), fmt.Sprintf("Firewall rule %s should deny all protocols", denyAllEgressName))

		allowApiEgressName := "fw-e-shared-restricted-65534-e-a-allow-google-apis-all-tcp-443"
		allowApiEgressRule := gcloud.Runf(t, "compute firewall-rules describe %s --project %s", allowApiEgressName, dataIngProjectID)
		assert.Equal(allowApiEgressName, allowApiEgressRule.Get("name").String(), fmt.Sprintf("Firewall rule %s should exist", allowApiEgressName))
		assert.Equal("EGRESS", allowApiEgressRule.Get("direction").String(), fmt.Sprintf("Firewall rule %s direction should be EGRESS", allowApiEgressName))
		assert.True(allowApiEgressRule.Get("logConfig.enable").Bool(), fmt.Sprintf("Firewall rule %s should have log configuration enabled", allowApiEgressName))
		assert.Equal(1, len(allowApiEgressRule.Get("allowed").Array()), fmt.Sprintf("Firewall rule %s should have only one allowed", allowApiEgressName))
		assert.Equal(2, len(allowApiEgressRule.Get("allowed.0").Map()), fmt.Sprintf("Firewall rule %s should have only one allowed only with protocol end ports", allowApiEgressName))
		assert.Equal("tcp", allowApiEgressRule.Get("allowed.0.IPProtocol").String(), fmt.Sprintf("Firewall rule %s should allow tcp protocol", allowApiEgressName))
		assert.Equal(1, len(allowApiEgressRule.Get("allowed.0.ports").Array()), fmt.Sprintf("Firewall rule %s should allow only one port", allowApiEgressName))
		assert.Equal("443", allowApiEgressRule.Get("allowed.0.ports.0").String(), fmt.Sprintf("Firewall rule %s should allow port 443", allowApiEgressName))

		functionId := standalone.GetStringOutput("function_id")
		opCloudFunction := gcloud.Runf(t, "functions describe cf-load-csv --region=us-east4 --project=%s --impersonate-service-account=%s", dataIngProjectID, terraformSa).Array()
		assert.Equal(functionId, opCloudFunction[0].Get("name").String(), fmt.Sprintf("Should have same id: %s", functionId))
		assert.Equal("data_dataset", opCloudFunction[0].Get("serviceConfig.environmentVariables.DATASET").String(), fmt.Sprintf("Should be in the same dataset: %s", "data_dataset"))
		assert.Equal(dataProjectID, opCloudFunction[0].Get("serviceConfig.environmentVariables.DATASET_PROJECT_ID").String(), fmt.Sprintf("Should be in the same project: %s", dataProjectID))
		assert.Equal("credit_card", opCloudFunction[0].Get("serviceConfig.environmentVariables.TABLE").String(), fmt.Sprintf("Should be in the same table: %s", "credit_card"))
		assert.Equal("GEN_2", opCloudFunction[0].Get("environment").String(), fmt.Sprintf("Should be in the same environment: %s", "GEN_2"))
		assert.Equal(dataIngBktName, opCloudFunction[0].Get("buildConfig.environmentVariables.BUCKET").String(), fmt.Sprintf("Should be in the same bucket: %s", dataIngBktName))
		assert.Equal("us-east4", opCloudFunction[0].Get("eventTrigger.triggerRegion").String(), fmt.Sprintf("Should be in the same region: %s", "us-east4"))

		kekKeyName := standalone.GetStringOutput("kek_wrapping_key_name")
		kekKeyringName := standalone.GetStringOutput("kek_wrapping_keyring_name")
		kek_Keyring := standalone.GetStringOutput("kek_wrapping_keyring")
		expectedKekKey := fmt.Sprintf("%s/cryptoKeys/%s", kek_Keyring, kekKeyName)
		opKekKey := gcloud.Runf(t, "kms keys describe %s --keyring=%s --project=%s --location us-east4 --impersonate-service-account=%s", kekKeyName, kekKeyringName, dataGovProjectID, terraformSa)
		assert.Equal(expectedKekKey, opKekKey.Get("name").String(), fmt.Sprintf("Should have key: %s", expectedKekKey))

		opVPCConnector := gcloud.Runf(t, "compute networks vpc-access connectors describe con-cf-data-ingestion --region=us-east4 --project=%s --impersonate-service-account=%s", dataIngProjectID, terraformSa)
		vpcConnectorNames := fmt.Sprintf("projects/%s/locations/us-east4/connectors/con-cf-data-ingestion", dataIngProjectID)
		assert.Equal(vpcConnectorNames, opVPCConnector.Get("name").String(), fmt.Sprintf("Should have same id: %s", vpcConnectorNames))
		assert.Equal("e2-micro", opVPCConnector.Get("machineType").String(), "Should have same machineType: e2-micro")
		assert.Equal("7", opVPCConnector.Get("maxInstances").String(), "Should have maxInstances equals to 7")
		assert.Equal("2", opVPCConnector.Get("minInstances").String(), "Should have minInstances equals to 2")
		assert.Equal("700", opVPCConnector.Get("maxThroughput").String(), "Should have maxThroughput equals to 700")
		assert.Equal("200", opVPCConnector.Get("minThroughput").String(), "Should have minThroughput equals to 200")

		csvJobId := standalone.GetStringOutput("csv_load_job_id")
		opBigqueryJob := gcloud.Runf(t, "alpha bq jobs list --show-all-users --project=%s   --impersonate-service-account=%s", dataProjectID, terraformSa).Array()
		assert.Equal(csvJobId, opBigqueryJob[0].Get("jobReference.jobId").String(), fmt.Sprintf("Should have name: %s", csvJobId))
		assert.Equal("us-east4", opBigqueryJob[0].Get("jobReference.location").String(), fmt.Sprintf("Should be in the same location: %s", "us-east4"))
		assert.Equal(dataProjectID, opBigqueryJob[0].Get("jobReference.projectId").String(), fmt.Sprintf("Should be in the same project: %s", dataProjectID))

		opDataset := gcloud.Runf(t, "alpha bq tables describe credit_card --dataset data_dataset --project %s --impersonate-service-account=%s", dataProjectID, terraformSa)
		fullTablePath := fmt.Sprintf("%s:data_dataset.credit_card", dataProjectID)
		assert.Equal(fullTablePath, opDataset.Get("id").String(), fmt.Sprintf("Should have same id: %s", fullTablePath))
		assert.Equal("us-east4", opDataset.Get("location").String(), fmt.Sprintf("Should have same location: %s", "us-east4"))

		opView := gcloud.Runf(t, "alpha bq tables describe decrypted_view --dataset data_dataset --project %s --impersonate-service-account=%s", dataProjectID, terraformSa)
		fullViewPath := fmt.Sprintf("%s:data_dataset.decrypted_view", dataProjectID)
		assert.Equal(fullViewPath, opView.Get("id").String(), fmt.Sprintf("View should have same id: %s", fullViewPath))
		assert.Equal("us-east4", opView.Get("location").String(), fmt.Sprintf("View should have same location: %s", "us-east4"))

		taxonomyName := standalone.GetStringOutput("taxonomy_name")
		opTaxonomies := gcloud.Runf(t, "data-catalog taxonomies list --location us-east4 --project %s  --impersonate-service-account=%s", dataGovProjectID, terraformSa).Array()
		assert.Equal(taxonomyName, opTaxonomies[0].Get("name").String(), fmt.Sprintf("Should have same name: %s", taxonomyName))

		opPubsubSubscription := gcloud.Runf(t, "pubsub subscriptions describe pubsub_to_bigquery_subscription --project=%s --impersonate-service-account=%s", dataIngProjectID, terraformSa).Array()
		expectedPubsubname := fmt.Sprintf("projects/%s/subscriptions/pubsub_to_bigquery_subscription", dataIngProjectID)
		assert.Equal(expectedPubsubname, opPubsubSubscription[0].Get("name").String(), fmt.Sprintf("Should have same name: %s", expectedPubsubname))

		serverlessToVpcConnector := "serverless-to-vpc-connector"
		serverlessToVpcConnectorRule := gcloud.Runf(t, "compute firewall-rules describe %s --project %s", serverlessToVpcConnector, dataIngProjectID)
		assert.Equal(serverlessToVpcConnector, serverlessToVpcConnectorRule.Get("name").String(), fmt.Sprintf("Firewall rule %s should exist", serverlessToVpcConnector))
		assert.Equal("INGRESS", serverlessToVpcConnectorRule.Get("direction").String(), fmt.Sprintf("Firewall rule %s direction should be INGRESS", serverlessToVpcConnector))
		assert.True(serverlessToVpcConnectorRule.Get("logConfig.enable").Bool(), fmt.Sprintf("Firewall rule %s should have log configuration enabled", serverlessToVpcConnector))
		assert.Equal("vpc-connector", serverlessToVpcConnectorRule.Get("targetTags").Array()[0].String(), fmt.Sprintf("Firewall rule %s should have target tags", serverlessToVpcConnector))
		assert.Equal("107.178.230.64/26", serverlessToVpcConnectorRule.Get("sourceRanges").Array()[0].String(), fmt.Sprintf("Firewall rule %s source ranges should be 107.178.230.64/26", serverlessToVpcConnector))
		assert.Equal("35.199.224.0/19", serverlessToVpcConnectorRule.Get("sourceRanges").Array()[1].String(), fmt.Sprintf("Firewall rule %s source ranges should be 35.199.224.0/19", serverlessToVpcConnector))
		assert.Equal("665", serverlessToVpcConnectorRule.Get("allowed.1.ports.0").String(), fmt.Sprintf("Firewall rule %s should allow port 665", serverlessToVpcConnector))
		assert.Equal("666", serverlessToVpcConnectorRule.Get("allowed.1.ports.1").String(), fmt.Sprintf("Firewall rule %s should allow port 666", serverlessToVpcConnector))
		assert.Equal("667", serverlessToVpcConnectorRule.Get("allowed.2.ports.0").String(), fmt.Sprintf("Firewall rule %s should allow port 667", serverlessToVpcConnector))

		vpcConnectorRequests := "vpc-connector-requests"
		vpcConnectorRequestsRule := gcloud.Runf(t, "compute firewall-rules describe %s --project %s", vpcConnectorRequests, dataIngProjectID)
		assert.Equal(vpcConnectorRequests, vpcConnectorRequestsRule.Get("name").String(), fmt.Sprintf("Firewall rule %s should exist", vpcConnectorRequests))
		assert.Equal("INGRESS", vpcConnectorRequestsRule.Get("direction").String(), fmt.Sprintf("Firewall rule %s direction should be INGRESS", vpcConnectorRequests))
		assert.True(vpcConnectorRequestsRule.Get("logConfig.enable").Bool(), fmt.Sprintf("Firewall rule %s should have log configuration enabled", vpcConnectorRequests))
		assert.Equal("vpc-connector", vpcConnectorRequestsRule.Get("sourceTags").Array()[0].String(), fmt.Sprintf("Firewall rule %s should have target tags", vpcConnectorRequests))

		vpcConnectorToServerless := "vpc-connector-to-serverless"
		vpcConnectorToServerlessRule := gcloud.Runf(t, "compute firewall-rules describe %s --project %s", vpcConnectorToServerless, dataIngProjectID)
		assert.Equal(vpcConnectorToServerless, vpcConnectorToServerlessRule.Get("name").String(), fmt.Sprintf("Firewall rule %s should exist", vpcConnectorToServerless))
		assert.Equal("EGRESS", vpcConnectorToServerlessRule.Get("direction").String(), fmt.Sprintf("Firewall rule %s direction should be EGRESS", vpcConnectorToServerless))
		assert.True(vpcConnectorToServerlessRule.Get("logConfig.enable").Bool(), fmt.Sprintf("Firewall rule %s should have log configuration enabled", vpcConnectorToServerless))
		assert.Equal("vpc-connector", vpcConnectorToServerlessRule.Get("targetTags").Array()[0].String(), fmt.Sprintf("Firewall rule %s should have target tags", vpcConnectorToServerless))
		assert.Equal("107.178.230.64/26", vpcConnectorToServerlessRule.Get("destinationRanges").Array()[0].String(), fmt.Sprintf("Firewall rule %s destination ranges should be 107.178.230.64/26", vpcConnectorRequests))
		assert.Equal("35.199.224.0/19", vpcConnectorToServerlessRule.Get("destinationRanges").Array()[1].String(), fmt.Sprintf("Firewall rule %s source ranges should be 35.199.224.0/19", vpcConnectorToServerless))
		assert.Equal("665", vpcConnectorToServerlessRule.Get("allowed.1.ports.0").String(), fmt.Sprintf("Firewall rule %s should allow port 665", vpcConnectorToServerless))
		assert.Equal("666", vpcConnectorToServerlessRule.Get("allowed.1.ports.1").String(), fmt.Sprintf("Firewall rule %s should allow port 666", vpcConnectorToServerless))
		assert.Equal("667", vpcConnectorToServerlessRule.Get("allowed.2.ports.0").String(), fmt.Sprintf("Firewall rule %s should allow port 667", vpcConnectorToServerless))

		vpcConnectorToLB := "vpc-connector-to-lb"
		vpcConnectorToLBRule := gcloud.Runf(t, "compute firewall-rules describe %s --project %s", vpcConnectorToLB, dataIngProjectID)
		assert.Equal(vpcConnectorToLB, vpcConnectorToLBRule.Get("name").String(), fmt.Sprintf("Firewall rule %s should exist", vpcConnectorToLB))
		assert.Equal("EGRESS", vpcConnectorToLBRule.Get("direction").String(), fmt.Sprintf("Firewall rule %s direction should be EGRESS", vpcConnectorToLB))
		assert.True(vpcConnectorToLBRule.Get("logConfig.enable").Bool(), fmt.Sprintf("Firewall rule %s should have log configuration enabled", vpcConnectorToLB))
		assert.Equal("vpc-connector", vpcConnectorToLBRule.Get("targetTags").Array()[0].String(), fmt.Sprintf("Firewall rule %s should have target tags", vpcConnectorToLB))
		assert.Equal("0.0.0.0/0", vpcConnectorToLBRule.Get("destinationRanges").Array()[0].String(), fmt.Sprintf("Firewall rule %s destination ranges should be 0.0.0.0/0", vpcConnectorToLB))
		assert.Equal("80", vpcConnectorToLBRule.Get("allowed.0.ports.0").String(), fmt.Sprintf("Firewall rule %s should allow port 80", vpcConnectorToLB))

		vpcConnectorToHealthchecks := "vpc-connector-health-checks"
		vpcConnectorToHealthchecksRule := gcloud.Runf(t, "compute firewall-rules describe %s --project %s", vpcConnectorToHealthchecks, dataIngProjectID)
		assert.Equal(vpcConnectorToHealthchecks, vpcConnectorToHealthchecksRule.Get("name").String(), fmt.Sprintf("Firewall rule %s should exist", vpcConnectorToHealthchecks))
		assert.Equal("INGRESS", vpcConnectorToHealthchecksRule.Get("direction").String(), fmt.Sprintf("Firewall rule %s direction should be INGRESS", vpcConnectorToHealthchecks))
		assert.True(vpcConnectorToHealthchecksRule.Get("logConfig.enable").Bool(), fmt.Sprintf("Firewall rule %s should have log configuration enabled", vpcConnectorToHealthchecks))
		assert.Equal("vpc-connector", vpcConnectorToHealthchecksRule.Get("targetTags").Array()[0].String(), fmt.Sprintf("Firewall rule %s should have target tags", vpcConnectorToHealthchecks))
		assert.Equal("130.211.0.0/22", vpcConnectorToHealthchecksRule.Get("sourceRanges").Array()[0].String(), fmt.Sprintf("Firewall rule %s source ranges should be 130.211.0.0/22", vpcConnectorToLB))
		assert.Equal("35.191.0.0/16", vpcConnectorToHealthchecksRule.Get("sourceRanges").Array()[1].String(), fmt.Sprintf("Firewall rule %s source ranges should be 35.191.0.0/16", vpcConnectorToLB))
		assert.Equal("108.170.220.0/23", vpcConnectorToHealthchecksRule.Get("sourceRanges").Array()[2].String(), fmt.Sprintf("Firewall rule %s source ranges should be 108.170.220.0/23", vpcConnectorToLB))
		assert.Equal("667", vpcConnectorToHealthchecksRule.Get("allowed.0.ports.0").String(), fmt.Sprintf("Firewall rule %s should allow port 667", vpcConnectorToHealthchecks))

		// validate jobTriggers
		token := getSAToken(t, terraformSa)
		url := fmt.Sprintf("https://dlp.googleapis.com/v2/projects/%s/locations/us-east4/jobTriggers", dataGovProjectID)
		body := getHttpResponse(t, "GET", url, token, nil)

		var jobTriggerResp struct {
			JobTriggers []struct {
				Name string `json:"name"`
			} `json:"jobTriggers"`
		}
		err := json.Unmarshal(body, &jobTriggerResp)
		assert.NoError(err)
		jobTriggerName := jobTriggerResp.JobTriggers[0].Name

		dlpJobId := standalone.GetStringOutput("dlp_job_id")
		assert.Equal(dlpJobId, jobTriggerName, "JobTrigger name does not match")

		// validate BQ project CMEK
		bqUrl := fmt.Sprintf("https://bigquery.googleapis.com/bigquery/v2/projects/%s/queries", dataProjectID)

		bqRBody := []byte(`{
			"query":"select option_value from region-us-east4.INFORMATION_SCHEMA.PROJECT_OPTIONS where option_name=\"default_kms_key_name\"",
			"useLegacySql": false
		}`)

		queryBody := getHttpResponse(t, "POST", bqUrl, token, bytes.NewBuffer(bqRBody))

		var queryResp struct {
			Rows []struct {
				F []struct {
					V string `json:"v"`
				} `json:"f"`
			} `json:"rows"`
		}
		err = json.Unmarshal(queryBody, &queryResp)
		assert.NoError(err)
		cmek := queryResp.Rows[0].F[0].V
		assert.Equal(kmsKeyDataBq, cmek, "CMEK should match")

	})

	standalone.Test()
}

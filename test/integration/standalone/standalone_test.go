// Copyright 2022 Google LLC
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
	"fmt"
	"strings"
	"testing"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/stretchr/testify/assert"
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

func TestStandalone(t *testing.T) {
	orgID := utils.ValFromEnv(t, "TF_VAR_org_id")
	policyID := getPolicyID(t, orgID)

	vars := map[string]interface{}{
		"access_context_manager_policy_id": policyID,
	}

	standalone := tft.NewTFBlueprintTest(t,
		tft.WithVars(vars),
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
	})

	standalone.Test()
}

// Copyright 2023 Google LLC
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

package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"flag"
	"io"
	"log"
	"os"
	"strings"

	"github.com/google/tink/go/aead"
	"github.com/google/tink/go/core/registry"
	"github.com/google/tink/go/integration/gcpkms"
	"github.com/google/tink/go/keyset"
	"github.com/google/tink/go/tink"
)

var (
	encrypter tink.HybridEncrypt
)

// generator config
type genCfg struct {
	in           string
	out          string
	fields       string
	keyset       string
	masterKeyURI string
}

func parseFlags() genCfg {
	var c genCfg
	flag.StringVar(&c.in, "in", "", "Filename to read json data.")
	flag.StringVar(&c.out, "out", "", "Filename to write encrypted json data.")
	flag.StringVar(&c.fields, "fields", "", "Comma-separated list of JSON field names that need to be encrypted. i.e. \"Card Type Full Name,Issuing Bank\"")
	flag.StringVar(&c.keyset, "keyset", "keyset", "Keyset filename to be used to encrypt the data.")
	flag.StringVar(&c.masterKeyURI, "master-key-uri", "", "URI of the master key. Format: 'gcp-kms://projects/PROJECT_ID/locations/LOCATION/keyRings/KEYRING/cryptoKeys/KEY'.")
	flag.Parse()
	if c.fields == "" {
		log.Fatal("fields flag is missing. Please set fields flag that is a comma-separated list of JSON field names that need to be encrypted. i.e. -fields \"Card Type Full Name,Issuing Bank\"")
	}
	if c.keyset == "" {
		log.Fatal("Keyset filename to be used to encrypt the data is missing.")
	}
	if c.masterKeyURI == "" {
		log.Fatal("URI of the master key is missing.")
	}
	if c.in == "" {
		log.Fatal("Input json filename is missing.")
	}
	if c.out == "" {
		log.Fatal("Output json filename is missing.")
	}
	return c
}

func loadMasterKeyFromKMS(ctx context.Context, c genCfg) (tink.AEAD, error) {
	// Fetch the master key from a KMS.
	gcpClient, err := gcpkms.NewClientWithOptions(ctx, c.masterKeyURI)
	if err != nil {
		log.Fatal(err)
	}
	registry.RegisterKMSClient(gcpClient)
	masterKey, err := gcpClient.GetAEAD(c.masterKeyURI)
	if err != nil {
		log.Fatal(err)
	}

	return masterKey, err
}

func setupKeyset(ctx context.Context, c genCfg) {
	var err error

	f, err := os.Open(c.keyset)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	masterKey, errKey := loadMasterKeyFromKMS(ctx, c)
	if errKey != nil {
		log.Fatal(errKey)
	}

	keyReader := keyset.NewJSONReader(f)

	keyHandle, err := keyset.Read(keyReader, masterKey)
	if err != nil {
		log.Fatal(err)
	}

	encrypter, err = aead.New(keyHandle)
	if err != nil {
		log.Fatal(err)
	}
}

func encryptData(data string) string {
	dataInBytes := []byte(data)
	encryptionContext := []byte("")

	encryptedData, err := encrypter.Encrypt(dataInBytes, encryptionContext)
	if err != nil {
		log.Fatal(err)
	}

	return base64.StdEncoding.EncodeToString(encryptedData)
}

func main() {
	cfg := parseFlags()
	ctx := context.Background()
	setupKeyset(ctx, cfg)

	headersToEncryptList := strings.Split(cfg.fields, ",")

	out, err := os.OpenFile(cfg.out, os.O_RDWR|os.O_CREATE|os.O_TRUNC, 0755)
	if err != nil {
		log.Fatal(err)
	}
	defer out.Close()

	in, err := os.Open(cfg.in)
	if err != nil {
		panic(err)
	}
	defer in.Close()

	inReader := json.NewDecoder(in)
	outJsonWriter := json.NewEncoder(out)
	for {
		var jsonLine map[string]string
		if err := inReader.Decode(&jsonLine); 	err == io.EOF {
			break // done decoding file
		} else if err != nil {
			log.Fatal(err)
		}

		for _, colToEncrypt := range headersToEncryptList {
			jsonLine[colToEncrypt] = encryptData(jsonLine[colToEncrypt])
		}

		err = outJsonWriter.Encode(jsonLine)
		if err != nil {
			log.Fatal(err)
		}
	}
}

// Copyright 2023-2025 Google LLC
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
	"encoding/csv"
	"flag"
	"io"
	"log"
	"os"
	"strings"

	"github.com/tink-crypto/tink-go-gcpkms/v2/integration/gcpkms"
	"github.com/tink-crypto/tink-go/v2/aead"
	"github.com/tink-crypto/tink-go/v2/core/registry"
	"github.com/tink-crypto/tink-go/v2/keyset"
	"github.com/tink-crypto/tink-go/v2/tink"
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
	flag.StringVar(&c.in, "in", "", "Filename to read csv data.")
	flag.StringVar(&c.out, "out", "", "Filename to write encrypted csv data.")
	flag.StringVar(&c.fields, "fields", "", "Comma-separated list of CSV header names that need to be encrypted. i.e. \"Card Type Full Name,Issuing Bank\"")
	flag.StringVar(&c.keyset, "keyset", "keyset", "Keyset filename to be used to encrypt the data.")
	flag.StringVar(&c.masterKeyURI, "master-key-uri", "", "URI of the master key. Format: 'gcp-kms://projects/PROJECT_ID/locations/LOCATION/keyRings/KEYRING/cryptoKeys/KEY'.")
	flag.Parse()
	if c.fields == "" {
		log.Fatal("fields flag is missing. Please set fields flag that is a comma-separated list of CSV header names that need to be encrypted. i.e. -fields \"Card Type Full Name,Issuing Bank\"")
	}
	if c.keyset == "" {
		log.Fatal("Keyset filename to be used to encrypt the data is missing.")
	}
	if c.masterKeyURI == "" {
		log.Fatal("URI of the master key is missing.")
	}
	if c.in == "" {
		log.Fatal("Input csv filename is missing.")
	}
	if c.out == "" {
		log.Fatal("Output csv filename is missing.")
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
	headersToEncryptMap := make(map[string]int)

	for _, val := range headersToEncryptList {
		headersToEncryptMap[strings.ToLower(val)] = 0
	}

	in, err := os.Open(cfg.in)
	if err != nil {
		panic(err)
	}
	defer in.Close()

	inReader := csv.NewReader(in)

	headersInCsv, err := inReader.Read()
	if err != nil {
		log.Fatal(err)
	}

	headersToEncrypt := make(map[int]int)

	for index, value := range headersInCsv {
		if _, hasKeyInMap := headersToEncryptMap[strings.ToLower(value)]; !hasKeyInMap {
			continue
		}
		headersToEncrypt[index] = 0
	}

	out, err := os.OpenFile(cfg.out, os.O_RDWR|os.O_CREATE|os.O_TRUNC, 0755)
	if err != nil {
		log.Fatal(err)
	}
	defer out.Close()

	outCsvWriter := csv.NewWriter(out)
	defer outCsvWriter.Flush()

	err = outCsvWriter.Write(headersInCsv)
	if err != nil {
		log.Fatal(err)
	}

	for {
		csvLine, err := inReader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			log.Fatal(err)
		}

		for colToEncryptIndex := range headersToEncrypt {
			csvLine[colToEncryptIndex] = encryptData(csvLine[colToEncryptIndex])
		}

		err = outCsvWriter.Write(csvLine)
		if err != nil {
			log.Fatal(err)
		}
	}
}

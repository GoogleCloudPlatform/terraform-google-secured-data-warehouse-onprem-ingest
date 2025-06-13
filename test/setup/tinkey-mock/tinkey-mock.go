// Copyright 2023-2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"context"
	"errors"
	"flag"
	"log"
	"os"
	"strings"

	"github.com/tink-crypto/tink-go-gcpkms/v2/integration/gcpkms"
	"github.com/tink-crypto/tink-go/v2/aead"
	"github.com/tink-crypto/tink-go/v2/core/registry"
	"github.com/tink-crypto/tink-go/v2/daead"
	"github.com/tink-crypto/tink-go/v2/keyset"
	tinkpb "github.com/tink-crypto/tink-go/v2/proto/tink_go_proto"
)

// generator config
type keyCfg struct {
	keyTemplate  string
	out          string
	outFormat    string
	masterKeyURI string
}

func parseFlags() keyCfg {
	var c keyCfg
	flag.StringVar(&c.keyTemplate, "key-template", "", "The key template name: AES256_GCM or AES256_SIV.")
	flag.StringVar(&c.out, "out", "", "The output filename, must not exist, to write the keyset to.")
	flag.StringVar(&c.outFormat, "out-format", "json", "The output format: json or binary (case-insensitive). json is default")
	flag.StringVar(&c.masterKeyURI, "master-key-uri", "", "URI of the master key. Format: 'gcp-kms://projects/PROJECT_ID/locations/LOCATION/keyRings/KEYRING/cryptoKeys/KEY'.")
	flag.Parse()
	if c.masterKeyURI == "" {
		log.Fatal("URI of the master key is missing.")
	}
	if c.keyTemplate == "" {
		log.Fatal("Key template type is missing.")
	}
	if c.out == "" {
		log.Fatal("Output filename is missing.")
	}
	return c
}

func getKeyTemplate(keyTemplate string) (*tinkpb.KeyTemplate, error) {
	switch keyTemplate {
	case "AES256_GCM":
		return aead.AES128GCMKeyTemplate(), nil
	case "AES256_SIV":
		return daead.AESSIVKeyTemplate(), nil
	default:
		return nil, errors.New("invalid key template option")
	}
}

func getKeyWriter(outFormat string, f *os.File) (keyset.Writer, error) {
	switch strings.ToUpper(outFormat) {
	case "JSON":
		return keyset.NewJSONWriter(f), nil
	case "BINARY":
		return keyset.NewBinaryWriter(f), nil
	default:
		return nil, errors.New("invalid out format")
	}
}

func main() {
	cfg := parseFlags()
	var err error

	// create output file
	_, err = os.Stat(cfg.out)
	if err == nil {
		log.Fatal(errors.New("output file must not exist"))
	}
	f, err := os.Create(cfg.out)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	// load master key
	ctx := context.Background()
	gcpClient, err := gcpkms.NewClientWithOptions(ctx, cfg.masterKeyURI)
	if err != nil {
		log.Fatal(err)
	}
	registry.RegisterKMSClient(gcpClient)

	masterKey, err := gcpClient.GetAEAD(cfg.masterKeyURI)
	if err != nil {
		log.Fatal(err)
	}

	// generate a new key.
	template, err := getKeyTemplate(cfg.keyTemplate)
	if err != nil {
		log.Fatal(err)
	}
	keyHandle, err := keyset.NewHandle(template)
	if err != nil {
		log.Fatal(err)
	}

	keyWriter, err := getKeyWriter(cfg.outFormat, f)
	if err != nil {
		log.Fatal(err)
	}

	if err := keyHandle.Write(keyWriter, masterKey); err != nil {
		log.Fatal(err)
	}

}

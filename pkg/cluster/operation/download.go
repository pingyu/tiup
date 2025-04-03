// Copyright 2020 PingCAP, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// See the License for the specific language governing permissions and
// limitations under the License.

package operator

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/pingcap/errors"
	"github.com/pingcap/tiup/pkg/cluster/clusterutil"
	"github.com/pingcap/tiup/pkg/cluster/spec"
	"github.com/pingcap/tiup/pkg/utils"
)

// Download the specific version of a component from
// the repository, there is nothing to do if the specified version exists.
func Download(component, nodeOS, arch string, version string, baseImage string) error {
	if component == "" {
		return errors.New("component name not specified")
	}
	if version == "" {
		return errors.Errorf("version not specified for component '%s'", component)
	}

	resName := fmt.Sprintf("%s-%s", component, version)
	fileName := fmt.Sprintf("%s-%s-%s.tar.gz", resName, nodeOS, arch)
	targetPath := spec.ProfilePath(spec.TiUPPackageCacheDir, fileName)

	if err := utils.MkdirAll(spec.ProfilePath(spec.TiUPPackageCacheDir), 0o755); err != nil {
		return err
	}

	repo, err := clusterutil.NewRepository(nodeOS, arch)
	if err != nil {
		return err
	}

	// Download from repository if not exists
	if utils.IsNotExist(targetPath) {
		var err error
		if baseImage == "" {
			err = repo.DownloadComponent(component, version, targetPath)
		} else {
			err = downloadFromDockerHub(component, nodeOS, arch, baseImage, version, targetPath)
		}
		if err != nil {
			return err
		}
	} else if baseImage == "" && version != "nightly" {
		if err := repo.VerifyComponent(component, version, targetPath); err != nil {
			os.Remove(targetPath)
		}
	}
	return nil
}

func downloadFromDockerHub(component, nodeOS, arch string, baseImage, version string, targetPath string) error {
	platform := nodeOS + "/" + arch
	path := baseImage + ":" + version
	cmd := exec.Command("docker", "pull", "--platform", platform, path)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	if err != nil {
		return errors.Annotatef(err, "%s: failed to pull docker image %s", component, path)
	}

	binaryName := dockerBinaryName(component)
	cmdStr := fmt.Sprintf("id=$(docker create --platform %s %s)"+
		" && docker cp \"$id\":%s - | tar -x"+
		" && tar czf %s %s"+
		" && docker rm -v $id", platform, path, binaryName, targetPath, binaryName)
	cmd = exec.Command("bash", "-c", cmdStr)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err = cmd.Run()
	return errors.Annotatef(err, "%s: failed to extract docker image %s", component, path)
}

func dockerBinaryName(component string) string {
	switch component {
	case spec.ComponentPD:
		return "pd-server"
	case spec.ComponentTiKV:
		return "tikv-server"
	case spec.ComponentTiDB:
		return "tidb-server"
	case spec.ComponentTiKVWorker:
		return "tikv-worker"
	default:
		return component
	}
}

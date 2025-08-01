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

package localdata

import (
	"os"
	"path"
	"testing"

	"github.com/google/uuid"
	"github.com/pingcap/tiup/pkg/utils"
	"github.com/stretchr/testify/require"
)

func TestResetMirror(t *testing.T) {
	uuid := uuid.New().String()
	root := path.Join("/tmp", uuid)
	_ = os.Mkdir(root, 0o755)
	_ = os.Mkdir(path.Join(root, "bin"), 0o755)
	defer os.RemoveAll(root)

	cfg, _ := InitConfig(root)
	profile := NewProfile(root, cfg)

	require.NoError(t, profile.ResetMirror("https://tiup-mirrors.pingcap.com", ""))
	require.Error(t, profile.ResetMirror("https://example.com", ""))
	require.NoError(t, profile.ResetMirror("https://example.com", "https://tiup-mirrors.pingcap.com/root.json"))

	require.NoError(t, utils.Copy(path.Join(root, "bin"), path.Join(root, "mock-mirror")))

	require.NoError(t, profile.ResetMirror(path.Join(root, "mock-mirror"), ""))
	require.Error(t, profile.ResetMirror(root, ""))
	require.NoError(t, profile.ResetMirror(root, path.Join(root, "mock-mirror", "root.json")))
}

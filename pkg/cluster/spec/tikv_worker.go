// Copyright 2022 PingCAP, Inc.
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

package spec

import (
	"context"
	"crypto/tls"
	"fmt"
	"path/filepath"
	"strings"
	"time"

	"github.com/pingcap/tiup/pkg/cluster/ctxt"
	"github.com/pingcap/tiup/pkg/cluster/template/scripts"
	"github.com/pingcap/tiup/pkg/meta"
	"github.com/pingcap/tiup/pkg/utils"
)

// TiKVWorkerSpec represents the TiKVWorker topology specification in topology.yaml
type TiKVWorkerSpec struct {
	Host            string               `yaml:"host"`
	ManageHost      string               `yaml:"manage_host,omitempty" validate:"manage_host:editable"`
	SSHPort         int                  `yaml:"ssh_port,omitempty" validate:"ssh_port:editable"`
	Imported        bool                 `yaml:"imported,omitempty"`
	Patched         bool                 `yaml:"patched,omitempty"`
	IgnoreExporter  bool                 `yaml:"ignore_exporter,omitempty"`
	Port            int                  `yaml:"port" default:"19000"`
	DeployDir       string               `yaml:"deploy_dir,omitempty"`
	LogDir          string               `yaml:"log_dir,omitempty"`
	Offline         bool                 `yaml:"offline,omitempty"`
	Source          string               `yaml:"source,omitempty" validate:"source:editable"`
	NumaNode        string               `yaml:"numa_node,omitempty" validate:"numa_node:editable"`
	Config          map[string]any       `yaml:"config,omitempty" validate:"config:ignore"`
	ResourceControl meta.ResourceControl `yaml:"resource_control,omitempty" validate:"resource_control:editable"`
	Arch            string               `yaml:"arch,omitempty"`
	OS              string               `yaml:"os,omitempty"`
}

// Role returns the component role of the instance
func (s *TiKVWorkerSpec) Role() string {
	return ComponentTiKVWorker
}

// SSH returns the host and SSH port of the instance
func (s *TiKVWorkerSpec) SSH() (string, int) {
	host := s.Host
	if s.ManageHost != "" {
		host = s.ManageHost
	}
	return host, s.SSHPort
}

// GetMainPort returns the main port of the instance
func (s *TiKVWorkerSpec) GetMainPort() int {
	return s.Port
}

// GetManageHost returns the manage host of the instance
func (s *TiKVWorkerSpec) GetManageHost() string {
	if s.ManageHost != "" {
		return s.ManageHost
	}
	return s.Host
}

// IsImported returns if the node is imported from TiDB-Ansible
func (s *TiKVWorkerSpec) IsImported() bool {
	// TiDB-Ansible do not support TiKV-Worker
	return false
}

// IgnoreMonitorAgent returns if the node does not have monitor agents available
func (s *TiKVWorkerSpec) IgnoreMonitorAgent() bool {
	return s.IgnoreExporter
}

// TiKVWorkerComponent represents TiKV-Worker component.
type TiKVWorkerComponent struct{ Topology *Specification }

// Name implements Component interface.
func (c *TiKVWorkerComponent) Name() string {
	return ComponentTiKVWorker
}

// Role implements Component interface.
func (c *TiKVWorkerComponent) Role() string {
	return ComponentTiKVWorker
}

// Source implements Component interface.
func (c *TiKVWorkerComponent) Source() string {
	source := c.Topology.ComponentSources.TiKVWorker
	if source != "" {
		return source
	}
	return ComponentTiKVWorker
}

// CalculateVersion implements the Component interface
func (c *TiKVWorkerComponent) CalculateVersion(clusterVersion string) string {
	// always not follow global version, use ""(latest) by default
	version := c.Topology.ComponentVersions.TiKVWorker
	return version
}

// SetVersion implements Component interface.
func (c *TiKVWorkerComponent) SetVersion(version string) {
	c.Topology.ComponentVersions.TiKVWorker = version
}

// Instances implements Component interface.
func (c *TiKVWorkerComponent) Instances() []Instance {
	ins := make([]Instance, 0, len(c.Topology.TiKVWorkers))
	for _, s := range c.Topology.TiKVWorkers {
		s := s
		instance := &TiKVWorkerInstance{BaseInstance{
			InstanceSpec: s,
			Name:         c.Name(),
			Host:         s.Host,
			ManageHost:   s.ManageHost,
			ListenHost:   c.Topology.BaseTopo().GlobalOptions.ListenHost,
			Port:         s.Port,
			SSHP:         s.SSHPort,
			Source:       s.Source,
			NumaNode:     s.NumaNode,
			NumaCores:    "",

			Ports: []int{
				s.Port,
			},
			Dirs: []string{
				s.DeployDir,
			},
			StatusFn: func(_ context.Context, timeout time.Duration, tlsCfg *tls.Config, _ ...string) string {
				return statusByHost(s.GetManageHost(), s.Port, "/healthz", timeout, tlsCfg)
			},
			UptimeFn: func(_ context.Context, timeout time.Duration, tlsCfg *tls.Config) time.Duration {
				return UptimeByHost(s.GetManageHost(), s.Port, timeout, tlsCfg)
			},

			Component: c,

			BaseImage: c.Topology.ComponentBaseImages.TiKVWorker,
		}, c.Topology}

		ins = append(ins, instance)
	}
	return ins
}

// TiKVWorkerInstance represent the TiKV-Worker instance.
type TiKVWorkerInstance struct {
	BaseInstance
	topo Topology
}

// ScaleConfig deploy temporary config on scaling
func (i *TiKVWorkerInstance) ScaleConfig(
	ctx context.Context,
	e ctxt.Executor,
	topo Topology,
	clusterName,
	clusterVersion,
	user string,
	paths meta.DirPaths,
) error {
	s := i.topo
	defer func() {
		i.topo = s
	}()
	i.topo = mustBeClusterTopo(topo)

	return i.InitConfig(ctx, e, clusterName, clusterVersion, user, paths)
}

// InitConfig implements Instance interface.
func (i *TiKVWorkerInstance) InitConfig(
	ctx context.Context,
	e ctxt.Executor,
	clusterName,
	clusterVersion,
	deployUser string,
	paths meta.DirPaths,
) error {
	topo := i.topo.(*Specification)
	if err := i.BaseInstance.InitConfig(ctx, e, topo.GlobalOptions, deployUser, paths); err != nil {
		return err
	}
	enableTLS := topo.GlobalOptions.TLSEnabled
	spec := i.InstanceSpec.(*TiKVWorkerSpec)
	globalConfig := topo.ServerConfigs.TiKVWorker
	instanceConfig := spec.Config
	instanceConfig = SetDfsConfigs(instanceConfig, topo.GlobalOptions.Dfs)

	pds := []string{}
	for _, pdspec := range topo.PDServers {
		pds = append(pds, pdspec.GetAdvertiseClientURL(enableTLS))
	}
	cfg := &scripts.TiKVWorkerScript{
		Addr:       utils.JoinHostPort(i.GetHost(), spec.Port),
		PD:         strings.Join(pds, ","),
		TLSEnabled: enableTLS,

		DeployDir: paths.Deploy,
		LogDir:    paths.Log,

		NumaNode: spec.NumaNode,
	}

	// doesn't work.
	if _, err := i.setTLSConfig(ctx, false, nil, paths); err != nil {
		return err
	}

	fp := filepath.Join(paths.Cache, fmt.Sprintf("run_tikv_worker_%s_%d.sh", i.GetHost(), i.GetPort()))

	if err := cfg.ConfigToFile(fp); err != nil {
		return err
	}
	dst := filepath.Join(paths.Deploy, "scripts", "run_tikv_worker.sh")
	if err := e.Transfer(ctx, fp, dst, false, 0, false); err != nil {
		return err
	}

	if _, _, err := e.Execute(ctx, "chmod +x "+dst, false); err != nil {
		return err
	}

	return i.MergeServerConfig(ctx, e, globalConfig, instanceConfig, paths)
}

// setTLSConfig set TLS Config to support enable/disable TLS
func (i *TiKVWorkerInstance) setTLSConfig(ctx context.Context, enableTLS bool, configs map[string]any, paths meta.DirPaths) (map[string]any, error) {
	return nil, nil
}

var _ RollingUpdateInstance = &TiKVWorkerInstance{}

// PreRestart implements RollingUpdateInstance interface.
// All errors are ignored, to trigger hard restart.
func (i *TiKVWorkerInstance) PreRestart(ctx context.Context, topo Topology, apiTimeoutSeconds int, tlsCfg *tls.Config) error {
	return nil
}

// PostRestart implements RollingUpdateInstance interface.
func (i *TiKVWorkerInstance) PostRestart(ctx context.Context, topo Topology, tlsCfg *tls.Config) error {
	return nil
}

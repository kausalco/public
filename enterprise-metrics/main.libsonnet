local cortex =
  (import 'github.com/grafana/cortex-jsonnet/cortex/cortex.libsonnet')
  + (import 'github.com/grafana/cortex-jsonnet/cortex/gossip.libsonnet')
  + (import 'github.com/grafana/cortex-jsonnet/cortex/tsdb.libsonnet')
  + {
    _config+:: {
      // Remove the alertmanagerStorageConfig from Cortex as this library provides its own config interface.
      alertmanagerStorageClientConfig:: {},
      alertmanager_enabled: true,
      // Remove the blocksStorageConfig from Cortex as this library provides its own config interface.
      blocksStorageConfig:: {},
      // No resources should have a pre-configured namespace. These should be removed with removeNamespaceReferences.
      // TODO: Remove upstream.
      namespace:: 'namespace',
      ringConfig+: {
        // Hide the consul hostname because it isn't used with memberlist.
        'consul.hostname':: '',
      },
      ingester+: {
        wal_dir: '/data',
      },
      memcached_chunks_enabled: true,
      memcached_index_queries_enabled: true,
      memcached_metadata_enabled: true,
      // Remove the rulerClientConfig from Cortex as this library provides its own config interface.
      rulerClientConfig: {},
      ruler_enabled: true,
    },
    alertmanager_args+:: {
      // Memberlist gossip is used instead of consul for the ring.
      'alertmanager.sharding-ring.consul.hostname':: null,
      'alertmanager.sharding-ring.prefix':: null,
      'alertmanager.sharding-ring.store': 'memberlist',
    },
    compactor_args+:: {
      // Memberlist gossip is used instead of consul for the ring.
      'compactor.ring.consul.hostname':: null,
      'compactor.ring.prefix':: null,
      'compactor.ring.store': 'memberlist',
    },
    distributor_args+:: {
      // Disable the ha-tracker by default.
      'distributor.ha-tracker.enable':: null,
      'distributor.ha-tracker.enable-for-all-users':: null,
      'distributor.ha-tracker.store':: null,
      'distributor.ha-tracker.etcd.endpoints':: null,
      'distributor.ha-tracker.prefix':: null,
      // Memberlist gossip is used instead of consul for the ring.
      'distributor.ring.consul.hostname':: null,
      // TODO: upstream this to github.com/grafana/cortex-jsonnet/cortex/gossip.libsonnet.
      'distributor.ring.store': 'memberlist',
    },
    querier_args+:: {
      // Memberlist gossip is used instead of consul for the ring.
      'store-gateway.sharding-ring.consul.hostname':: null,
      'store-gateway.sharding-ring.prefix':: null,
      'store-gateway.sharding-ring.store': 'memberlist',
    },
    ruler_args+:: {
      // Memberlist gossip is used instead of consul for the ring.
      'ruler.ring.consul.hostname':: null,
      'ruler.ring.prefix':: null,
      'ruler.ring.store': 'memberlist',
      // Remove ruler limits configuration.
      'ruler.max-rule-groups-per-tenant':: null,
      'ruler.max-rules-per-rule-group':: null,
      'store-gateway.sharding-ring.consul.hostname':: null,
      'store-gateway.sharding-ring.prefix':: null,
      'store-gateway.sharding-ring.store': 'memberlist',
    },
    store_gateway_args+:: {
      // Memberlist gossip is used instead of consul for the ring.
      'store-gateway.sharding-ring.consul.hostname':: null,
      'store-gateway.sharding-ring.prefix':: null,
      'store-gateway.sharding-ring.store': 'memberlist',
    },
  };
local d = import 'github.com/jsonnet-libs/docsonnet/doc-util/main.libsonnet';
local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet',
      configMap = k.core.v1.configMap,
      container = k.core.v1.container,
      deployment = k.apps.v1.deployment,
      job = k.batch.v1.job,
      policyRule = k.rbac.v1.policyRule,
      persistentVolumeClaim = k.core.v1.persistentVolumeClaim,
      role = k.rbac.v1.role,
      roleBinding = k.rbac.v1.roleBinding,
      subject = k.rbac.v1.subject,
      service = k.core.v1.service,
      serviceAccount = k.core.v1.serviceAccount,
      statefulSet = k.apps.v1.statefulSet;
local util = (import 'github.com/grafana/jsonnet-libs/ksonnet-util/util.libsonnet').withK(k);

// removeNamespaceReferences removes the cluster domain and namespace from container arguments.
local removeNamespaceReferences(args) = std.map(function(arg) std.strReplace(arg, '.namespace.svc.cluster.local', ''), args);


{
  '#':: d.pkg(
    name='enterprise-metrics',
    url='github.com/grafana/jsonnet-libs/enterprise-metrics/main.libsonnet',
    help='`enterprise-metrics` produces Kubernetes manifests for a Grafana Enterprise Metrics cluster.',
  ),
  local this = self,

  '#_config':: d.obj('`_config` is used for consumer overrides and configuration. Similar to a Helm values.yaml file'),
  _config:: {
    '#commonArgs':: d.obj('`commonArgs` is a convenience field that can be used to modify the container arguments of all modules as key-value pairs.'),
    commonArgs:: {
      'admin.client.backend-type': error 'you must set the `admin.client.backend-type` flag to an object storage backend ("gcs"|"s3")',
      'admin.client.gcs.bucket-name': 'admin',
      'admin.client.s3.bucket-name': 'admin',
      '#auth.enabled':: d.val(default=self['auth.enabled'], help='`auth.enabled` enables the tenant authentication', type=d.T.bool),
      'auth.enabled': true,
      '#auth.type':: d.val(
        default=self['auth.type'], help=|||
          `auth.type` configures the type of authentication in use.
          `enterprise` uses Grafana Enterprise token authentication.
          `default` uses Cortex authentication.
        |||, type=d.T.bool
      ),
      'auth.type': 'enterprise',
      'blocks-storage.backend': error 'you must set the `blocks-storage.backend` flag to an object storage backend ("gcs"|"s3")',
      'blocks-storage.gcs.bucket-name': 'tsdb',
      'blocks-storage.s3.bucket-name': 'tsdb',
      '#cluster-name':: d.val(
        default=self['cluster-name'],
        help='`cluster-name` is the cluster name associated with your Grafana Enterprise Metrics license.',
        type=d.T.string
      ),
      'cluster-name': error 'you must set the `cluster-name` flag to the cluster name associated with your Grafana Enterprise Metrics license',
      '#memberlist.join':: d.val(
        default=self['memberlist.join'],
        help='`memberlist.join` is an address used to find memberlist peers for ring gossip',
        type=d.T.string
      ),
      'memberlist.join': 'gossip-ring',
      // Remove 'limits-per-user-override-config' flag and use 'runtime-config.file' instead.
      // TODO: remove this when upstream uses 'runtime-config.file'.
      'limits.per-user-override-config':: null,
      '#runtime-config.file':: d.val(
        help='`runtime-config.file` provides a reloadable runtime configuration file for some specific configuration.',
        type=d.T.string
      ),
      'runtime-config.file': '/etc/enterprise-metrics/runtime.yml',
      'store.engine': 'blocks',
    },

    '#licenseSecretName':: d.val(
      default=self.licenseSecretName,
      help=|||
        The admin-api expects a Grafana Enterprise Metrics license configured as 'license.jwt' in the
        Kubernetes Secret with `licenseSecretName`.
        To create the Kubernetes Secret from a local 'license.jwt' file:
        $ kubectl create secret generic gem-license -from-file=license.jwt
      |||,
      type=d.T.string,
    ),
    licenseSecretName: 'gem-license',
  },
  '#_images':: d.obj('`_images` contains fields for container images.'),
  _images:: {
    '#gem':: d.val(default=self.gem, help='`gem` is the Grafana Enterprise Metrics container image.', type=d.T.string),
    gem: 'grafana/metrics-enterprise:v1.3.0',
    '#kubectl':: d.val(default=self.kubectl, help='`kubectl` is the image used for kubectl containers.', type=d.T.string),
    kubectl: 'bitnami/kubectl',
  },

  '#adminApi':: d.obj('`adminApi` has configuration for the admin-api.'),
  adminApi: {
    '#args':: d.obj('`args` is a convenience field that can be used to modify the admin-api container arguments as key value pairs.'),
    args:: this._config.commonArgs {
      '#bootstrap.license.path':: d.val(
        default=self['bootstrap.license.path'],
        help='`bootstrap.license.path` configures where the admin-api expects to find a Grafana Enterprise Metrics License.',
        type=d.T.string
      ),
      'bootstrap.license.path': '/etc/gem-license/license.jwt',
      target: 'admin-api',
    },
    '#container':: d.obj('`container` is a convenience field that can be used to modify the admin-api container.'),
    container::
      container.new('admin-api', image=this._images.gem)
      + container.withArgs(util.mapToFlags(self.args))
      + container.withPorts(cortex.util.defaultPorts)
      + container.resources.withLimits({ cpu: '2', memory: '4Gi' })
      + container.resources.withRequests({ cpu: '500m', memory: '1Gi' })
      + cortex.util.readinessProbe,
    '#deployment':: d.obj('`deployment` is the Kubernetes Deployment for the admin-api.'),
    deployment:
      deployment.new(name='admin-api', replicas=1, containers=[self.container])
      + deployment.spec.selector.withMatchLabelsMixin({ name: 'admin-api' })
      + deployment.spec.template.metadata.withLabelsMixin({ name: 'admin-api', gossip_ring_member: 'true' })
      + deployment.spec.template.spec.withTerminationGracePeriodSeconds(15)
      + util.configVolumeMount('runtime', '/etc/enterprise-metrics')
      + util.secretVolumeMount(this._config.licenseSecretName, '/etc/gem-license/'),
    '#service':: d.obj('`service` is the Kubernetes Service for the admin-api.'),
    service:
      util.serviceFor(self.deployment),
  },

  '#alertmanager':: d.obj('`alertmanager` has configuration for the alertmanager. To disable the alertmanager, ensure the alertmanager object field is hidden'),
  alertmanager: {
    local alertmanager = self,
    '#args':: d.obj('`args` is a convenience field that can be used to modify the alertmanager container arguments as key-value pairs.'),
    args:: cortex.alertmanager_args + this._config.commonArgs + {
      'alertmanager-storage.backend':
        if 'alertmanager-storage.backend' in super then
          super['alertmanager-storage.backend']
        else error 'you must set the `alertmanager-storage.backend` flag to an object storage backend ("azure"|"local"|"gcs"|"s3")',
      '#alertmanager-storage.s3.bucket-name':: d.val(
        default=self['alertmanager-storage.s3.bucket-name'],
        help='`alertmanager-storage.s3.bucket-name` is the name of the bucket in which the alertmanager data will be stored.',
        type=d.T.string
      ),
      'alertmanager-storage.s3.bucket-name': 'alertmanager',
      'alertmanager.web.external-url': error 'you must set the `alertmanager.web.external-url` flag in order to run an Alertmanager.',
    },
    '#container':: d.obj('`container` is a convenience field that can be used to modify the alertmanager container.'),
    container::
      cortex.alertmanager_container
      + container.withArgs(removeNamespaceReferences(util.mapToFlags(alertmanager.args)))
      + container.withImage(this._images.gem),
    '#persistentVolumeClaim':: d.obj('`persistentVolumeClaim` is a convenience field that can be used to modify the alertmanager PersistentVolumeClaim.'),
    persistentVolumeClaim:: cortex.alertmanager_pvc,
    '#statefulSet':: d.obj('`statefulSet` is the Kubernetes StatefulSet for the alertmanager.'),
    statefulSet:
      cortex.alertmanager_statefulset { metadata+: { namespace:: null } }  // Hide the metadata.namespace field as Tanka provides that.
      + statefulSet.spec.selector.withMatchLabelsMixin({ name: 'alertmanager' })
      + statefulSet.spec.withVolumeClaimTemplates([self.persistentVolumeClaim])
      + statefulSet.spec.template.metadata.withLabelsMixin({ name: 'alertmanager', gossip_ring_member: 'true' })
      + statefulSet.spec.template.spec.withContainers([alertmanager.container])
      // Remove Cortex volumes.
      + statefulSet.spec.template.spec.withVolumes([])
      // Replace with GEM volumes.
      + util.configVolumeMount('runtime', '/etc/enterprise-metrics'),
    '#service':: d.obj('`service` is the Kubernetes Service for the alertmanager.'),
    service: util.serviceFor(self.statefulSet),
  },

  '#compactor':: d.obj('`compactor` has configuration for the compactor.'),
  compactor: {
    local compactor = self,
    '#args':: d.obj('`args` is a convenience field that can be used to modify the compactor container arguments as key-value pairs.'),
    args:: cortex.compactor_args + this._config.commonArgs,
    '#container':: d.obj('`container` is a convenience field that can be used to modify the compactor container.'),
    container::
      cortex.compactor_container
      + container.withArgs(removeNamespaceReferences(util.mapToFlags(compactor.args)))
      + container.withImage(this._images.gem),
    '#persistentVolumeClaim':: d.obj('`persistentVolumeClaim` is a convenience field that can be used to modify the compactor PersistentVolumeClaim.'),
    persistentVolumeClaim::
      persistentVolumeClaim.new()
      + persistentVolumeClaim.mixin.spec.resources.withRequests({ storage: '250Gi' })
      + persistentVolumeClaim.mixin.spec.withAccessModes(['ReadWriteOnce'])
      + persistentVolumeClaim.mixin.metadata.withName('compactor-data'),
    '#statefulSet':: d.obj('`statefulSet` is the Kubernetes StatefulSet for the compactor.'),
    statefulSet:
      cortex.compactor_statefulset { metadata+: { namespace:: null } }  // Hide the metadata.namespace field as Tanka provides that.
      + statefulSet.spec.withVolumeClaimTemplates([self.persistentVolumeClaim])
      + statefulSet.spec.selector.withMatchLabelsMixin({ name: 'compactor' })
      + statefulSet.spec.template.metadata.withLabelsMixin({ name: 'compactor', gossip_ring_member: 'true' })
      + statefulSet.spec.template.spec.withContainers([compactor.container])
      + util.configVolumeMount('runtime', '/etc/enterprise-metrics'),
    '#service':: d.obj('`service` is the Kubernetes Service for the compactor.'),
    service: util.serviceFor(self.statefulSet),
  },

  '#distributor':: d.obj('`distributor` has configuration for the distributor.'),
  distributor: {
    local distributor = self,
    '#args':: d.obj('`args` is a convenience field that can be used to modify the distributor container arguments as key-value pairs.'),
    args:: cortex.distributor_args + this._config.commonArgs,
    '#container':: d.obj('`container` is a convenience field that can be used to modify the distributor container.'),
    container::
      cortex.distributor_container
      + container.withArgs(removeNamespaceReferences(util.mapToFlags(distributor.args)))
      + container.withImage(this._images.gem),
    '#statefulSet':: d.obj('`deployment` is the Kubernetes Deployment for the distributor.'),
    deployment:
      cortex.distributor_deployment
      + deployment.spec.selector.withMatchLabelsMixin({ name: 'distributor' })
      + deployment.spec.template.metadata.withLabelsMixin({ name: 'distributor', gossip_ring_member: 'true' })
      + deployment.spec.template.spec.withContainers([distributor.container])
      // Remove Cortex volumes.
      + deployment.spec.template.spec.withVolumes([])
      // Replace with GEM volumes.
      + util.configVolumeMount('runtime', '/etc/enterprise-metrics'),
    '#service':: d.obj('`service` is the Kubernetes Service for the distributor.'),
    service:
      util.serviceFor(self.deployment)
      + service.spec.withClusterIp('None'),
  },

  '#gateway':: d.obj('`gateway` has configuration for the gateway.'),
  gateway: {
    '#args':: d.obj('`args` is a convenience field that can be used to modify the gateway container arguments as key-value pairs.'),
    args:: this._config.commonArgs {
      '#gateway.proxy.admin-api.url':: d.val(
        default=self['gateway.proxy.admin-api.url'], help='`gateway.proxy.admin-api.url is the upstream URL of the admin-api.', type=d.T.string
      ),
      'gateway.proxy.admin-api.url': 'http://admin-api',
      '#gateway.proxy.compactor.url':: d.val(
        default=self['gateway.proxy.compactor.url'], help='`gateway.proxy.compactor.url is the upstream URL of the compactor.', type=d.T.string
      ),
      'gateway.proxy.compactor.url': 'http://compactor',
      '#gateway.proxy.distributor.url':: d.val(
        default=self['gateway.proxy.distributor.url'], help='`gateway.proxy.distributor.url is the upstream URL of the distributor.', type=d.T.string
      ),
      '#gateway.proxy.alertmanager.url':: d.val(
        default=self['gateway.proxy.alertmanager.url'], help='`gateway.proxy.alertmanager.url is the upstream URL of the alertmanager.', type=d.T.string
      ),
      'gateway.proxy.alertmanager.url': 'http://alertmanager',
      'gateway.proxy.distributor.url': 'dns:///distributor:9095',
      '#gateway.proxy.ingester.url':: d.val(
        default=self['gateway.proxy.ingester.url'], help='`gateway.proxy.ingester.url is the upstream URL of the ingester.', type=d.T.string
      ),
      'gateway.proxy.ingester.url': 'http://ingester',
      '#gateway.proxy.ruler.url':: d.val(
        default=self['gateway.proxy.ruler.url'], help='`gateway.proxy.ruler.url is the upstream URL of the ruler.', type=d.T.string
      ),
      'gateway.proxy.ruler.url': 'http://ruler',
      '#gateway.proxy.query-frontend.url':: d.val(
        default=self['gateway.proxy.query-frontend.url'], help='`gateway.proxy.query-frontend.url is the upstream URL of the query-frontend.', type=d.T.string
      ),
      'gateway.proxy.query-frontend.url': 'http://query-frontend',
      '#gateway.proxy.store-gateway.url':: d.val(
        default=self['gateway.proxy.store-gateway.url'], help='`gateway.proxy.store-gateway.url is the upstream URL of the store-gateway.', type=d.T.string
      ),
      'gateway.proxy.store-gateway.url': 'http://store-gateway',
      target: 'gateway',
    },

    '#container':: d.obj('`container` is a convenience field that can be used to modify the gateway container.'),
    container::
      container.new('gateway', this._images.gem)
      + container.withArgs(util.mapToFlags(self.args))
      + container.withPorts(cortex.util.defaultPorts)
      + container.resources.withLimits({ cpu: '2', memory: '4Gi' })
      + container.resources.withRequests({ cpu: '500m', memory: '1Gi' })
      + cortex.util.readinessProbe,
    '#deployment':: d.obj('`deployment` is the Kubernetes Deployment for the gateway.'),
    deployment:
      deployment.new('gateway', 3, [self.container]) +
      deployment.spec.template.spec.withTerminationGracePeriodSeconds(15)
      + util.configVolumeMount('runtime', '/etc/enterprise-metrics'),
    '#service':: d.obj('`service` is the Kubernetes Service for the gateway.'),
    service:
      util.serviceFor(self.deployment),
  },

  '#gossipRing':: d.obj('`gossipRing` is used by microservices to discover other memberlist members.'),
  gossipRing: {
    '#service':: d.obj('`service` is the Kubernetes Service for the gossip ring.'),
    service:
      cortex.gossip_ring_service
      // Publish not ready addresses for initial memberlist start up.
      + service.spec.withPublishNotReadyAddresses(true),
  },

  '#ingester':: d.obj('`ingester` has configuration for the ingester.'),
  ingester: {
    local ingester = self,
    '#args':: d.obj('`args` is a convenience field that can be used to modify the ingester container arguments as key-value pairs.'),
    args:: cortex.ingester_args + this._config.commonArgs,
    '#container':: d.obj('`container` is a convenience field that can be used to modify the ingester container.'),
    container::
      cortex.ingester_statefulset_container
      + container.withArgs(removeNamespaceReferences(util.mapToFlags(ingester.args)))
      + container.withImage(this._images.gem)
      + container.withVolumeMounts([{ name: 'ingester-data', mountPath: '/data' }]),
    '#persistentVolumeClaim':: d.obj('`persistentVolumeClaim` is a convenience field that can be used to modify the ingester PersistentVolumeClaim. It is recommended to use a fast storage class.'),
    persistentVolumeClaim::
      persistentVolumeClaim.new()
      + persistentVolumeClaim.mixin.spec.resources.withRequests({ storage: '100Gi' })
      + persistentVolumeClaim.mixin.spec.withAccessModes(['ReadWriteOnce'])
      + persistentVolumeClaim.mixin.metadata.withName('ingester-data'),
    '#podDisruptionBudget':: d.obj('`podDisruptionBudget` is the Kubernetes PodDisruptionBudget for the ingester.'),
    podDisruptionBudget: cortex.ingester_pdb,
    '#statefulSet':: d.obj('`statefulSet` is the Kubernetes StatefulSet for the ingester.'),
    statefulSet:
      cortex.ingester_statefulset { metadata+: { namespace:: null } }  // Hide the metadata.namespace field as Tanka provides that.
      + statefulSet.spec.withVolumeClaimTemplates([self.persistentVolumeClaim])
      + statefulSet.spec.selector.withMatchLabelsMixin({ name: 'ingester' })
      + statefulSet.spec.template.metadata.withLabelsMixin({ name: 'ingester', gossip_ring_member: 'true' })
      + statefulSet.spec.template.spec.withContainers([ingester.container])
      // Remove Cortex volumes.
      + statefulSet.spec.template.spec.withVolumes([])
      // Replace with GEM volumes.
      + util.configVolumeMount('runtime', '/etc/enterprise-metrics'),
    '#service':: d.obj('`service` is the Kubernetes Service for the ingester.'),
    service: util.serviceFor(self.statefulSet),
  },

  '#memcached':: d.obj('`memcached` has configuration for GEM caches.'),
  memcached: {
    '#chunks':: d.obj('`chunks` is a cache for time series chunks.'),
    chunks: cortex.memcached_chunks,
    '#metadata':: d.obj('`metadata` is cache for object store metadata used by the queriers and store-gateways.'),
    metadata: cortex.memcached_metadata,
    '#queries':: d.obj('`queries` is a cache for index queries used by the store-gateways.'),
    queries: cortex.memcached_index_queries,
  },

  '#querier':: d.obj('`querier` has configuration for the querier.'),
  querier: {
    local querier = self,
    '#args':: d.obj('`args` is a convenience field that can be used to modify the querier container arguments as key-value pairs.'),
    args:: cortex.querier_args + this._config.commonArgs {
      // Disable enterprise authentication on the querier so that query_range queries succeed.
      'auth.type': 'default',
    },
    '#container':: d.obj('`container` is a convenience field that can be used to modify the querier container.'),
    container::
      cortex.querier_container
      + container.withArgs(removeNamespaceReferences(util.mapToFlags(querier.args)))
      + container.withImage(this._images.gem),
    '#deployment':: d.obj('`deployment` is the Kubernetes Deployment for the querier.'),
    deployment:
      cortex.querier_deployment
      + deployment.spec.selector.withMatchLabelsMixin({ name: 'querier' })
      + deployment.spec.template.metadata.withLabelsMixin({ name: 'querier', gossip_ring_member: 'true' })
      + deployment.spec.template.spec.withContainers([querier.container])
      // Remove Cortex volumes.
      + deployment.spec.template.spec.withVolumes([])
      // Replace with GEM volumes.
      + util.configVolumeMount('runtime', '/etc/enterprise-metrics'),
    '#service':: d.obj('`service` is the Kubernetes Service for the querier.'),
    service: util.serviceFor(self.deployment),
  },

  '#queryFrontend':: d.obj('`queryFrontend` has configuration for the query-frontend.'),
  queryFrontend: {
    local queryFrontend = self,
    '#args':: d.obj('`args` is a convenience field that can be used to modify the query-frontend container arguments as key-value pairs.'),
    args:: cortex.query_frontend_args + this._config.commonArgs,
    '#container':: d.obj('`container` is a convenience field that can be used to modify the query-frontend container.'),
    container::
      cortex.query_frontend_container
      + container.withArgs(removeNamespaceReferences(util.mapToFlags(queryFrontend.args)))
      + container.withImage(this._images.gem),
    '#deployment':: d.obj('`deployment` is the Kubernetes Deployment for the query-frontend.'),
    deployment:
      cortex.query_frontend_deployment
      + deployment.spec.template.spec.withContainers([queryFrontend.container])
      // Remove Cortex volumes.
      + deployment.spec.template.spec.withVolumes([])
      // Replace with GEM volumes.
      + util.configVolumeMount('runtime', '/etc/enterprise-metrics'),
    '#service':: d.obj('`service` is the Kubernetes Service for the query-frontend.'),
    service: util.serviceFor(self.deployment),
    '#discoveryService':: d.obj('`discoveryService` is a headless Kubernetes Service used by queriers to discover query-frontend addresses.'),
    discoveryService:
      cortex.query_frontend_discovery_service,
  },

  '#ruler':: d.obj('`ruler` has configuration for the ruler.'),
  ruler: {
    local ruler = self,
    '#args':: d.obj('`args` is a convenience field that can be used to modify the ruler container arguments as key-value pairs.'),
    args:: cortex.ruler_args + this._config.commonArgs + {
      'ruler-storage.backend':
        if 'ruler-storage.backend' in super then
          super['ruler.storage.backend'] else
          error 'you must set the `ruler-storage.backend` flag to an object storage backend ("azure"|"local"|"gcs"|"s3")',
      '#ruler-storage.s3.bucket-name':: d.val(
        default=self['ruler-storage.s3.bucket-name'],
        help='`ruler-storage.s3.bucket-name` is the name of the bucket in which the ruler data will be stored.',
        type=d.T.string
      ),
      'ruler-storage.s3.bucket-name': 'ruler',
    },
    '#container':: d.obj('`container` is a convenience field that can be used to modify the ruler container.'),
    container::
      cortex.ruler_container
      + container.withArgs(removeNamespaceReferences(util.mapToFlags(ruler.args)))
      + container.withImage(this._images.gem),
    '#deployment':: d.obj('`deployment` is the Kubernetes Deployment for the ruler.'),
    deployment:
      cortex.ruler_deployment
      + deployment.spec.selector.withMatchLabelsMixin({ name: 'ruler' })
      + deployment.spec.template.metadata.withLabelsMixin({ name: 'ruler', gossip_ring_member: 'true' })
      + deployment.spec.template.spec.withContainers([ruler.container])
      // Remove Cortex volumes.
      + deployment.spec.template.spec.withVolumes([])
      // Replace with GEM volumes.
      + util.configVolumeMount('runtime', '/etc/enterprise-metrics'),
    '#service':: d.obj('`service` is the Kubernetes Service for the ruler.'),
    service: util.serviceFor(self.deployment),
  },

  '#runtime':: d.obj('`runtime` has configuration for runtime overrides.'),
  runtime: {
    local runtime = self,
    '#config':: d.obj('`config` is a convenience field for modifying the runtime configuration.'),
    configuration:: {
      '#overrides':: d.obj('`overrides` are per tenant runtime limits overrides.'),
      overrides: cortex._config.overrides,
    },
    '#configMap':: d.obj('`configMap` is the Kubernetes ConfigMap containing the runtime configuration.'),
    configMap: configMap.new('runtime', { 'runtime.yml': std.manifestYamlDoc(runtime.configuration) }),
  },

  '#storeGateway':: d.obj('`storeGateway` has configuration for the store-gateway.'),
  storeGateway: {
    local storeGateway = self,
    '#args':: d.obj('`args` is a convenience field that can be used to modify the store-gateway container arguments as key-value pairs.'),
    args:: cortex.store_gateway_args + this._config.commonArgs,
    '#container':: d.obj('`container` is a convenience field that can be used to modify the store-gateway container.'),
    container::
      cortex.store_gateway_container
      + container.withArgs(removeNamespaceReferences(util.mapToFlags(storeGateway.args)))
      + container.withImage(this._images.gem),
    '#persistentVolumeClaim':: d.obj('`persistentVolumeClaim` is a convenience field that can be used to modify the store-gateway PersistentVolumeClaim.'),
    persistentVolumeClaim::
      persistentVolumeClaim.new()
      + persistentVolumeClaim.mixin.spec.resources.withRequests({ storage: '100Gi' })
      + persistentVolumeClaim.mixin.spec.withAccessModes(['ReadWriteOnce'])
      + persistentVolumeClaim.mixin.metadata.withName('store-gateway-data'),
    '#podDisruptionBudget':: d.obj('`podDisruptionBudget` is the Kubernetes PodDisruptionBudget for the store-gateway.'),
    podDisruptionBudget: cortex.store_gateway_pdb,
    '#statefulSet':: d.obj('`statefulSet` is the Kubernetes StatefulSet for the store-gateway.'),
    statefulSet:
      cortex.store_gateway_statefulset { metadata+: { namespace:: null } }  // Hide the metadata.namespace field as Tanka provides that.
      + statefulSet.spec.withVolumeClaimTemplates([self.persistentVolumeClaim])
      + statefulSet.spec.selector.withMatchLabelsMixin({ name: 'store-gateway' })
      + statefulSet.spec.template.metadata.withLabelsMixin({ name: 'store-gateway', gossip_ring_member: 'true' })
      + statefulSet.spec.template.spec.withContainers([storeGateway.container])
      // Remove Cortex volumes.
      + statefulSet.spec.template.spec.withVolumes([])
      // Replace with GEM volumes.
      + util.configVolumeMount('runtime', '/etc/enterprise-metrics'),
    '#service':: d.obj('`service` is the Kubernetes Service for the store-gateway.'),
    service: util.serviceFor(self.statefulSet),
  },

  '#tokengen':: d.obj(|||
    `tokengen` has configuration for tokengen.
    By default the tokengen object is hidden as it is a one-off task. To deploy the tokengen job, unhide the tokengen object field.
  |||),
  tokengen:: {
    local target = 'tokengen',
    '#args':: d.obj('`args` is convenience field for modifying the tokegen container arguments as key-value pairs.'),
    args:: this._config.commonArgs {
      target: target,
      'tokengen.token-file': '/shared/admin-token',
    },
    '#container':: d.obj(|||
      `container` is a convenience field for modifying the tokengen container.
      By default, the container runs GEM with the tokengen target and writes the token to a file.
    |||),
    container::
      container.new(target, this._images.gem)
      + container.withPorts(cortex.util.defaultPorts)
      + container.withArgs(util.mapToFlags(self.args))
      + container.withVolumeMounts([{ mountPath: '/shared', name: 'shared' }])
      + container.resources.withLimits({ memory: '4Gi' })
      + container.resources.withRequests({ cpu: '500m', memory: '500Mi' }),

    '#createSecretContainer':: d.obj('`createSecretContainer` creates a Kubernetes Secret from a token file.'),
    createSecretContainer::
      container.new('create-secret', this._images.kubectl)
      + container.withCommand([
        '/bin/bash',
        '-euc',
        'kubectl create secret generic gem-admin-token --from-file=token=/shared/admin-token --from-literal=grafana-token="$(base64 <(echo :$(cat /shared/admin-token)))"',
      ])
      + container.withVolumeMounts([{ mountPath: '/shared', name: 'shared' }])
      // Need to run as root because the GEM container does.
      + container.securityContext.withRunAsUser(0),

    '#job':: d.obj('`job` is the Kubernetes Job for tokengen'),
    job:
      job.new(target)
      + job.spec.withCompletions(1)
      + job.spec.withParallelism(1)
      + job.spec.template.spec.withContainers([self.createSecretContainer])
      + job.spec.template.spec.withInitContainers([self.container])
      + job.spec.template.spec.withRestartPolicy('Never')
      + job.spec.template.spec.withServiceAccount(target)
      + job.spec.template.spec.withServiceAccountName(target)
      + job.spec.template.spec.withVolumes([{ name: 'shared', emptyDir: {} }]),

    '#serviceAccount':: d.obj('`serviceAccount` is the Kubernetes ServiceAccount for tokengen'),
    serviceAccount:
      serviceAccount.new(target),

    '#role':: d.obj('`role` is the Kubernetes Role for tokengen'),
    role:
      role.new(target)
      + role.withRules([
        policyRule.withApiGroups([''])
        + policyRule.withResources(['secrets'])
        + policyRule.withVerbs(['create']),
      ]),

    '#roleBinding':: d.obj('`roleBinding` is the Kubernetes RoleBinding for tokengen'),
    roleBinding:
      roleBinding.new()
      + roleBinding.metadata.withName(target)
      + roleBinding.roleRef.withApiGroup('rbac.authorization.k8s.io')
      + roleBinding.roleRef.withKind('Role')
      + roleBinding.roleRef.withName(target)
      + roleBinding.withSubjects([
        subject.new()
        + subject.withName(target)
        + subject.withKind('ServiceAccount'),
      ]),
  },
}

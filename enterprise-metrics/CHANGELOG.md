# Changelog

All notable changes to this library will be documented in this file.

Entries should be ordered as follows:
- [CHANGE]
- [FEATURE]
- [ENHANCEMENT]
- [BUGFIX]

Entries should include a reference to the Pull Request that introduced the change.

## Unreleased

- [CHANGE] The tokengen configuration is now hidden by default to avoid confusing errors when immutable fields are changed. #541
- [CHANGE] Arbitrary storage class names are removed from PersistentVolumeClaims. If you were using those storage class names, you will need to configure the storageClassName in the persistentVolume object. For example in `$.ingester.persistentVolumeClaim`. #577
- [FEATURE] Upgrade to [Grafana Enterprise Metrics v1.3.0](https://grafana.com/docs/metrics-enterprise/latest/downloads/#v130----april-26th-2021). #552
- [FEATURE] Alertmanager and ruler Kubernetes App manifests are now included. #541
- [FEATURE] PersistentVolumeClaims can be configured on all components run as a StatefulSet. This includes the alertmanager, compactor, ingester, and store-gateway components. #577
- [BUGFIX] The `gossip-ring` Service now publishes not ready addresses. #523
- [BUGFIX] All ring members now have the `gossip_ring-member` label set. #523
- [BUGFIX] All microservices now use the `gossip-ring` Service as `memberlist.join` address. #523
- [BUGFIX] `auth.type=default` is set on the `querier` to fix hanging query_range queries. #549

## 1.0.0

- [FEATURE] Initial versioned release. #TODO

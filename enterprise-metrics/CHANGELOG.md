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
- [FEATURE] Upgrade to [Grafana Enterprise Metrics v1.3.0](https://grafana.com/docs/metrics-enterprise/latest/downloads/#v130----april-26th-2021). #552
- [FEATURE] Alertmanager and ruler Kubernetes App manifests are now included. #541
- [ENHANCEMENT] Make Secret name for GEM admin token configurable via `adminTokenSecretName`. #600
- [BUGFIX] The `gossip-ring` Service now publishes not ready addresses. #523
- [BUGFIX] All ring members now have the `gossip_ring-member` label set. #523
- [BUGFIX] All microservices now use the `gossip-ring` Service as `memberlist.join` address. #523
- [BUGFIX] `auth.type=default` is set on the `querier` to fix hanging query_range queries. #549

## 1.0.0

- [FEATURE] Initial versioned release. #TODO

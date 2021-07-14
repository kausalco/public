# Usage

```jsonnet
local zk = (import './zookeeper.libsonnet');

{
    config+:: {
      namespace: 'hello-zookeeper'

    }
    zookeeper: zk {
      _config+:: $._config,
    },

}
```

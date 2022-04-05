# devkns

This script uses `k3s` for deployment of the following tools:

- `rabbitmq`
- `kafka`
- `nats`
- `elasticsearch`
- `openfaas`
- `logstash`

## [Option 1] Installation

Prerequisites: `curl`, `jq` and `nc`.

```shell
./deploy.sh -h

OPTIONS:
-r \t deploys rabbitmq.
-k \t deploys kafka.
-n \t deploys nats.
-e \t deploys elasticsearch.
-o \t deploys openfaas.
-l YAML_FILE \t deploys logstash.
-u \t uninstalls everything.
```

## [Option 2] Deploy using vagrant (recommended)

Prerequisites: `vagrant` and virtualbox (provider).

Modify script command in Vagrantfile accordingly.

Deploy and connect to the vm:
```shell
vagrant up
vagrant ssh
```

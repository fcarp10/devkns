# devkns

Deployment script:

- Communication: NATS, Kafka or RabbitMQ
- Database: Elasticsearch
- Dashboard: Kibana
- Processing: OpenFaas
- Container Orchestrator: k3s


### Helm charts

- [NATS](https://nats-io.github.io/k8s/helm/charts/)
- [Kafka (unofficial)](https://bitnami.com/stack/kafka/helm)
- [RabbitMQ (unofficial)](https://bitnami.com/stack/rabbitmq/helm)
- [OpenFaas](https://openfaas.github.io/faas-netes/)
- [Elastic](https://Helm.elastic.co)


## [Option 1] Installation

`curl` is required for the script to work. 

Default deployment install `nats` + `elasticsearch` + `openfaas`:

```shell
./deploy.sh
```

or:

```shell
./deploy.sh -c 'nats' -d 'true' -p 'true'
```
More options:

```shell
OPTIONS:
\n -c ["nats"|"kafka"|"rabbitmq"]
\t deploys nats, kafka or rabbitmq.
\n -d ["true"|"false"]
\t deploys Elasticsearch.
\n -p ["true"|"false"]
\t deploys OpenFaas.
\n -g ["true"|"false"]
\t deploys Kibana.
\n -x ["true"|"false"]
\t deploys rabbitmq --> elasticsearch connector.
```

To uninstall everything, run the following script:

```shell
/usr/local/bin/k3s-uninstall.sh
```

## [Option 2] Deploy using vagrant (recommended)

### Prerequisites 

- vagrant
- virtualbox (provider)


### Deployment

Modify Vagrantfile `deploy.sh` script accordingly:

```ruby
config.vm.provision "shell", path: "deploy.sh" 
```

Deploy and connect to the vm:
```shell
vagrant up
vagrant ssh
```

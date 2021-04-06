# devkns

This script deploys k3s, OpenFaas, Elasticsearch and NATS/Kafka on a single node.

```
-------------------------------------
openfaas | nats/kafka | elasticsearch  
-------------------------------------
                 k3s                                              
-------------------------------------
```

## Helm charts

OpenFaas
https://openfaas.github.io/faas-netes/

Elasticsearch
https://Helm.elastic.co

NATS
https://nats-io.github.io/k8s/helm/charts/

Kafka (unofficial)
https://bitnami.com/stack/kafka/helm

## Usage

### Install

#### Prerequisites: 
- curl
- faas-cli
- helm


Deploy with:

```
./deploy.sh
```

By default it deploys with nats, to use kafka instead run `./deploy.sh -k` 


### Uninstall

Run the following to uninstall everything:

```
/usr/local/bin/k3s-uninstall.sh
```
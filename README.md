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





## Test OpenFaas

Apply k3s configuration:

```shell
mkdir ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config && sudo chown $USER: ~/.kube/k3s-config && export KUBECONFIG=~/.kube/k3s-config
kubectl rollout status -n openfaas deploy/gateway
kubectl port-forward -n openfaas svc/gateway 8080:8080 &
```

Log in with faas cli:
```shell
PASSWORD=$(
    sudo kubectl get secret -n openfaas basic-auth -o jsonpath="{.data.basic-auth-password}" | base64 --decode
    echo
)
echo -n $PASSWORD | faas-cli login --username admin --password-stdin
```

Deploy and test a function:
```shell
faas deploy --image fcarp10/figlet --name figlet --fprocess "figlet"
curl http://127.0.0.1:8080/function/figlet -d "Hello World!"
```
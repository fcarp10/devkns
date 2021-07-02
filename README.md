# devkns


Script for deployment of k3s, NATS|Kafka|RabbitMQ, Elasticsearch and OpenFaas.

```
------------------------------------------------
                    functions
------------------------------------------------
 nats/kafka/rabbitmq | elasticsearch | openfaas
------------------------------------------------
                       k3s                                              
------------------------------------------------
```


### Used Helm charts

- [OpenFaas](https://openfaas.github.io/faas-netes/)
- [Elasticsearch](https://Helm.elastic.co)
- [NATS](https://nats-io.github.io/k8s/helm/charts/)
- [Kafka (unofficial)](https://bitnami.com/stack/kafka/helm)
- [RabbitMQ (unofficial)](https://bitnami.com/stack/rabbitmq/helm)




## [Option 1] Installation

`curl` is required for the script to work. To deploy `nats` + `elasticsearch` + `openfaas`:

```shell
./deploy.sh -c 'nats' -d 'true' -p 'true'
```

To deploy `rabbitmq` + `elasticsearch` only:

```shell
./deploy.sh -c 'rabbitmq' -d 'true' -p 'false'
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

Deploy and connect to the vm:
```shell
vagrant up
```
Run `vagrant ssh` to connect to the VM.





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
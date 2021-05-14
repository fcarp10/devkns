# devkns

Script for deployment of k3s, OpenFaas, Elasticsearch and NATS/Kafka.

```
-------------------------------------
             functions
-------------------------------------
openfaas | nats/kafka | elasticsearch  
-------------------------------------
                 k3s                                              
-------------------------------------

```

### Used Helm charts

- [OpenFaas](https://openfaas.github.io/faas-netes/)
- [Elasticsearch](https://Helm.elastic.co)
- [NATS](https://nats-io.github.io/k8s/helm/charts/)
- [Kafka (unofficial)](https://bitnami.com/stack/kafka/helm)

## [Option 1] Installation

`curl` is required for the script to work. Deploy with:

```
./deploy.sh
```

By default, it deploys with `NATS`. To use `Kafka` specify option: 

```
./deploy.sh -k
```

To uninstall everything, run the following script:

```
/usr/local/bin/k3s-uninstall.sh
```

## [Option 2] Deploy using vagrant (recommended)

### Prerequisites 

- vagrant
- virtualbox (provider)


### Deployment

Deploy and connect to the vm:
```
vagrant up
```
Run `vagrant ssh` to connect to the VM.


## Test

Apply k3s configuration:

```
mkdir ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config && sudo chown $USER: ~/.kube/k3s-config && export KUBECONFIG=~/.kube/k3s-config
kubectl rollout status -n openfaas deploy/gateway
kubectl port-forward -n openfaas svc/gateway 8080:8080 &
```

Log in with faas cli:
```
PASSWORD=$(
    sudo kubectl get secret -n openfaas basic-auth -o jsonpath="{.data.basic-auth-password}" | base64 --decode
    echo
)
echo -n $PASSWORD | faas-cli login --username admin --password-stdin
```

Deploy and test a function:
```
faas deploy --image fcarp10/figlet --name figlet --fprocess "figlet"
curl http://127.0.0.1:8080/function/figlet -d "Hello World!"
```
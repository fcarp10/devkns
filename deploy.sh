#!/bin/bash

source utils.sh

###############################################################################
# Author	:	Francisco Carpio
# Github	:	https://github.com/fcarp10
###############################################################################
#   DO NOT JUST RUN THIS. EXAMINE AND JUDGE. RUN AT YOUR OWN RISK.
###############################################################################

TIMER=480

BLUE='\033[0;34m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NO_COLOR='\033[0m'

function log() {
    if [[ $1 == "INFO" ]]; then
        printf "${BLUE}INFO:${NO_COLOR} %s \n" "$2"
    elif [[ $1 == "DONE" ]]; then
        printf "${GREEN}SUCCESS:${NO_COLOR} %s \n" "$2"
    elif [[ $1 == "WARN" ]]; then
        printf "${ORANGE}WARNING:${NO_COLOR} %s \n" "$2"
    else
        printf "${RED}FAILED:${NO_COLOR} %s \n" "$2"
    fi
}

usage='Usage:
'$0' [OPTION]
OPTIONS:
-r \t deploys rabbitmq.
-k \t deploys kafka.
-n \t deploys nats.
-e \t deploys elasticsearch.
-o \t deploys openfaas.
-l YAML_FILE \t deploys logstash.
-u \t uninstalls everything.
'
rabbitmq=false
kafka=false
nats=false
elasticsearch=false
openfaas=false
logstash="none"

while getopts "rkneol:u" opt; do
    case $opt in
    r)
        rabbitmq=true
        ;;
    k)
        kafka=true
        ;;
    n)
        nats=true
        ;;
    e)
        elasticsearch=true
        ;;
    o)
        openfaas=true
        ;;
    l)
        logstash+=("$OPTARG")
        ;;
    u) 
        /usr/local/bin/k3s-uninstall.sh
        exit 0
        ;;
    *)
        echo -e "Invalid option $1 \n\n${usage}"
        exit 0
        ;;
    esac
done

log "INFO" "checking tools..."
command -v curl >/dev/null 2>&1 || {
    log "ERROR" "curl not found, aborting."
    exit 1
}
command -v jq >/dev/null 2>&1 || {
    log "ERROR" "jq not found, aborting."
    exit 1
}
command -v nc >/dev/null 2>&1 || {
    log "ERROR" "nc (netcat) not found, aborting."
    exit 1
}
command -v helm >/dev/null 2>&1 || {
    log "WARN" "helm not found, installing..."
    curl -sSLf https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
}
log "DONE" "tools already installed"

# deploy k3s
export DEV_NS=dev
if hash sudo kubectl 2>/dev/null; then
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config && sudo chown $USER: ~/.kube/k3s-config && export KUBECONFIG=~/.kube/k3s-config
    kubectl apply -f namespaces.yml
else
    log "INFO" "installing k3s..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.20.9+k3s1 sh -
    log "INFO" "waiting for k3s to start..."
    sleep 30
    waitUntilK3sIsReady $TIMER
    rm -rf ~/.kube && mkdir ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config && sudo chown $USER: ~/.kube/k3s-config && export KUBECONFIG=~/.kube/k3s-config
    kubectl apply -f namespaces.yml
    log "INFO" "done"
fi

# deploy selected tools
if [[ "$rabbitmq" = true ]]; then
    log "INFO" "deploying rabbitMQ..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
    helm install rabbitmq bitnami/rabbitmq --namespace $DEV_NS \
        --version 10.1.14 \
        --set replicaCount=1 \
        --set auth.username=user,auth.password=password \
        --set service.type=NodePort,service.nodePorts.amqp=30672,service.nodePorts.manager=31672
    log "INFO" "done"
fi
if [ "$nats" = true ]; then
    log "INFO" "deploying nats..."
    helm repo add nats https://nats-io.github.io/k8s/helm/charts/
    helm repo update
    helm install nats nats/nats --namespace $DEV_NS --set stan.replicas=1
    log "INFO" "done"
fi
if [ "$kafka" = true ]; then
    log "INFO" "deploying kafka..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
    helm install kafka bitnami/kafka --namespace $DEV_NS
    log "INFO" "done"
fi
if [ "$elasticsearch" = true ]; then
    log "INFO" "deploying elasticsearch..."
    helm repo add elastic https://Helm.elastic.co
    helm repo update
    helm install elasticsearch elastic/elasticsearch --namespace $DEV_NS \
        --version 7.17.1 \
        --set replicas=1 \
        --set service.type=NodePort,service.nodePort=32200
    log "INFO" "done"
fi
if [ "$openfaas" = true ]; then
    log "INFO" "deploying openfaas..."
    command -v faas >/dev/null 2>&1 || {
        log "WARN" "faas cli not found, installing..."
        curl -SLsf https://cli.openfaas.com | sudo sh
    }
    export TIMEOUT=2m
    helm repo add openfaas https://openfaas.github.io/faas-netes/
    helm repo update
    helm install openfaas openfaas/openfaas \
        --namespace openfaas \
        --set functionNamespace=$DEV_NS \
        --set generateBasicAuth=true \
        --set gateway.upstreamTimeout=$TIMEOUT \
        --set gateway.writeTimeout=$TIMEOUT \
        --set gateway.readTimeout=$TIMEOUT \
        --set faasnetes.writeTimeout=$TIMEOUT \
        --set faasnetes.readTimeout=$TIMEOUT \
        --set queueWorker.ackWait=$TIMEOUT
    log "INFO" "done"
fi
for logst in "${logstash[@]}"; do
    if [ "$logst" != "none" ]; then
        log "INFO" "deploying logstash using ${logst}.yml file..."
        helm install logstash-"${logst}" elastic/logstash --namespace $DEV_NS \
            --version 7.17.1 \
            --set replicas=1 \
            -f connectors/"${logst}".yml
        log "INFO" "done"
    fi
done

# wait for deployment
if [[ "$rabbitmq" = true ]]; then
    blockUntilPodIsReady "app.kubernetes.io/name=rabbitmq" $TIMER
    log "INFO" "done"
fi
if [ "$nats" = true ]; then
    ## TBD
    log "INFO" "done"
fi
if [ "$kafka" = true ]; then
    ## TBD
    log "INFO" "done"
fi
if [ "$elasticsearch" = true ]; then
    blockUntilPodIsReady "app=elasticsearch-master" $TIMER
    log "INFO" "done"
fi
if [ "$openfaas" = true ]; then
    blockUntilPodIsReady "app=gateway" $TIMER
    kubectl rollout status -n openfaas deploy/gateway
    kubectl port-forward -n openfaas svc/gateway --address 0.0.0.0 8080:8080 &
    log "INFO" "please wait..."
    sleep 5
    PASSWORD=$(kubectl get secret -n openfaas basic-auth -o jsonpath="{.data.basic-auth-password}" | base64 --decode)
    echo -n $PASSWORD | faas-cli login --username admin --password-stdin
    log "DONE" "openfaas deployed successfully"
    log "INFO" "testing openfaas..."
    faas deploy --image fcarp10/hello-world --name hello-world
    MAX_ATTEMPTS=10
    for ((i = 0; i < $MAX_ATTEMPTS; i++)); do
        if [[ $(curl -o /dev/null -s -w "%{http_code}\n" http://127.0.0.1:8080/function/hello-world) -eq 200 ]]; then
            log "DONE" "function is running successfully"
            faas remove hello-world
            break
        else
            log "WARN" "function is not running yet"
            if [[ $i -eq 10 ]]; then
                log "ERROR" "problem ocurred while deploying the function, exiting..."
                break
            fi
        fi
    done
    log "INFO" "done"
fi
for logst in "${logstash[@]}"; do
    if [ "$logst" != "none" ]; then
        blockUntilPodIsReady "app=logstash-${logst}-logstash" $TIMER
        log "INFO" "done"
    fi
done

# keep connections alive
log "INFO" "keeping connections alive..."
while true; do
    if [ "$openfaas" = true ]; then nc -vz 127.0.0.1 8080; fi
    sleep 60
done

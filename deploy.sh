#!/bin/bash

source utils.sh

###############################################################################
# Author	:	Francisco Carpio
# Github	:	https://github.com/fcarp10
###############################################################################
#   DO NOT JUST RUN THIS. EXAMINE AND JUDGE. RUN AT YOUR OWN RISK.
###############################################################################

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
'

# default values
communication="nats"
database=true
processing=true
dashboard=false
rabbitMQ_elasticsearch_connector=false

while getopts ":c:d:p:g:x:" opt; do
    case $opt in
        c) communication="$OPTARG"
        ;;
        d) database="$OPTARG"
        ;;
        p) processing="$OPTARG"
        ;;
        g) dashboard="$OPTARG"
        ;;
        x) rabbitMQ_elasticsearch_connector="$OPTARG"
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
command -v faas >/dev/null 2>&1 || {
    log "WARN" "faas cli not found, installing..."
    curl -SLsf https://cli.openfaas.com | sudo sh
}
command -v helm >/dev/null 2>&1 || {
    log "WARN" "helm not found, installing..."
    curl -sSLf https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
}
log "DONE" "tools already installed"




####### k3s #######
log "INFO" "installing k3s..."
curl -sfL https://get.k3s.io | sh -
mkdir ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config && sudo chown $USER: ~/.kube/k3s-config && export KUBECONFIG=~/.kube/k3s-config
log "INFO" "waiting for k3s to start..."
sleep 30
log "INFO" "done"

# create namespaces
export DEV_NS=dev
kubectl apply -f namespaces.yml # create namespaces




####### nats|kafka|rabbitmq #######
if [ "$communication" = "nats" ]; then
    log "INFO" "deploying nats..."
    helm repo add nats https://nats-io.github.io/k8s/helm/charts/
    helm install nats nats/nats --namespace $DEV_NS --set stan.replicas=1
    log "INFO" "done"

elif [ "$communication" = "kafka" ]; then
    log "INFO" "deploying kafka..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm install kafka bitnami/kafka --namespace $DEV_NS
    log "INFO" "done"

elif [[ "$communication" = "rabbitmq" ]]; then
    log "INFO" "deploying rabbitMQ..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm install rabbitmq bitnami/rabbitmq --namespace $DEV_NS --set replicas=1
fi



####### elasticsearch #######
if [ "$database" = true ]; then
    log "INFO" "deploying elasticsearch..."
    helm repo add elastic https://Helm.elastic.co
    helm install elasticsearch elastic/elasticsearch --namespace $DEV_NS --set replicas=1

    blockUntilPodIsReady "app=elasticsearch-master" 120 "elasticsearch-master"  # Block until is running & ready
    ES_POD=$(kubectl get pods -n $DEV_NS -l "app=elasticsearch-master" -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward -n $DEV_NS $ES_POD 9200 &
    log "INFO" "done"
fi



####### connectors #######
if [ "$rabbitMQ_elasticsearch_connector" = true ]; then
    log "INFO" "deploying logstash for rabbitMQ --> elasticsearch ..."
    PIPELINE='{input { rabbitmq { host => "rabbitmq" durable => true } } }'
    helm install logstash elastic/logstash --namespace $DEV_NS -f logstash_conf.yml --set replicas=1
    blockUntilPodIsReady "app=logstash" 120 "logstash"  # Block until is running & ready
    log "INFO" "done"
fi



####### kibana #######
if [ "$dashboard" = true ]; then
    log "INFO" "deploying kibana..."
    helm repo add elastic https://Helm.elastic.co
    helm install kibana elastic/kibana --namespace $DEV_NS --set replicas=1

    blockUntilPodIsReady "app=kibana" 120 "kibana"  # Block until is running & ready
    KIBANA_POD=$(kubectl get pods -n $DEV_NS -l "app=kibana" -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward -n $DEV_NS $KIBANA_POD 5601:5601 &
    log "INFO" "done"
fi


####### openfaas #######
if [ "$processing" = true ]; then
    log "INFO" "deploying openfaas..."
    export TIMEOUT=2m
    helm repo add openfaas https://openfaas.github.io/faas-netes/
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

    blockUntilPodIsReady "app=openfaas" 120 "openfaas"  # Block until is running & ready
    kubectl rollout status -n openfaas deploy/gateway
    kubectl port-forward -n openfaas svc/gateway 8080:8080 &

    log "INFO" "please wait..."
    sleep 10
    PASSWORD=$(
        sudo kubectl get secret -n openfaas basic-auth -o jsonpath="{.data.basic-auth-password}" | base64 --decode
        echo
    )
    echo -n $PASSWORD | faas-cli login --username admin --password-stdin
    log "DONE" "openfaas deployed successfully"

    log "INFO" "testing openfaas..."
    faas store deploy NodeInfo
    MAX_ATTEMPTS=10
    for ((i = 0; i < $MAX_ATTEMPTS; i++)); do
        if [[ $(curl -o /dev/null -s -w "%{http_code}\n" http://127.0.0.1:8080/function/nodeinfo) -eq 200 ]]; then
            log "DONE" "function is running successfully"
            faas rm nodeinfo
            break
        else
            log "WARN" "function is not running yet"
            if [[ $i -eq 10 ]]; then
                log "ERROR" "problem ocurred while deploying the function, exiting..."
                break
            fi
        fi
    done
fi
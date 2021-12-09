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
\n -c {"nats"|"kafka"|"rabbitmq"}
\t communication tool to deploy.
\n -d {"elasticsearch"|"influxdb"}
\t database engine to deploy.
\n -p {"openfaas"}
\t serverless platform to deploy.
\n -g {"kibana"}
\t GUI/dashboard to deploy.
\n -x NAME_OF_YML_FILE (e.g. "rbtoes")
\t connectors to deploy.
'

# default values
communication="none"
database="none"
processing="none"
dashboard="none"
connectors="none"

while getopts ":c:d:p:g:x:" opt; do
    case $opt in
    c)
        communication="$OPTARG"
        ;;
    d)
        database="$OPTARG"
        ;;
    p)
        processing="$OPTARG"
        ;;
    g)
        dashboard="$OPTARG"
        ;;
    x)
        connectors+=("$OPTARG")
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

####### k3s #######
log "INFO" "installing k3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.20.9+k3s1 sh -
log "INFO" "waiting for k3s to start..."
waitUntilK3sIsReady $TIMER
mkdir ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config && sudo chown $USER: ~/.kube/k3s-config && export KUBECONFIG=~/.kube/k3s-config
log "INFO" "done"

# create namespaces
export DEV_NS=dev
kubectl apply -f namespaces.yml # create namespaces

####### communication #######
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
    helm repo add groundhog2k https://groundhog2k.github.io/helm-charts/
    helm install rabbitmq groundhog2k/rabbitmq --version 0.2.19 --namespace $DEV_NS --set replicaCount=1 --set authentication.user=user --set authentication.password=password
    log "INFO" "done"
fi

####### database #######
if [ "$database" = "elasticsearch" ]; then
    log "INFO" "deploying elasticsearch..."
    helm repo add elastic https://Helm.elastic.co
    helm install elasticsearch elastic/elasticsearch --namespace $DEV_NS --set replicas=1
    log "INFO" "done"

elif [ "$database" = "influxdb" ]; then
    log "INFO" "deploying influxdb..."
    helm repo add influxdata https://helm.influxdata.com/
    helm install influxdb influxdata/influxdb2 --namespace $DEV_NS \
        --set adminUser.password=pass123456 \
        --set adminUser.token=token123456
    log "INFO" "done"
fi

####### processing #######
if [ "$processing" = "openfaas" ]; then
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
    log "INFO" "done"
fi

####### dashboard #######
if [ "$dashboard" = "kibana" ]; then
    log "INFO" "deploying kibana..."
    helm repo add elastic https://Helm.elastic.co
    helm install kibana elastic/kibana --namespace $DEV_NS --set replicas=1
    log "INFO" "done"
fi

####### connectors #######
for conn in "${connectors[@]}"; do
    if [ "$conn" != "none" ]; then
        log "INFO" "deploying logstash using ${conn}.yml file..."
        helm install logstash-"${conn}" elastic/logstash --namespace $DEV_NS -f connectors/"${conn}".yml --set replicas=1
        log "INFO" "done"
    fi
done

################################
##### wait for deployment ######
################################

####### communication #######
if [ "$communication" = "nats" ]; then
    ## TBD
    log "INFO" "done"

elif [ "$communication" = "kafka" ]; then
    ## TBD
    log "INFO" "done"

elif [ "$communication" = "rabbitmq" ]; then
    blockUntilPodIsReady "app.kubernetes.io/name=rabbitmq" $TIMER
    kubectl port-forward -n $DEV_NS svc/rabbitmq --address 0.0.0.0 5672 &
    kubectl port-forward -n $DEV_NS svc/rabbitmq --address 0.0.0.0 15672:15672 &
    log "INFO" "done"
fi

####### database #######
if [ "$database" = "elasticsearch" ]; then
    blockUntilPodIsReady "app=elasticsearch-master" $TIMER
    ES_POD=$(kubectl get pods -n $DEV_NS -l "app=elasticsearch-master" -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward -n $DEV_NS $ES_POD --address 0.0.0.0 9200 &
    log "INFO" "done"

elif [ "$database" = "influxdb" ]; then
    blockUntilPodIsReady "app.kubernetes.io/name=influxdb2" $TIMER
    # PASSWORD=$(kubectl get secret -n $DEV_NS influxdb-influxdb2-auth -o jsonpath="{.data['admin-password']}" | base64 --decode)
    INF_POD=$(kubectl get pods -n $DEV_NS -l "app.kubernetes.io/name=influxdb2" -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward -n $DEV_NS $INF_POD --address 0.0.0.0 8086:8086 &
    log "INFO" "done"
fi

####### processing #######
if [ "$processing" = "openfaas" ]; then

    command -v faas >/dev/null 2>&1 || {
        log "WARN" "faas cli not found, installing..."
        curl -SLsf https://cli.openfaas.com | sudo sh
    }

    blockUntilPodIsReady "app=gateway" $TIMER
    kubectl rollout status -n openfaas deploy/gateway
    kubectl port-forward -n openfaas svc/gateway --address 0.0.0.0 8080:8080 &

    log "INFO" "please wait..."
    sleep 5
    PASSWORD=$(kubectl get secret -n openfaas basic-auth -o jsonpath="{.data.basic-auth-password}" | base64 --decode)
    echo -n $PASSWORD | faas-cli login --username admin --password-stdin
    log "DONE" "openfaas deployed successfully"

    log "INFO" "testing openfaas..."
    faas deploy --image fcarp10/payload-echo-rbes --name payload-echo-rbes
    MAX_ATTEMPTS=10
    for ((i = 0; i < $MAX_ATTEMPTS; i++)); do
        if [[ $(curl -o /dev/null -s -w "%{http_code}\n" -d '{"test":"test"}' http://127.0.0.1:8080/function/payload-echo-rbes) -eq 200 ]]; then
            log "DONE" "function is running successfully"
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

####### dashboard #######
if [ "$dashboard" = "kibana" ]; then
    blockUntilPodIsReady "app=kibana" $TIMER
    KIBANA_POD=$(kubectl get pods -n $DEV_NS -l "app=kibana" -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward -n $DEV_NS $KIBANA_POD --address 0.0.0.0 5601:5601 &
    log "INFO" "done"
fi

####### connectors #######
for conn in "${connectors[@]}"; do
    if [ "$conn" != "none" ]; then
        blockUntilPodIsReady "app=logstash-${conn}-logstash" $TIMER
        log "INFO" "done"
    fi
done

log "INFO" "keeping connections alive..."
while true ; do 
    if [ "$communication" = "rabbitmq" ]; then nc -vz 127.0.0.1 5672; nc -vz 127.0.0.1 15672; fi
    if [ "$database" = "elasticsearch" ]; then nc -vz 127.0.0.1 9200; fi
    if [ "$processing" = "openfaas" ]; then nc -vz 127.0.0.1 8080; fi
    if [ "$dashboard" = "kibana" ]; then nc -vz 127.0.0.1 5601; fi
    sleep 60
done
#!/bin/bash

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
\n -k --kafka
\t deploys kafka instead of nats.
\n -h --help
\t Shows available options.
\n\t Only one option is allowed.
'

withkafka=false

while [ "$1" != "" ]; do
    case $1 in
    --kafka | -k)
        withkafka=true
        ;;
    --help | -h)
        echo -e "${usage}"
        exit 1
        ;;
    *)
        echo -e "Invalid option $1 \n\n${usage}"
        exit 0
        ;;
    esac
    shift
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

####### openfaas #######
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

log "INFO" "waiting for openfaas to start..."
sleep 30

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

####### elasticsearch #######
log "INFO" "deploying elasticsearch..."
helm repo add elastic https://Helm.elastic.co
helm install elasticsearch elastic/elasticsearch --set replicas=1 --namespace $DEV_NS
log "INFO" "done"

####### kafka/nats #######
if [ "$withkafka" = true ]; then
    log "INFO" "deploying kafka..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm install kafka bitnami/kafka --namespace $DEV_NS
    log "INFO" "done"
else
    log "INFO" "deploying nats..."
    helm repo add nats https://nats-io.github.io/k8s/helm/charts/
    helm install nats nats/nats --set stan.replicas=1 --namespace $DEV_NS
    log "INFO" "done"
fi

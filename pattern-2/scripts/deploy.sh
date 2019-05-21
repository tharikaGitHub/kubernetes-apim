#!/bin/bash
# ------------------------------------------------------------------------
# Copyright 2017 WSO2, Inc. (http://wso2.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License
# ------------------------------------------------------------------------

set -e

ECHO=`which echo`
KUBECTL=`which kubectl`

# methods
function echoBold () {
    ${ECHO} -e $'\e[1m'"${1}"$'\e[0m'
}

read -p "Do you have a WSO2 Subscription?(N/y)" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
 read -p "Enter Your WSO2 Username: " WSO2_SUBSCRIPTION_USERNAME
 echo
 read -s -p "Enter Your WSO2 Password: " WSO2_SUBSCRIPTION_PASSWORD
 echo
 HAS_SUBSCRIPTION=0
 if ! grep -q "imagePullSecrets" ../apim-analytics/wso2apim-analytics-deployment.yaml; then
     if ! sed -i.bak -e 's|wso2/|docker.wso2.com/|' \
     ../apim-analytics/wso2apim-analytics-deployment.yaml \
     ../apim-gw/wso2apim-gateway-deployment.yaml \
     ../apim-is-as-km/wso2apim-is-as-km-deployment.yaml \
     ../apim-km/wso2apim-km-deployment.yaml \
     ../apim-pubstore-tm/wso2apim-pubstore-tm-1-deployment.yaml \
     ../apim-pubstore-tm/wso2apim-pubstore-tm-2-deployment.yaml; then
     echo "couldn't configure the docker.wso2.com"
     exit 1
     fi
     if ! sed -i.bak -e '/serviceAccount/a \
    \      imagePullSecrets:' \
     ../apim-analytics/wso2apim-analytics-deployment.yaml \
     ../apim-gw/wso2apim-gateway-deployment.yaml \
     ../apim-is-as-km/wso2apim-is-as-km-deployment.yaml \
     ../apim-km/wso2apim-km-deployment.yaml \
     ../apim-pubstore-tm/wso2apim-pubstore-tm-1-deployment.yaml \
     ../apim-pubstore-tm/wso2apim-pubstore-tm-2-deployment.yaml; then
     echo "couldn't configure the \"imagePullSecrets:\""
     exit 1
     fi
      if ! sed -i.bak -e '/imagePullSecrets/a \
    \      - name: wso2creds' \
     ../apim-analytics/wso2apim-analytics-deployment.yaml \
     ../apim-gw/wso2apim-gateway-deployment.yaml \
     ../apim-is-as-km/wso2apim-is-as-km-deployment.yaml \
     ../apim-km/wso2apim-km-deployment.yaml \
     ../apim-pubstore-tm/wso2apim-pubstore-tm-1-deployment.yaml \
     ../apim-pubstore-tm/wso2apim-pubstore-tm-2-deployment.yaml; then
     echo "couldn't configure the \"- name: wso2creds\""
     exit 1
     fi
 fi
elif [[ $REPLY =~ ^[Nn]$ || -z "$REPLY" ]]
then
 HAS_SUBSCRIPTION=1
 if ! sed -i.bak -e '/imagePullSecrets:/d' -e '/- name: wso2creds/d' \
     ../apim-analytics/wso2apim-analytics-deployment.yaml \
     ../apim-gw/wso2apim-gateway-deployment.yaml \
     ../apim-is-as-km/wso2apim-is-as-km-deployment.yaml \
     ../apim-km/wso2apim-km-deployment.yaml \
     ../apim-pubstore-tm/wso2apim-pubstore-tm-1-deployment.yaml \
     ../apim-pubstore-tm/wso2apim-pubstore-tm-2-deployment.yaml; then
     echo "couldn't configure the \"- name: wso2creds\""
     exit 1
 fi
 if ! sed -i.bak -e 's|docker.wso2.com|wso2|' \
     ../apim-analytics/wso2apim-analytics-deployment.yaml \
     ../apim-gw/wso2apim-gateway-deployment.yaml \
     ../apim-is-as-km/wso2apim-is-as-km-deployment.yaml \
     ../apim-km/wso2apim-km-deployment.yaml \
     ../apim-pubstore-tm/wso2apim-pubstore-tm-1-deployment.yaml \
     ../apim-pubstore-tm/wso2apim-pubstore-tm-2-deployment.yaml; then
  echo "couldn't configure the docker.wso2.com"
  exit 1
 fi
else
 echo "Invalid option"
 exit 1
fi

# remove backup files
test -f ../apim/*.bak && rm ../apim/*.bak
test -f ../apim-analytics/*.bak && rm ../apim-analytics/*.bak
test -f ../apim-gw/*.bak && rm ../apim-gw/*.bak
test -f ../apim-is-as-km/*.bak && rm ../apim-is-as-km/*.bak
test -f ../apim-km/*.bak && rm ../apim-km/*.bak
test -f ../apim-pubstore-tm/apim-pubstore-tm/wso2apim-pubstore-tm-1-deployment.yaml.bak && rm ../apim-pubstore-tm/*.bak


# create a new Kubernetes Namespace
${KUBECTL} create namespace wso2

# create a new service account in 'wso2' Kubernetes Namespace
${KUBECTL} create serviceaccount wso2svc-account -n wso2

# switch the context to new 'wso2' namespace
${KUBECTL} config set-context $(${KUBECTL} config current-context) --namespace=wso2

# create a Kubernetes Secret for passing WSO2 Private Docker Registry credentials
${KUBECTL} create secret docker-registry wso2creds --docker-server=docker.wso2.com --docker-username=${WSO2_SUBSCRIPTION_USERNAME} --docker-password=${WSO2_SUBSCRIPTION_PASSWORD} --docker-email=${WSO2_SUBSCRIPTION_USERNAME}

# create Kubernetes Role and Role Binding necessary for the Kubernetes API requests made from Kubernetes membership scheme
${KUBECTL} create --username=admin --password=${ADMIN_PASSWORD} -f ../../rbac/rbac.yaml

echoBold 'Creating ConfigMaps...'
# create the APIM Gateway ConfigMaps
${KUBECTL} create configmap apim-gateway-conf --from-file=../confs/apim-gateway/
${KUBECTL} create configmap apim-gateway-conf-axis2 --from-file=../confs/apim-gateway/axis2/
${KUBECTL} create configmap apim-gateway-conf-datasources --from-file=../confs/apim-gateway/datasources/
${KUBECTL} create configmap apim-gateway-conf-identity --from-file=../confs/apim-gateway/identity/
# create the APIM Analytics ConfigMaps
${KUBECTL} create configmap apim-analytics-conf-worker --from-file=../confs/apim-analytics/
# create the APIM Publisher-Store-Traffic-Manager ConfigMaps
${KUBECTL} create configmap apim-pubstore-tm-1-conf --from-file=../confs/apim-pubstore-tm-1/
${KUBECTL} create configmap apim-pubstore-tm-1-conf-axis2 --from-file=../confs/apim-pubstore-tm-1/axis2/
${KUBECTL} create configmap apim-pubstore-tm-1-conf-datasources --from-file=../confs/apim-pubstore-tm-1/datasources/
${KUBECTL} create configmap apim-pubstore-tm-1-conf-identity --from-file=../confs/apim-pubstore-tm-1/identity/
${KUBECTL} create configmap apim-pubstore-tm-2-conf --from-file=../confs/apim-pubstore-tm-2/
${KUBECTL} create configmap apim-pubstore-tm-2-conf-axis2 --from-file=../confs/apim-pubstore-tm-2/axis2/
${KUBECTL} create configmap apim-pubstore-tm-2-conf-datasources --from-file=../confs/apim-pubstore-tm-2/datasources/
${KUBECTL} create configmap apim-pubstore-tm-2-conf-identity --from-file=../confs/apim-pubstore-tm-2/identity/
# create the APIM KeyManager ConfigMaps
${KUBECTL} create configmap apim-km-conf --from-file=../confs/apim-km/
${KUBECTL} create configmap apim-km-conf-axis2 --from-file=../confs/apim-km/axis2/
${KUBECTL} create configmap apim-km-conf-datasources --from-file=../confs/apim-km/datasources/
${KUBECTL} create configmap apim-km-conf-identity --from-file=../confs/apim-km/identity/
# create the APIM IS as Key Manager ConfigMaps
${KUBECTL} create configmap apim-is-as-km-conf --from-file=../confs/apim-is-as-km/
${KUBECTL} create configmap apim-is-as-km-conf-axis2 --from-file=../confs/apim-is-as-km/axis2/
${KUBECTL} create configmap apim-is-as-km-conf-datasources --from-file=../confs/apim-is-as-km/datasources/

${KUBECTL} create configmap mysql-dbscripts --from-file=../extras/confs/rdbms/mysql/dbscripts/

# deploy the Kubernetes services
${KUBECTL} create -f ../apim-pubstore-tm/wso2apim-pubstore-tm-1-service.yaml
${KUBECTL} create -f ../apim-pubstore-tm/wso2apim-pubstore-tm-2-service.yaml
${KUBECTL} create -f ../apim-pubstore-tm/wso2apim-service.yaml
#${KUBECTL} create -f ../apim-km/wso2apim-km-service.yaml
${KUBECTL} create -f ../apim-is-as-km/wso2apim-is-as-km-service.yaml
${KUBECTL} create -f ../apim-gw/wso2apim-gateway-service.yaml
${KUBECTL} create -f ../apim-analytics/wso2apim-analytics-service.yaml

echoBold 'Deploying persistent storage resources...'
${KUBECTL} create -f ../volumes/persistent-volumes.yaml
${KUBECTL} create -f ../extras/rdbms/volumes/persistent-volumes.yaml

# MySQL
echoBold 'Deploying WSO2 API Manager Databases...'
${KUBECTL} create -f ../extras/rdbms/mysql/mysql-persistent-volume-claim.yaml
${KUBECTL} create -f ../extras/rdbms/mysql/mysql-deployment.yaml
${KUBECTL} create -f ../extras/rdbms/mysql/mysql-service.yaml
sleep 30s

echoBold 'Deploying WSO2 API Manager Analytics...'
${KUBECTL} create -f ../apim-analytics/wso2apim-analytics-deployment.yaml
sleep 3m

echoBold 'Deploying WSO2 API Manager Key Manager...'
#${KUBECTL} create -f ../apim-km/wso2apim-km-deployment.yaml
${KUBECTL} create -f ../apim-is-as-km/wso2apim-is-as-km-volume-claim.yaml
${KUBECTL} create -f ../apim-is-as-km/wso2apim-is-as-km-deployment.yaml
sleep 2m

echoBold 'Deploying WSO2 API Manager Publisher-Store-Traffic-Manager...'
${KUBECTL} create -f ../apim-pubstore-tm/wso2apim-pubstore-tm-1-deployment.yaml
sleep 1m
${KUBECTL} create -f ../apim-pubstore-tm/wso2apim-pubstore-tm-2-deployment.yaml
sleep 3m

echoBold 'Deploying WSO2 API Manager Gateway...'
${KUBECTL} create -f ../apim-gw/wso2apim-gateway-volume-claim.yaml
${KUBECTL} create -f ../apim-gw/wso2apim-gateway-deployment.yaml
sleep 2m

echoBold 'Deploying Ingresses...'
${KUBECTL} create -f ../ingresses/wso2apim-gateway-ingress.yaml
${KUBECTL} create -f ../ingresses/wso2apim-ingress.yaml

echoBold 'Finished'
echo 'To access the WSO2 API Manager Management console, try https://wso2apim/carbon in your browser.'
echo 'To access the WSO2 API Manager Publisher, try https://wso2apim/publisher in your browser.'
echo 'To access the WSO2 API Manager Store, try https://wso2apim/store in your browser.'

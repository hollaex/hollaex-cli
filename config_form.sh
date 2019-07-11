#!/bin/bash 
SCRIPTPATH=$HOME/.hollaex-cli

function local_database_init() {

    if [ $HOLLAEX_CODEBASE_PATH ]; then

      CONTAINER_PREFIX="-api"

    fi

    echo "*** Running sequelize db:migrate ***"
    docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 sequelize db:migrate

    echo "*** Running database triggers ***"
    docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/runTriggers.js

    echo "*** Running sequelize db:seed:all ***"
    docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 sequelize db:seed:all

    echo "*** Running InfluxDB migrations ***"
    docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/createInflux.js
    docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/migrateInflux.js
    docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/initializeInflux.js

    exit 0;
}

function local_code_test() {

    echo "*** Running mocha code test ***"
    docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server-api_1 mocha --exit

    exit 0;
}

function check_kubernetes_dependencies() {

    # Checking kubectl and helm are installed on this machine.
    if command kubectl version > /dev/null 2>&1 && command helm version > /dev/null 2>&1; then

         echo "*** kubectl and helm detected ***"

    else

         echo "*** hollaex-cli failed to detect kubectl or helm installed on this machine. Please install it before running hollaex-cli. ***"
         exit 1;

    fi

}

 
function load_config_variables() {

  HOLLAEX_CONFIGMAP_VARIABLES=$(set -o posix ; set | grep "KUBERNETES_CONFIGMAP" | cut -c22-)
  HOLLAEX_SECRET_VARIABLES=$(set -o posix ; set | grep "KUBERNETES_SECRET" | cut -c19-)

  HOLLAEX_CONFIGMAP_VARIABLES_YAML=$(for value in ${HOLLAEX_CONFIGMAP_VARIABLES} 
  do 
      if [[ $value == *"'"* ]]; then
        printf "  ${value//=/: }\n";
      else
        printf "  ${value//=/: \'}'\n";
      fi

  done)

  HOLLAEX_SECRET_VARIABLES_BASE64=$(for value in ${HOLLAEX_SECRET_VARIABLES} 
  do

      printf "${value//$(cut -d "=" -f 2 <<< "$value")/$(cut -d "=" -f 2 <<< "$value" | tr -d '\n' | base64)} ";
  
  done)

  HOLLAEX_SECRET_VARIABLES_YAML=$(for value in ${HOLLAEX_SECRET_VARIABLES_BASE64} 
  do

      printf "  ${value/=/: }\n";

  done)

}

function generate_local_env() {

# Generate local env
cat > $SCRIPTPATH/local/${ENVIRONMENT_EXCHANGE_NAME}.env.local <<EOL
DB_DIALECT=postgres

$(echo "$HOLLAEX_CONFIGMAP_VARIABLES" | tr -d '\'\')

$(echo "$HOLLAEX_SECRET_VARIABLES")
EOL

}

function generate_nginx_conf() {
  
if [ "$LOCAL_DEPLOYMENT_MODE" == "all" ]; then 

  # Generate local nginx conf
  cat > $SCRIPTPATH/local/nginx/conf.d/upstream.conf <<EOL

  upstream api {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server:10010;
  }

  upstream socket {
    ip_hash;
    server ${ENVIRONMENT_EXCHANGE_NAME}-server:10080;
  }

EOL

fi


#IFS=',' read -ra LOCAL_DEPLOYMENT_MODE <<< "$1"

if [ "$LOCAL_DEPLOYMENT_MODE" == "api" ] && [ ! "$LOCAL_DEPLOYMENT_MODE" == "ws" ]; then

  # Generate local nginx conf
  cat > $SCRIPTPATH/local/nginx/conf.d/upstream.conf <<EOL

  upstream api {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-api:10010;
  }

  upstream socket {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-api:10080;
  }

EOL

elif [ ! "$LOCAL_DEPLOYMENT_MODE" == "api" ] && [ "$LOCAL_DEPLOYMENT_MODE" == "ws" ]; then

  # Generate local nginx conf
  cat > $SCRIPTPATH/local/nginx/conf.d/upstream.conf <<EOL

  upstream api {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-ws:10010;
  }
  
  upstream socket {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-ws:10080;
  }

EOL

fi

if [ "$LOCAL_DEPLOYMENT_MODE" == "api" ] && [ "$LOCAL_DEPLOYMENT_MODE" == "ws" ]; then

# Generate local nginx conf
cat > $SCRIPTPATH/local/nginx/conf.d/upstream.conf <<EOL

  upstream api {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-api:10010;
  }

  upstream socket {
    ip_hash;
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-ws:10080;
  }

EOL

fi

}


function generate_local_docker_compose() {

# Generate docker-compose
cat > $SCRIPTPATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
version: '3'
services:
EOL

if [ ! "$LOCAL_WITHOUT_BACKENDS" ]; then 
# Generate docker-compose
cat >> $SCRIPTPATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-nginx:
    image: nginx:1.13-alpine
    volumes:
      - ./nginx:/etc/nginx
      - ./logs/nginx:/var/log
      - ./nginx/static/:/usr/share/nginx/html
    ports:
      - 80:80
    environment:
      - NGINX_PORT=80
    #depends_on:
    #  - ${ENVIRONMENT_EXCHANGE_NAME}-server
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
  ${ENVIRONMENT_EXCHANGE_NAME}-redis:
    image: redis:5.0.4
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    ports:
      - 6379:6379
  ${ENVIRONMENT_EXCHANGE_NAME}-db:
    image: postgres:10.6
    ports:
      - 5432:5432
    environment:
      - POSTGRES_DB=$KUBERNETES_SECRET_DB_NAME
      - POSTGRES_USER=$KUBERNETES_SECRET_DB_USERNAME
      - POSTGRES_PASSWORD=$KUBERNETES_SECRET_DB_PASSWORD
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
  ${ENVIRONMENT_EXCHANGE_NAME}-influxdb:
    image: influxdb:1.7-alpine
    ports:
      - 8086:8086
    environment:
      - INFLUX_DB=$KUBERNETES_SECRET_INFLUX_DB
      - INFLUX_HOST=${ENVIRONMENT_EXCHANGE_NAME}-influxdb
      - INFLUX_PORT=8086
      - INFLUX_USER=$KUBERNETES_SECRET_INFLUX_USER
      - INFLUX_PASSWORD=$KUBERNETES_SECRET_INFLUX_PASSWORD
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network

EOL

fi 

if [ "$1" == "all" ]; then

  # Generate docker-compose
  cat >> $SCRIPTPATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL


  ${ENVIRONMENT_EXCHANGE_NAME}-server:
    image: $ENVIRONMENT_DOCKER_IMAGE_REGISTRY:$ENVIRONMENT_DOCKER_IMAGE_VERSION
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    entrypoint:
      - pm2-runtime
      - start
      - ecosystem.config.js
      - --env
      - development
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
      - ${ENVIRONMENT_EXCHANGE_NAME}-influxdb
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network

EOL

else

LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE=$1

IFS=',' read -ra LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE <<< "$LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE"

  for i in ${LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE[@]}; do

  # Generate docker-compose
  cat >> $SCRIPTPATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL


  ${ENVIRONMENT_EXCHANGE_NAME}-server-${i}:
    image: $ENVIRONMENT_DOCKER_IMAGE_REGISTRY:$ENVIRONMENT_DOCKER_IMAGE_VERSION
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    entrypoint:
      - pm2-runtime
      - start
      - ecosystem.config.js
      - --env
      - development
      - --only
      - ${i}
EOL

  if [ "$i" == "api" ]; then
  cat >> $SCRIPTPATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
    ports:
      - 10010:10010
EOL

  elif [ "$i" == "ws" ]; then

  cat >> $SCRIPTPATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
    ports:
      - 10080:10080
EOL

  fi
  cat >> $SCRIPTPATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL

done

fi

# Generate docker-compose
cat >> $SCRIPTPATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

networks:
  ${ENVIRONMENT_EXCHANGE_NAME}-network:
  
EOL

}

function generate_kubernetes_configmap() {

# Generate Kubernetes Configmap
cat > $SCRIPTPATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-configmap.yaml <<EOL
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-env
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
data:
  DB_DIALECT: postgres
${HOLLAEX_CONFIGMAP_VARIABLES_YAML}
EOL

}

function generate_kubernetes_secret() {

# Generate Kubernetes Secret
cat > $SCRIPTPATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-secret.yaml <<EOL
apiVersion: v1
kind: Secret
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-secret
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
type: Opaque
data:
${HOLLAEX_SECRET_VARIABLES_YAML}
EOL
}

function generate_kubernetes_ingress() {

# Generate Kubernetes Secret
cat > $SCRIPTPATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-ingress.yaml <<EOL
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    certmanager.k8s.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      limit_req zone=api burst=10 nodelay;
      limit_req_log_level notice;
      limit_req_status 429;
spec:
  rules:
  - host: ${KUBERNETES_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /v0
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010

  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${KUBERNETES_CONFIGMAP_API_HOST}

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api-order
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    certmanager.k8s.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      limit_req zone=order burst=3 nodelay;
      limit_req_log_level notice;
      limit_req_status 429;
spec:
  rules:
  - host: ${KUBERNETES_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /v0/order
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010
  
  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${KUBERNETES_CONFIGMAP_API_HOST}

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api-admin
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    certmanager.k8s.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
spec:
  rules:
  - host: ${KUBERNETES_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /v0/admin
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010

  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${KUBERNETES_CONFIGMAP_API_HOST}

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-ws
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    certmanager.k8s.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
    nginx.org/websocket-services: "${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}-server-ws"
spec:
  rules:
  - host: ${KUBERNETES_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /socket.io
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-ws
          servicePort: 10080
  
  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${KUBERNETES_CONFIGMAP_API_HOST}
EOL

}

function generate_random_values() {

  python -c "import os; print os.urandom(16).encode('hex')"

}

function update_random_values_to_config() {


GENERATE_VALUES_LIST=( "KUBERNETES_SECRET_ADMIN_PASSWORD" "KUBERNETES_SECRET_SUPERVISOR_PASSWORD" "KUBERNETES_SECRET_SUPPORT_PASSWORD" "KUBERNETES_SECRET_KYC_PASSWORD" "KUBERNETES_SECRET_QUICK_TRADE_SECRET" "KUBERNETES_SECRET_API_KEYS" "KUBERNETES_SECRET_SECRET" )


for j in ${CONFIG_FILE_PATH[@]}; do

if command grep -q "KUBERNETES_SECRET" $j > /dev/null ; then

SECRET_CONFIG_FILE_PATH=$j

for k in ${GENERATE_VALUES_LIST[@]}; do

grep -v $k $SECRET_CONFIG_FILE_PATH > temp && mv temp $SECRET_CONFIG_FILE_PATH

cat >> $SECRET_CONFIG_FILE_PATH <<EOL
$k=$(generate_random_values)
EOL

done
        
fi

done

unset GENERATE_VALUES_LIST

}

function generate_nodeselector_values() {

INPUT_VALUE=$1
CONVERTED_VALUE=$(printf "${INPUT_VALUE/:/: }")

# Generate Kubernetes Secret
cat > $SCRIPTPATH/kubernetes/config/nodeSelector-$2.yaml <<EOL
nodeSelector: $(echo $CONVERTED_VALUE)
EOL

}

# `helm_dynamic_trading_paris run` for running paris based on config file definition.
# `helm_dynamic_trading_paris terminate` for terminating installed paris on kubernetes.

function helm_dynamic_trading_paris() {

  IFS=',' read -ra PAIRS <<< "$KUBERNETES_CONFIGMAP_PAIRS"    #Convert string to array

  for i in "${PAIRS[@]}"; do
    TRADE_PARIS_DEPLOYMENT=$(echo $i | cut -f1 -d ",")
    TRADE_PARIS_DEPLOYMENT_NAME=${TRADE_PARIS_DEPLOYMENT//-/}

    if [ "$1" == "run" ]; then

      #Running and Upgrading
      helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-server-queue-$TRADE_PARIS_DEPLOYMENT_NAME --namespace $ENVIRONMENT_EXCHANGE_NAME --recreate-pods --set DEPLOYMENT_MODE="queue $TRADE_PARIS_DEPLOYMENT" --set dockerTag="$ENVIRONMENT_DOCKER_IMAGE_VERSION" --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" --set podRestart_webhook_url="$ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL" -f $SCRIPTPATH/kubernetes/config/nodeSelector-hollaex.yaml -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server

    elif [ "$1" == "terminate" ]; then

      #Terminating
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-server-queue-$TRADE_PARIS_DEPLOYMENT_NAME

    fi

  done

}
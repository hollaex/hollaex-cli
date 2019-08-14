#!/bin/bash 
SCRIPTPATH=$HOME/.hollaex-cli

function local_database_init() {

    if [[ "$RUN_WITH_VERIFY" == true ]]; then

        echo "*** Are you sure you want to run database init jobs for your local $ENVIRONMENT_EXCHANGE_NAME db? (y/n) ***"

        read answer

      if [[ "$answer" = "${answer#[Yy]}" ]]; then
        echo "*** Exiting... ***"
        exit 0;
      fi

    fi
    
    if [[ "$1" == "start" ]]; then

      if [[ ! $LOCAL_DEPLOYMENT_MODE == "all" ]]; then

        CONTAINER_PREFIX="-$LOCAL_DEPLOYMENT_MODE"

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


    elif [[ "$1" == 'upgrade' ]]; then

      if [[ $LOCAL_DEPLOYMENT_MODE ]]; then

        CONTAINER_PREFIX="-$LOCAL_DEPLOYMENT_MODE"

      fi

      echo "*** Running sequelize db:migrate ***"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 sequelize db:migrate

      echo "*** Running database triggers ***"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/runTriggers.js

      echo "*** Running InfluxDB initialization ***"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/initializeInflux.js
    
    fi
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

  HOLLAEX_CONFIGMAP_VARIABLES=$(set -o posix ; set | grep "HOLLAEX_CONFIGMAP" | cut -c19-)
  HOLLAEX_SECRET_VARIABLES=$(set -o posix ; set | grep "HOLLAEX_SECRET" | cut -c16-)

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
      printf "${value//$(cut -d "=" -f 2 <<< "$value")/$(cut -d "=" -f 2 <<< "$value" | tr -d '\n' | tr -d "'" | base64)} ";
  
  done)

  HOLLAEX_SECRET_VARIABLES_YAML=$(for value in ${HOLLAEX_SECRET_VARIABLES_BASE64} 
  do

      printf "  ${value/=/: }\n";

  done)

}

function generate_local_env() {

# Generate local env
cat > $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}.env.local <<EOL
DB_DIALECT=postgres

$(echo "$HOLLAEX_CONFIGMAP_VARIABLES" | tr -d '\'\')

$(echo "$HOLLAEX_SECRET_VARIABLES")
EOL

}

function generate_nginx_upstream() {
  
if [[ "$LOCAL_DEPLOYMENT_MODE" == "all" ]]; then 

  # Generate local nginx conf
  cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream.conf <<EOL

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

if [[ "$LOCAL_DEPLOYMENT_MODE" == "api" ]] && [[ ! "$LOCAL_DEPLOYMENT_MODE" == "ws" ]]; then

  # Generate local nginx conf
  cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream.conf <<EOL

  upstream api {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-api:10010;
  }

  upstream socket {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-api:10080;
  }

EOL

elif [[ ! "$LOCAL_DEPLOYMENT_MODE" == "api" ]] && [[ "$LOCAL_DEPLOYMENT_MODE" == "ws" ]]; then

  # Generate local nginx conf
  cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream.conf <<EOL

  upstream api {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-ws:10010;
  }
  
  upstream socket {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-ws:10080;
  }

EOL

fi

if [[ "$LOCAL_DEPLOYMENT_MODE" == "api" ]] && [[ "$LOCAL_DEPLOYMENT_MODE" == "ws" ]]; then

# Generate local nginx conf
cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream.conf <<EOL

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

function generate_nginx_config_for_plugin() {

  if [[ -f "$TEMPLATE_GENERATE_PATH/local/nginx/conf.d/plugins.conf" ]]; then

    rm $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/plugins.conf
    touch $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/plugins.conf
  
  fi

  # if [[ -f "$TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream-plugins.conf" ]]; then

  #   rm $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream-plugins.conf
  #   touch $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream-plugins.conf
  
  # fi
  
  IFS=',' read -ra PLUGINS <<< "$ENVIRONMENT_CUSTOM_PLUGINS_NAME"    #Convert string to array

  for i in "${PLUGINS[@]}"; do
    PLUGINS_UPSTREAM_NAME=$(echo $i | cut -f1 -d ",")

    CUSTOM_ENDPOINT=$(set -o posix ; set | grep "ENVIRONMENT_CUSTOM_ENDPOINT_$(echo $PLUGINS_UPSTREAM_NAME | tr a-z A-Z)" | cut -f2 -d"=")
    CUSTOM_ENDPOINT_PORT=$(set -o posix ; set | grep "ENVIRONMENT_CUSTOM_ENDPOINT_PORT_$(echo $PLUGINS_UPSTREAM_NAME | tr a-z A-Z)" | cut -f2 -d"=")
    CUSTOM_URL=$(set -o posix ; set | grep "ENVIRONMENT_CUSTOM_URL_$(echo $PLUGINS_UPSTREAM_NAME | tr a-z A-Z)" | cut -f2 -d"=")
    CUSTOM_IS_WEBSOCKET=$(set -o posix ; set | grep "ENVIRONMENT_CUSTOM_IS_WEBSOCKET_$(echo $PLUGINS_UPSTREAM_NAME | tr a-z A-Z)" | cut -f2 -d"=")

    if [[ "$USE_KUBERNETES" ]]; then

      function websocket_upgrade() {
        if  [[ "$CUSTOM_IS_WEBSOCKET" == "true" ]]; then
          echo "nginx.org/websocket-services: '${CUSTOM_ENDPOINT}'"
        fi
      }

cat >> $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-ingress.yaml <<EOL
---

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-${PLUGINS_UPSTREAM_NAME}
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    certmanager.k8s.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
    $(websocket_upgrade;)
spec:
  rules:
  - host: ${HOLLAEX_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: ${CUSTOM_URL}
        backend:
          serviceName: ${CUSTOM_ENDPOINT}
          servicePort: ${CUSTOM_ENDPOINT_PORT}
          
tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${HOLLAEX_CONFIGMAP_API_HOST}
EOL

    fi

    if [[ ! "$USE_KUBERNETES" ]]; then

      function websocket_upgrade() {
        if  [[ "$CUSTOM_IS_WEBSOCKET" == "true" ]]; then
          echo "proxy_http_version  1.1;
          proxy_set_header    Upgrade \$http_upgrade; 
          proxy_set_header    Connection \"upgrade\";"
        fi
      }
      
# Generate local nginx conf
cat >> $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream.conf <<EOL

upstream $PLUGINS_UPSTREAM_NAME {
  server ${CUSTOM_ENDPOINT}:${CUSTOM_ENDPOINT_PORT};
}
EOL

cat >> $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/plugins.conf <<EOL
location ${CUSTOM_URL} {
  $(websocket_upgrade;)
  proxy_pass      http://$PLUGINS_UPSTREAM_NAME;
}

EOL
  
  fi

  done

}

function generate_local_docker_compose_for_dev() {

echo $HOLLAEX_CODEBASE_PATH
# Generate docker-compose
cat > $HOLLAEX_CODEBASE_PATH/.${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
version: '3'
services:
  ${ENVIRONMENT_EXCHANGE_NAME}-redis:
    image: redis:5.0.5-alpine
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    ports:
      - 6379:6379
    environment:
      - REDIS_PASSWORD=${HOLLAEX_SECRET_REDIS_PASSWORD}
    command : ["sh", "-c", "redis-server --requirepass \$\${REDIS_PASSWORD}"]
  ${ENVIRONMENT_EXCHANGE_NAME}-db:
    image: postgres:10.9
    ports:
      - 5432:5432
    environment:
      - POSTGRES_DB=$HOLLAEX_SECRET_DB_NAME
      - POSTGRES_USER=$HOLLAEX_SECRET_DB_USERNAME
      - POSTGRES_PASSWORD=$HOLLAEX_SECRET_DB_PASSWORD
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
  ${ENVIRONMENT_EXCHANGE_NAME}-influxdb:
    image: influxdb:1.7-alpine
    ports:
      - 8086:8086
    environment:
      - INFLUX_DB=$HOLLAEX_SECRET_INFLUX_DB
      - INFLUX_HOST=${ENVIRONMENT_EXCHANGE_NAME}-influxdb
      - INFLUX_PORT=8086
      - INFLUX_USER=$HOLLAEX_SECRET_INFLUX_USER
      - INFLUX_PASSWORD=$HOLLAEX_SECRET_INFLUX_PASSWORD
      - INFLUXDB_HTTP_LOG_ENABLED=false
      - INFLUXDB_DATA_QUERY_LOG_ENABLED=false
      - INFLUXDB_CONTINUOUS_QUERIES_LOG_ENABLED=false
      - INFLUXDB_LOGGING_LEVEL=error
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
  ${ENVIRONMENT_EXCHANGE_NAME}-server:
    image: ${ENVIRONMENT_EXCHANGE_NAME}-server-pm2
    build:
      context: .
      dockerfile: ${HOLLAEX_CODEBASE_PATH}/tools/Dockerfile.pm2
    env_file:
      - ${TEMPLATE_GENERATE_PATH}/local/${ENVIRONMENT_EXCHANGE_NAME}.env.local
    entrypoint:
      - pm2-runtime
      - start
      - ecosystem.config.js
      - --env
      - development
    volumes:
      - ${HOLLAEX_CODEBASE_PATH}/api:/app/api
      - ${HOLLAEX_CODEBASE_PATH}/config:/app/config
      - ${HOLLAEX_CODEBASE_PATH}/db:/app/db
      - ${HOLLAEX_CODEBASE_PATH}/mail:/app/mail
      - ${HOLLAEX_CODEBASE_PATH}/queue:/app/queue
      - ${HOLLAEX_CODEBASE_PATH}/ws:/app/ws
      - ${HOLLAEX_CODEBASE_PATH}/app.js:/app/app.js
      - ${HOLLAEX_CODEBASE_PATH}/ecosystem.config.js:/app/ecosystem.config.js
      - ${HOLLAEX_CODEBASE_PATH}/constants.js:/app/constants.js
      - ${HOLLAEX_CODEBASE_PATH}/messages.js:/app/messages.js
      - ${HOLLAEX_CODEBASE_PATH}/logs:/app/logs
      - ${HOLLAEX_CODEBASE_PATH}/test:/app/test
      - ${HOLLAEX_CODEBASE_PATH}/tools:/app/tools
      - ${HOLLAEX_CODEBASE_PATH}/utils:/app/utils
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
      - ${ENVIRONMENT_EXCHANGE_NAME}-influxdb
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
  ${ENVIRONMENT_EXCHANGE_NAME}-nginx:
    image: nginx:1.15.8-alpine
    volumes:
      - ${TEMPLATE_GENERATE_PATH}/nginx:/etc/nginx
      - ${TEMPLATE_GENERATE_PATH}/local/nginx/conf.d:/etc/nginx/conf.d
      - ${TEMPLATE_GENERATE_PATH}/local/logs/nginx:/var/log
      - ${TEMPLATE_GENERATE_PATH}/nginx/static/:/usr/share/nginx/html
    ports:
      - 80:80
    environment:
      - NGINX_PORT=80
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-server
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network

networks:
  ${ENVIRONMENT_EXCHANGE_NAME}-network:

EOL

}


function generate_local_docker_compose() {

# Generate docker-compose
cat > $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
version: '3'
services:
EOL

if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" == "true" ]]; then 

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-redis:
    image: redis:5.0.5-alpine
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    ports:
      - 6379:6379
    environment:
      - REDIS_PASSWORD=${HOLLAEX_SECRET_REDIS_PASSWORD}
    command : ["sh", "-c", "redis-server --requirepass \$\${REDIS_PASSWORD}"]

EOL
fi

if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" == "true" ]]; then 
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-db:
    image: postgres:10.9
    ports:
      - 5432:5432
    environment:
      - POSTGRES_DB=$HOLLAEX_SECRET_DB_NAME
      - POSTGRES_USER=$HOLLAEX_SECRET_DB_USERNAME
      - POSTGRES_PASSWORD=$HOLLAEX_SECRET_DB_PASSWORD
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network

EOL

fi

if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" == "true" ]]; then
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-influxdb:
    image: influxdb:1.7-alpine
    ports:
      - 8086:8086
    environment:
      - INFLUX_DB=$HOLLAEX_SECRET_INFLUX_DB
      - INFLUX_HOST=${ENVIRONMENT_EXCHANGE_NAME}-influxdb
      - INFLUX_PORT=8086
      - INFLUX_USER=$HOLLAEX_SECRET_INFLUX_USER
      - INFLUX_PASSWORD=$HOLLAEX_SECRET_INFLUX_PASSWORD
      - INFLUXDB_HTTP_LOG_ENABLED=false
      - INFLUXDB_DATA_QUERY_LOG_ENABLED=false
      - INFLUXDB_CONTINUOUS_QUERIES_LOG_ENABLED=false
      - INFLUXDB_LOGGING_LEVEL=error
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network

EOL
fi 

if [[ "$1" == "all" ]]; then

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

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

  ${ENVIRONMENT_EXCHANGE_NAME}-nginx:
    image: nginx:1.15.8-alpine
    volumes:
      - ./nginx:/etc/nginx
      - ./logs/nginx:/var/log
      - ./nginx/static/:/usr/share/nginx/html
    ports:
      - 80:80
    environment:
      - NGINX_PORT=80
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-server
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network

EOL


elif [[ "$1" == "all" ]] && [[ ! "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" == "true" ]] && [[ ! "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" == "true" ]] && [[ ! "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" == "true" ]] ; then

 # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

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
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network

  ${ENVIRONMENT_EXCHANGE_NAME}-nginx:
    image: nginx:1.15.8-alpine
    volumes:
      - ./nginx:/etc/nginx
      - ./logs/nginx:/var/log
      - ./nginx/static/:/usr/share/nginx/html
    ports:
      - 80:80
    environment:
      - NGINX_PORT=80
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-server
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network

EOL

else

#LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE=$ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE

IFS=',' read -ra LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE <<< "$ENVIRONMENT_DOCKER_COMPOSE_RUN_MODE"

  for i in ${LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE[@]}; do

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

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

  if [[ "$i" == "api" ]]; then
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
    ports:
      - 10010:10010
EOL

  elif [[ "$i" == "ws" ]]; then

  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
    ports:
      - 10080:10080
EOL

  fi
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL

done

fi

# Generate docker-compose
cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

networks:
  ${ENVIRONMENT_EXCHANGE_NAME}-network:
  
EOL

}

function generate_kubernetes_configmap() {

# Generate Kubernetes Configmap
cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-configmap.yaml <<EOL
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
cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-secret.yaml <<EOL
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
cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-ingress.yaml <<EOL
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
      limit_req zone=api burst=5 nodelay;
      limit_req_log_level notice;
      limit_req_status 429;
spec:
  rules:
  - host: ${HOLLAEX_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /v0
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010

  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${HOLLAEX_CONFIGMAP_API_HOST}

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
  - host: ${HOLLAEX_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /v0/order
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010
  
  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${HOLLAEX_CONFIGMAP_API_HOST}

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
  - host: ${HOLLAEX_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /v0/admin
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010

  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${HOLLAEX_CONFIGMAP_API_HOST}

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
  - host: ${HOLLAEX_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /socket.io
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-ws
          servicePort: 10080
  
  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${HOLLAEX_CONFIGMAP_API_HOST}
EOL

}

function generate_random_values() {

  python -c "import os; print os.urandom(16).encode('hex')"

}

function update_random_values_to_config() {


GENERATE_VALUES_LIST=( "HOLLAEX_SECRET_ADMIN_PASSWORD" "HOLLAEX_SECRET_SUPERVISOR_PASSWORD" "HOLLAEX_SECRET_SUPPORT_PASSWORD" "HOLLAEX_SECRET_KYC_PASSWORD" "HOLLAEX_SECRET_QUICK_TRADE_SECRET" "HOLLAEX_SECRET_API_KEYS" "HOLLAEX_SECRET_SECRET" )

for j in ${CONFIG_FILE_PATH[@]}; do

  if command grep -q "HOLLAEX_SECRET" $j > /dev/null ; then

    SECRET_CONFIG_FILE_PATH=$j

    if command grep -q "HOLLAEX_SECRET_ADMIN_PASSWORD" $SECRET_CONFIG_FILE_PATH ; then
  
      echo "*** Pre-generated secrets are detected on your secert file! ***"
      echo "Are you sure you want to override them? (y/n)"

      read answer

      if [[ "$answer" == "${answer#[Nn]}" ]]; then

        for k in ${GENERATE_VALUES_LIST[@]}; do

          grep -v $k $SECRET_CONFIG_FILE_PATH > temp && mv temp $SECRET_CONFIG_FILE_PATH

          # Using special form to generate both API_KEYS keys and secret
          if [[ "$k" == "HOLLAEX_SECRET_API_KEYS" ]]; then

            cat >> $SECRET_CONFIG_FILE_PATH <<EOL
$k=$(generate_random_values):$(generate_random_values)
EOL

          else 

            cat >> $SECRET_CONFIG_FILE_PATH <<EOL
$k=$(generate_random_values)
EOL

          fi
        
        done

      else

        echo "*** Skipping... ***"

      fi

    fi
  fi
done

unset GENERATE_VALUES_LIST
 
}

function generate_nodeselector_values() {

INPUT_VALUE=$1
CONVERTED_VALUE=$(printf "${INPUT_VALUE/:/: }")

# Generate Kubernetes Secret
cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-$2.yaml <<EOL
nodeSelector: $(echo $CONVERTED_VALUE)
EOL

}

# `helm_dynamic_trading_paris run` for running paris based on config file definition.
# `helm_dynamic_trading_paris terminate` for terminating installed paris on kubernetes.

function helm_dynamic_trading_paris() {

  IFS=',' read -ra PAIRS <<< "$HOLLAEX_CONFIGMAP_PAIRS"    #Convert string to array

  for i in "${PAIRS[@]}"; do
    TRADE_PARIS_DEPLOYMENT=$(echo $i | cut -f1 -d ",")
    TRADE_PARIS_DEPLOYMENT_NAME=${TRADE_PARIS_DEPLOYMENT//-/}

    if [[ "$1" == "run" ]]; then

      #Running and Upgrading
      helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-server-queue-$TRADE_PARIS_DEPLOYMENT_NAME --namespace $ENVIRONMENT_EXCHANGE_NAME --recreate-pods --set DEPLOYMENT_MODE="queue $TRADE_PARIS_DEPLOYMENT" --set imageRegistry="$ENVIRONMENT_DOCKER_IMAGE_REGISTRY" --set dockerTag="$ENVIRONMENT_DOCKER_IMAGE_VERSION" --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" --set podRestart_webhook_url="$ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL" -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex.yaml -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server

    elif [[ "$1" == "scaleup" ]]; then
      
      #Scaling down queue deployments on Kubernetes
      kubectl scale deployment/$ENVIRONMENT_EXCHANGE_NAME-server-queue-$TRADE_PARIS_DEPLOYMENT_NAME --replicas=1 --namespace $ENVIRONMENT_EXCHANGE_NAME

    elif [[ "$1" == "scaledown" ]]; then
      
      #Scaling down queue deployments on Kubernetes
      kubectl scale deployment/$ENVIRONMENT_EXCHANGE_NAME-server-queue-$TRADE_PARIS_DEPLOYMENT_NAME --replicas=0 --namespace $ENVIRONMENT_EXCHANGE_NAME

    elif [[ "$1" == "terminate" ]]; then

      #Terminating
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-server-queue-$TRADE_PARIS_DEPLOYMENT_NAME

    fi

  done

}
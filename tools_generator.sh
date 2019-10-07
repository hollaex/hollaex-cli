#!/bin/bash 
SCRIPTPATH=$HOME/.hex-cli

function local_database_init() {

    if [[ "$RUN_WITH_VERIFY" == true ]]; then

        echo "Are you sure you want to run database init jobs for your local $ENVIRONMENT_EXCHANGE_NAME db? (y/N)"

        read answer

      if [[ "$answer" = "${answer#[Yy]}" ]]; then
        echo "Exiting..."
        exit 0;
      fi

    fi
    
    if [[ "$1" == "start" ]]; then

      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

      echo "Running sequelize db:migrate"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 sequelize db:migrate

      echo "Running database triggers"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js

      echo "Running sequelize db:seed:all"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 sequelize db:seed:all

      echo "Running InfluxDB migrations"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/createInflux.js
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/migrateInflux.js
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/initializeInflux.js

      echo "Setting up the exchange with provided activation code"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/setExchange.js

    elif [[ "$1" == 'upgrade' ]]; then

      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

      echo "Running sequelize db:migrate"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 sequelize db:migrate

      echo "Running database triggers"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/runTriggers.js

      echo "Running InfluxDB initialization"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/initializeInflux.js
    
    elif [[ "$1" == 'dev' ]]; then

      echo "Running sequelize db:migrate"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server_1 sequelize db:migrate

      echo "Running database triggers"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server_1 node tools/dbs/runTriggers.js

      echo "Running sequelize db:seed:all"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server_1 sequelize db:seed:all

      echo "Running InfluxDB migrations"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server_1 node tools/dbs/createInflux.js
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server_1 node tools/dbs/migrateInflux.js
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server_1 node tools/dbs/initializeInflux.js

    fi
}

function kubernetes_database_init() {

  # Checks the api container(s) get ready enough to run database upgrade jobs.
  while ! kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- echo "API is ready!" > /dev/null 2>&1;
      do echo "API container is not ready! Retrying..."
      sleep 10;
  done;

  echo "API container become ready to run Database initialization jobs!"
  sleep 10;

  if [[ "$1" == "launch" ]]; then

    echo "Running sequelize db:migrate"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- sequelize db:migrate 

    echo "Running Database Triggers"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/runTriggers.js

    echo "Running sequelize db:seed:all"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- sequelize db:seed:all 

    echo "Running InfluxDB migrations"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/createInflux.js
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/migrateInflux.js
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/initializeInflux.js

    echo "Setting up the exchange with provided activation code"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/setExchange.js

  elif [[ "$1" == "upgrade" ]]; then

    echo "Running sequelize db:migrate"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- sequelize db:migrate 

    echo "Running Database Triggers"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/runTriggers.js

    echo "Running InfluxDB migrations"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/initializeInflux.js

  fi

  echo "Restarting all containers to apply latest database changes..."
  kubectl delete pods --namespace $ENVIRONMENT_EXCHANGE_NAME -l role=$ENVIRONMENT_EXCHANGE_NAME

  echo "Waiting for the containers get fully ready..."
  sleep 30;

}

function local_code_test() {

    echo "Running mocha code test"
    docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server-api_1 mocha --exit

    exit 0;
}

function check_kubernetes_dependencies() {

    # Checking kubectl and helm are installed on this machine.
    if command kubectl version > /dev/null 2>&1 && command helm version > /dev/null 2>&1; then

         echo "kubectl and helm detected"

    else

         echo "hex-cli failed to detect kubectl or helm installed on this machine. Please install it before running hex-cli."
         exit 1;

    fi

}

 
function load_config_variables() {

  HEX_CONFIGMAP_VARIABLES=$(set -o posix ; set | grep "HEX_CONFIGMAP" | cut -c15-)
  HEX_SECRET_VARIABLES=$(set -o posix ; set | grep "HEX_SECRET" | cut -c12-)

  HEX_CONFIGMAP_VARIABLES_YAML=$(for value in ${HEX_CONFIGMAP_VARIABLES} 
  do 
      if [[ $value == *"'"* ]]; then
        printf "  ${value//=/: }\n";
      else
        printf "  ${value//=/: \'}'\n";
      fi

  done)

  HEX_SECRET_VARIABLES_BASE64=$(for value in ${HEX_SECRET_VARIABLES} 
  do
      printf "${value//$(cut -d "=" -f 2 <<< "$value")/$(cut -d "=" -f 2 <<< "$value" | tr -d '\n' | tr -d "'" | base64)} ";
  
  done)

  HEX_SECRET_VARIABLES_YAML=$(for value in ${HEX_SECRET_VARIABLES_BASE64} 
  do

      printf "  ${value/=/: }\n";

  done)

}

function generate_local_env() {

# Generate local env
cat > $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}.env.local <<EOL
DB_DIALECT=postgres

$(echo "$HEX_CONFIGMAP_VARIABLES" | tr -d '\'\')

$(echo "$HEX_SECRET_VARIABLES" | tr -d '\'\')
EOL

}

function generate_nginx_upstream() {

IFS=',' read -ra LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE <<< "$ENVIRONMENT_EXCHANGE_RUN_MODE"

for i in ${LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE[@]}; do
  
  if [[ "$i" == "api" ]]; then 

  # Generate local nginx conf
  cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream.conf <<EOL
  upstream api {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-api:10010;
  }
  upstream socket {
    ip_hash;
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-stream:10080;
  }
EOL

  fi

done


#Upstream generator for dev environments
if [[ "$IS_DEVELOP" ]]; then

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

}

function generate_nginx_upstream_for_web(){

  # Generate local nginx conf
  cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream-web.conf <<EOL

  upstream web {
    server host.docker.internal:8080;
  }
EOL

}

function apply_nginx_user_defined_values(){
          #sed -i.bak "s/$ENVIRONMENT_DOCKER_IMAGE_VERSION/$ENVIRONMENT_DOCKER_IMAGE_VERSION_OVERRIDE/" $CONFIGMAP_FILE_PATH

      sed -i.bak "s/server_name.*\#Server.*/server_name $HEX_CONFIGMAP_API_HOST; \#Server domain/" $TEMPLATE_GENERATE_PATH/local/nginx/nginx.conf
      rm $TEMPLATE_GENERATE_PATH/local/nginx/nginx.conf.bak

    if [[ "$ENVIRONMENT_WEB_ENABLE" == true ]]; then 
      CLIENT_DOMAIN=$(echo $HEX_CONFIGMAP_DOMAIN | cut -f3 -d "/")
      sed -i.bak "s/server_name.*\#Client.*/server_name $CLIENT_DOMAIN; \#Client domain/" $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/web.conf
      rm $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/web.conf.bak
    fi
}

function generate_nginx_config_for_plugin() {

  if [[ -f "$TEMPLATE_GENERATE_PATH/local/nginx/conf.d/plugins.conf" ]]; then

    rm $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/plugins.conf
    touch $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/plugins.conf
  
  fi
  
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
  - host: ${HEX_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: ${CUSTOM_URL}
        backend:
          serviceName: ${CUSTOM_ENDPOINT}
          servicePort: ${CUSTOM_ENDPOINT_PORT}
          
tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${HEX_CONFIGMAP_API_HOST}
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

echo $HEX_CODEBASE_PATH
# Generate docker-compose
cat > $HEX_CODEBASE_PATH/.${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
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
      - REDIS_PASSWORD=${HEX_SECRET_REDIS_PASSWORD}
    command : ["sh", "-c", "redis-server --requirepass \$\${REDIS_PASSWORD}"]
  ${ENVIRONMENT_EXCHANGE_NAME}-db:
    image: postgres:10.9
    ports:
      - 5432:5432
    environment:
      - POSTGRES_DB=$HEX_SECRET_DB_NAME
      - POSTGRES_USER=$HEX_SECRET_DB_USERNAME
      - POSTGRES_PASSWORD=$HEX_SECRET_DB_PASSWORD
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
  ${ENVIRONMENT_EXCHANGE_NAME}-influxdb:
    image: influxdb:1.7-alpine
    ports:
      - 8086:8086
    environment:
      - INFLUX_DB=$HEX_SECRET_INFLUX_DB
      - INFLUX_HOST=${ENVIRONMENT_EXCHANGE_NAME}-influxdb
      - INFLUX_PORT=8086
      - INFLUX_USER=$HEX_SECRET_INFLUX_USER
      - INFLUX_PASSWORD=$HEX_SECRET_INFLUX_PASSWORD
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
      dockerfile: ${HEX_CODEBASE_PATH}/tools/Dockerfile.pm2
    env_file:
      - ${TEMPLATE_GENERATE_PATH}/local/${ENVIRONMENT_EXCHANGE_NAME}.env.local
    entrypoint:
      - pm2-runtime
      - start
      - ecosystem.config.js
      - --env
      - development
    volumes:
      - ${HEX_CODEBASE_PATH}/api:/app/api
      - ${HEX_CODEBASE_PATH}/config:/app/config
      - ${HEX_CODEBASE_PATH}/db:/app/db
      - ${HEX_CODEBASE_PATH}/mail:/app/mail
      - ${HEX_CODEBASE_PATH}/queue:/app/queue
      - ${HEX_CODEBASE_PATH}/ws:/app/ws
      - ${HEX_CODEBASE_PATH}/app.js:/app/app.js
      - ${HEX_CODEBASE_PATH}/ecosystem.config.js:/app/ecosystem.config.js
      - ${HEX_CODEBASE_PATH}/constants.js:/app/constants.js
      - ${HEX_CODEBASE_PATH}/messages.js:/app/messages.js
      - ${HEX_CODEBASE_PATH}/logs:/app/logs
      - ${HEX_CODEBASE_PATH}/test:/app/test
      - ${HEX_CODEBASE_PATH}/tools:/app/tools
      - ${HEX_CODEBASE_PATH}/utils:/app/utils
      - ${HEX_CODEBASE_PATH}/init.js:/app/init.js
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
    restart: always
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
    ports:
      - 6379:6379
    environment:
      - REDIS_PASSWORD=${HEX_SECRET_REDIS_PASSWORD}
    command : ["sh", "-c", "redis-server --requirepass \$\${REDIS_PASSWORD}"]
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL

fi

if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" == "true" ]]; then 
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-db:
    image: postgres:10.9
    restart: always
    ports:
      - 5432:5432
    environment:
      - POSTGRES_DB=$HEX_SECRET_DB_NAME
      - POSTGRES_USER=$HEX_SECRET_DB_USERNAME
      - POSTGRES_PASSWORD=$HEX_SECRET_DB_PASSWORD
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL

fi

if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" == "true" ]]; then
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-influxdb:
    image: influxdb:1.7-alpine
    restart: always
    ports:
      - 8086:8086
    environment:
      - INFLUX_DB=$HEX_SECRET_INFLUX_DB
      - INFLUX_HOST=${ENVIRONMENT_EXCHANGE_NAME}-influxdb
      - INFLUX_PORT=8086
      - INFLUX_USER=$HEX_SECRET_INFLUX_USER
      - INFLUX_PASSWORD=$HEX_SECRET_INFLUX_PASSWORD
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

#LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE=$ENVIRONMENT_EXCHANGE_RUN_MODE

IFS=',' read -ra LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE <<< "$ENVIRONMENT_EXCHANGE_RUN_MODE"

for i in ${LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE[@]}; do

  if [[ ! "$i" == "engine" ]]; then

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

  ${ENVIRONMENT_EXCHANGE_NAME}-server-${i}:
    image: $ENVIRONMENT_DOCKER_IMAGE_REGISTRY:$ENVIRONMENT_DOCKER_IMAGE_VERSION
    restart: always
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    entrypoint:
      - /app/${i}-binary
    $(if [[ "${i}" == "api" ]] || [[ "${i}" == "stream" ]]; then echo "ports:"; fi)
      $(if [[ "${i}" == "api" ]]; then echo "- 10010:10010"; fi) 
      $(if [[ "${i}" == "stream" ]]; then echo "- 10080:10080"; fi)
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" ]] || [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" ]] || [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" ]]; then echo "depends_on:"; fi)
      $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-influxdb"; fi)
      $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-redis"; fi)
      $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-db"; fi)

EOL

  fi

  if [[ "$i" == "api" ]]; then
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

  ${ENVIRONMENT_EXCHANGE_NAME}-nginx:
    image: bitholla/nginx-with-certbot:1.15.8
    restart: always
    volumes:
      - ./nginx:/etc/nginx
      - ./logs/nginx:/var/log/nginx
      - ./nginx/static/:/usr/share/nginx/html
      - ./letsencrypt:/etc/letsencrypt
    ports:
      - 80:80
      - 443:443
    environment:
      - NGINX_PORT=80
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-server-${i}
      $(if [[ "$ENVIRONMENT_WEB_ENABLE" == true ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-web"; fi)
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
      
EOL

  fi

  if [[ "$i" == "engine" ]]; then

  IFS=',' read -ra PAIRS <<< "$HEX_CONFIGMAP_PAIRS"    #Convert string to array

  for j in "${PAIRS[@]}"; do
    TRADE_PARIS_DEPLOYMENT=$(echo $j | cut -f1 -d ",")

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

  ${ENVIRONMENT_EXCHANGE_NAME}-server-${i}-$TRADE_PARIS_DEPLOYMENT:
    image: $ENVIRONMENT_DOCKER_IMAGE_REGISTRY:$ENVIRONMENT_DOCKER_IMAGE_VERSION
    restart: always
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    environment:
      - PAIR=${TRADE_PARIS_DEPLOYMENT}
    entrypoint:
      - /app/${i}-binary
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" ]] || [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" ]] || [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" ]]; then echo "depends_on:"; fi)
      $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-influxdb"; fi)
      $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-redis"; fi)
      $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-db"; fi)
      
EOL

  done

  fi

done

# Generate docker-compose
cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
networks:
  ${ENVIRONMENT_EXCHANGE_NAME}-network:
  
EOL

}

function generate_local_docker_compose_for_web() {

# Generate docker-compose
cat > $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose-web.yaml <<EOL
version: '3'
services:
EOL

if [[ "$ENVIRONMENT_WEB_ENABLE" == true ]]; then
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose-web.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-web:
    image: bitholla/hex-web:${ENVIRONMENT_EXCHANGE_NAME}
    build:
      context: ${HEX_CLI_INIT_PATH}/web/
      dockerfile: ${HEX_CLI_INIT_PATH}/web/docker/Dockerfile
    restart: always
    ports:
      - 8080:80
    volumes:
      - ${HEX_CLI_INIT_PATH}/mail:/app/mail
EOL

fi

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
${HEX_CONFIGMAP_VARIABLES_YAML}
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
${HEX_SECRET_VARIABLES_YAML}
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
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo "certmanager.k8s.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      limit_req zone=api burst=5 nodelay;
      limit_req_log_level notice;
      limit_req_status 429;
spec:
  rules:
  - host: ${HEX_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /v1
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010

  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${HEX_CONFIGMAP_API_HOST}

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api-order
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo "certmanager.k8s.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      limit_req zone=order burst=3 nodelay;
      limit_req_log_level notice;
      limit_req_status 429;
spec:
  rules:
  - host: ${HEX_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /v1/order
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010
  
  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${HEX_CONFIGMAP_API_HOST}

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api-admin
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo "certmanager.k8s.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
spec:
  rules:
  - host: ${HEX_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /v1/admin
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010

  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${HEX_CONFIGMAP_API_HOST}

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-stream
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo "certmanager.k8s.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
    nginx.org/websocket-services: "${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}-server-stream"
spec:
  rules:
  - host: ${HEX_CONFIGMAP_API_HOST}
    http:
      paths:
      - path: /socket.io
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-stream
          servicePort: 10080
  
  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - ${HEX_CONFIGMAP_API_HOST}
EOL

if [[ "$ENVIRONMENT_WEB_ENABLE" ]]; then

local WEB_DOMAIN_FOR_INGRESS=$HEX_CONFIGMAP_DOMAIN

  # Generate Kubernetes Secret
cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-ingress-web.yaml <<EOL

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-web
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo "certmanager.k8s.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"

spec:
  rules:
  - host: ${WEB_DOMAIN_FOR_INGRESS}
    http:
      paths:
      - path: /
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-web
          servicePort: 80
  
  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-web-tls-cert
    hosts:
    - ${WEB_DOMAIN_FOR_INGRESS}

EOL

fi

}

function generate_random_values() {

  python -c "import os; print os.urandom(16).encode('hex')"

}

function update_random_values_to_config() {


GENERATE_VALUES_LIST=( "HEX_SECRET_SUPERVISOR_PASSWORD" "HEX_SECRET_SUPPORT_PASSWORD" "HEX_SECRET_KYC_PASSWORD" "HEX_SECRET_QUICK_TRADE_SECRET" "HEX_SECRET_SECRET" )

for j in ${CONFIG_FILE_PATH[@]}; do

  if command grep -q "HEX_SECRET" $j > /dev/null ; then

    SECRET_CONFIG_FILE_PATH=$j

    if [[ ! -z "$HEX_SECRET_SECRET" ]] ; then
  
      echo "Pre-generated secrets are detected on your secert file!"
      echo "Are you sure you want to override them? (y/n)"

      read answer

      if [[ "$answer" == "${answer#[Nn]}" ]]; then

        for k in ${GENERATE_VALUES_LIST[@]}; do

          grep -v $k $SECRET_CONFIG_FILE_PATH > temp && mv temp $SECRET_CONFIG_FILE_PATH

          # Using special form to generate both API_KEYS keys and secret
          if [[ "$k" == "HEX_SECRET_API_KEYS" ]]; then

            cat >> $SECRET_CONFIG_FILE_PATH <<EOL
$k=$(generate_random_values):$(generate_random_values)
EOL

          else 

            cat >> $SECRET_CONFIG_FILE_PATH <<EOL
$k=$(generate_random_values)
EOL

          fi
        
        done

        unset k
        unset GENERATE_VALUES_LIST
        unset HEX_CONFIGMAP_VARIABLES
        unset HEX_SECRET_VARIABLES
        unset HEX_SECRET_VARIABLES_BASE64
        unset HEX_SECRET_VARIABLES_YAML
        unset HEX_CONFIGMAP_VARIABLES_YAML

        for i in ${CONFIG_FILE_PATH[@]}; do
            source $i
        done;

        load_config_variables;

      else

        echo "Skipping..."

      fi

    elif [[ -z "$HEX_SECRET_SECRET" ]] ; then

      for k in ${GENERATE_VALUES_LIST[@]}; do

          grep -v $k $SECRET_CONFIG_FILE_PATH > temp && mv temp $SECRET_CONFIG_FILE_PATH

          # Using special form to generate both API_KEYS keys and secret
          if [[ "$k" == "HEX_SECRET_API_KEYS" ]]; then

            cat >> $SECRET_CONFIG_FILE_PATH <<EOL
$k=$(generate_random_values):$(generate_random_values)
EOL

          else 

            cat >> $SECRET_CONFIG_FILE_PATH <<EOL
$k=$(generate_random_values)
EOL

          fi
        
        done

        unset k
        unset GENERATE_VALUES_LIST
        unset HEX_CONFIGMAP_VARIABLES
        unset HEX_SECRET_VARIABLES
        unset HEX_SECRET_VARIABLES_BASE64
        unset HEX_SECRET_VARIABLES_YAML
        unset HEX_CONFIGMAP_VARIABLES_YAML

        for i in ${CONFIG_FILE_PATH[@]}; do
            source $i
        done;

        load_config_variables;

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

  IFS=',' read -ra PAIRS <<< "$HEX_CONFIGMAP_PAIRS"    #Convert string to array

  for i in "${PAIRS[@]}"; do
    TRADE_PARIS_DEPLOYMENT=$(echo $i | cut -f1 -d ",")
    TRADE_PARIS_DEPLOYMENT_NAME=${TRADE_PARIS_DEPLOYMENT//-/}

    if [[ "$1" == "run" ]]; then

      #Running and Upgrading
      helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-server-engine-$TRADE_PARIS_DEPLOYMENT_NAME --namespace $ENVIRONMENT_EXCHANGE_NAME --recreate-pods --set DEPLOYMENT_MODE="engine" --set PAIR="$TRADE_PARIS_DEPLOYMENT" --set imageRegistry="$ENVIRONMENT_DOCKER_IMAGE_REGISTRY" --set dockerTag="$ENVIRONMENT_DOCKER_IMAGE_VERSION" --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" --set podRestart_webhook_url="$ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL" -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hex.yaml -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server/values.yaml $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server

    elif [[ "$1" == "scaleup" ]]; then
      
      #Scaling down queue deployments on Kubernetes
      kubectl scale deployment/$ENVIRONMENT_EXCHANGE_NAME-server-engine-$TRADE_PARIS_DEPLOYMENT_NAME --replicas=1 --namespace $ENVIRONMENT_EXCHANGE_NAME

    elif [[ "$1" == "scaledown" ]]; then
      
      #Scaling down queue deployments on Kubernetes
      kubectl scale deployment/$ENVIRONMENT_EXCHANGE_NAME-server-engine-$TRADE_PARIS_DEPLOYMENT_NAME --replicas=0 --namespace $ENVIRONMENT_EXCHANGE_NAME

    elif [[ "$1" == "terminate" ]]; then

      #Terminating
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-server-engine-$TRADE_PARIS_DEPLOYMENT_NAME

    fi

  done

}

function check_empty_values_on_settings() {

  for i in ${HEX_CONFIGMAP_VARIABLES[@]}; do

    PARSED_CONFIGMAP_VARIABLES=$(echo $i | cut -f2 -d '=')

    if [[ -z $PARSED_CONFIGMAP_VARIABLES ]]; then

      echo -e "\nWarning! Configmap - \"$(echo $i | cut -f1 -d '=')\" got an empty value! Please reconfirm the settings files.\n"

    fi
  
  done

  GENERATE_VALUES_LIST=( "ADMIN_PASSWORD" "SUPERVISOR_PASSWORD" "SUPPORT_PASSWORD" "KYC_PASSWORD" "QUICK_TRADE_SECRET" "SECRET" )

  for i in ${HEX_SECRET_VARIABLES[@]}; do

    PARSED_SECRET_VARIABLES=$(echo $i | cut -f2 -d '=')

    if [[ -z $PARSED_SECRET_VARIABLES ]]; then

      echo -e "\nWarning! Secret - \"$(echo $i | cut -f1 -d '=')\" got an empty value! Please reconfirm the settings files."

      for k in "${GENERATE_VALUES_LIST[@]}"; do

          GENERATE_VALUES_FILTER=$(echo $i | cut -f1 -d '=')

          if [[ "$k" == "${GENERATE_VALUES_FILTER}" ]] ; then

              echo -n "\"$k\" is a value should be automatically generated by hex-cli."
              echo -e "\n"

          fi

      done

    fi
  
  done

}

function override_docker_image_version() {

  for i in ${CONFIG_FILE_PATH[@]}; do

    if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
      CONFIGMAP_FILE_PATH=$i
      sed -i.bak "s/$ENVIRONMENT_DOCKER_IMAGE_VERSION/$ENVIRONMENT_DOCKER_IMAGE_VERSION_OVERRIDE/" $CONFIGMAP_FILE_PATH
    fi
    
  done

  rm $CONFIGMAP_FILE_PATH.bak

}

# JSON generator
function join_array_to_json(){
  local arr=( "$@" );
  local len=${#arr[@]}

  if [[ ${len} -eq 0 ]]; then
          >&2 echo "Error: Length of input array needs to be at least 2.";
          return 1;
  fi

  if [[ $((len%2)) -eq 1 ]]; then
          >&2 echo "Error: Length of input array needs to be even (key/value pairs).";
          return 1;
  fi

  local data="";
  local foo=0;
  for i in "${arr[@]}"; do
          local char=","
          if [ $((++foo%2)) -eq 0 ]; then
          char=":";
          fi

          local first="${i:0:1}";  # read first charc

          local app="\"$i\""

          if [[ "$first" == "^" ]]; then
          app="${i:1}"  # remove first char
          fi

          data="$data$char$app";

  done

  data="${data:1}";  # remove first char
  echo "{$data}";    # add braces around the string
}

function add_coin_input() {

  echo "Coin Symbol: (eth)"
  read answer

  COIN_SYMBOL=${answer:-eth}

  echo "Full Name of Coin: (Ethereum)"
  read answer

  COIN_FULLNAME=${answer:-Ethereum}

  echo "Allow deposit: (Y/n)"
  read answer
  
  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    COIN_ALLOW_DEPOSIT='false'
  
  else

    COIN_ALLOW_DEPOSIT='true'

  fi

  echo "Allow Withdrawal: (Y/n)"
  read answer
  
  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    COIN_ALLOW_WITHDRAWAL='false'
  
  else

    COIN_ALLOW_WITHDRAWAL='true'

  fi
  
  echo "Fee for Withdrawal: (0.001)"
  read answer

  COIN_WITHDRAWAL_FEE=${answer:-0.001}

  echo "Minimum Price: (0.001)"
  read answer

  COIN_MIN=${answer:-0.001}

  echo "Maximum Price: (10000)"
  read answer

  COIN_MAX=${answer:-10000}

  echo "Increment Size: (0.001)"
  read answer

  COIN_INCREMENT_UNIT=${answer:-0.001}

  # Checking user level setup on settings file is set or not
  if [[ ! "$HEX_CONFIGMAP_USER_LEVEL_NUMBER" ]]; then

    echo "Warning: Settings value - HEX_CONFIGMAP_USER_LEVEL_NUMBER is not configured. Please confirm your settings files."
    exit 1;

  fi

  # Side-by-side printer 
  function print_deposit_array_side_by_side() { #LEVEL FRIST, VALUE NEXT.
    for ((i=0; i<=${#RANGE_DEPOSIT_LIMITS_LEVEL[@]}; i++)); do
    printf '%s %s\n' "${RANGE_DEPOSIT_LIMITS_LEVEL[i]}" "${VALUE_DEPOSIT_LIMITS_LEVEL[i]}"
    done
  }

  # Side-by-side printer 
  function print_withdrawal_array_side_by_side() { #LEVEL FRIST, VALUE NEXT.
    for ((i=0; i<=${#RANGE_WITHDRAWAL_LIMITS_LEVEL[@]}; i++)); do
    printf '%s %s\n' "${RANGE_WITHDRAWAL_LIMITS_LEVEL[i]}" "${VALUE_WITHDRAWAL_LIMITS_LEVEL[i]}"
    done
  }

  # Asking deposit limit of new coin per level
  for i in $(seq 1 $HEX_CONFIGMAP_USER_LEVEL_NUMBER);

    do echo "Deposit limit of user level $i:" && read answer && export DEPOSIT_LIMITS_LEVEL_$i=$answer
  
  done;

  local PARSE_RANGE_DEPOSIT_LIMITS_LEVEL=$(set -o posix ; set | grep "DEPOSIT_LIMITS_LEVEL_" | cut -c22 )
  local PARSE_VALUE_DEPOSIT_LIMITS_LEVEL=$(set -o posix ; set | grep "DEPOSIT_LIMITS_LEVEL_" | cut -f2 -d "=" )

  read -ra RANGE_DEPOSIT_LIMITS_LEVEL <<< ${PARSE_RANGE_DEPOSIT_LIMITS_LEVEL[@]}
  read -ra VALUE_DEPOSIT_LIMITS_LEVEL <<< ${PARSE_VALUE_DEPOSIT_LIMITS_LEVEL[@]}

  COIN_DEPOSIT_LIMITS=$(join_array_to_json $(print_deposit_array_side_by_side))

  # Asking withdrawal limit of new coin per level
  for i in $(seq 1 $HEX_CONFIGMAP_USER_LEVEL_NUMBER);

    do echo "Withdrawal limit of user level $i" && read answer && export WITHDRAWAL_LIMITS_LEVEL_$i=$answer
  
  done;

  local PARSE_RANGE_WITHDRAWAL_LIMITS_LEVEL=$(set -o posix ; set | grep "WITHDRAWAL_LIMITS_LEVEL_" | cut -c25 )
  local PARSE_VALUE_WITHDRAWAL_LIMITS_LEVEL=$(set -o posix ; set | grep "WITHDRAWAL_LIMITS_LEVEL_" | cut -f2 -d "=" )

  read -ra RANGE_WITHDRAWAL_LIMITS_LEVEL <<< ${PARSE_RANGE_WITHDRAWAL_LIMITS_LEVEL[@]}
  read -ra VALUE_WITHDRAWAL_LIMITS_LEVEL <<< ${PARSE_VALUE_WITHDRAWAL_LIMITS_LEVEL[@]}

  COIN_WITHDRAWAL_LIMITS=$(join_array_to_json $(print_withdrawal_array_side_by_side))

  echo "Activate Coin: (Y/n)"
  read answer
  
  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    COIN_ACTIVE='false'
  
  else

    COIN_ACTIVE='true'

  fi

  function print_coin_add_deposit_level(){ 

    for i in $(set -o posix ; set | grep "DEPOSIT_LIMITS_LEVEL_");

      do echo -e "$i"

    done;

  }

  function print_coin_add_withdrawal_level(){ 

    for i in $(set -o posix ; set | grep "WITHDRAWAL_LIMITS_LEVEL_");

      do echo -e "$i"

    done;

  }
  
  echo "*********************************************"
  echo "Symbol: $COIN_SYMBOL"
  echo "Full name: $COIN_FULLNAME"
  echo "Allow deposit: $COIN_ALLOW_DEPOSIT"
  echo "Allow withdrawal: $COIN_ALLOW_WITHDRAWAL"
  echo "Minimum price: $COIN_MIN"
  echo "Maximum price: $COIN_MAX"
  echo "Increment size: $COIN_INCREMENT_UNIT"
  echo "Deposit limits per level: $COIN_DEPOSIT_LIMITS"
  echo "Withdrawal limits per level: $COIN_WITHDRAWAL_LIMITS"
  echo "Activation: $COIN_ACTIVE"
  echo "*********************************************"

  echo "Are the values are all correct? (y/N)"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "You chose false. Please confirm the values and re-run the command."
    exit 1;
  
  fi
}


function add_coin_exec() {

  if [[ "$USE_KUBERNETES" ]]; then


    function generate_kubernetes_add_coin_values() {

    # Generate Kubernetes Configmap
    cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/add-coin.yaml <<EOL
job:
  enable: true
  mode: add_coin
  env:
    coin_symbol: ${COIN_SYMBOL}
    coin_fullname: ${COIN_FULLNAME}
    coin_allow_deposit: ${COIN_ALLOW_DEPOSIT}
    coin_allow_withdrawal: ${COIN_ALLOW_WITHDRAWAL}
    coin_withdrawal_fee: ${COIN_WITHDRAWAL_FEE}
    coin_min: ${COIN_MIN}
    coin_max: ${COIN_MAX}
    coin_increment_unit: ${COIN_INCREMENT_UNIT}
    coin_deposit_limits: '${COIN_DEPOSIT_LIMITS}'
    coin_withdrawal_limits: '${COIN_WITHDRAWAL_LIMITS}'
    coin_active: ${COIN_ACTIVE}
EOL

    }

    generate_kubernetes_add_coin_values;

    echo "Blocking exchange external connections"
    kubectl delete -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    echo "Adding new coin $COIN_SYMBOL on Kubernetes"
    
    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL --namespace $ENVIRONMENT_EXCHANGE_NAME --set job.enable="true" --set job.mode="add_coin" --set DEPLOYMENT_MODE="api" --set imageRegistry="$ENVIRONMENT_DOCKER_IMAGE_REGISTRY" --set dockerTag="$ENVIRONMENT_DOCKER_IMAGE_VERSION" --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hex.yaml -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server/values.yaml -f $TEMPLATE_GENERATE_PATH/kubernetes/config/add-coin.yaml $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server; then

      echo "Kubernetes Job has been created for adding new coin $COIN_SYMBOL."

      echo "Waiting until Job get completely run"
      sleep 30;

    else 

      echo "Failed to create Kubernetes Job for adding new coin $COIN_SYMBOL, Please confirm your input values and try again."
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL

      echo "Allowing exchange external connections"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml


    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Coin $COIN_SYMBOL has been successfully added on your exchange!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL
      
      echo "Upgrading exchange with latest settings..."
      hex upgrade --kube --no_verify

      echo "Removing created Kubernetes Job for adding new coin..."
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL

      echo "Updating settings file to add new $COIN_SYMBOL."
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          HEX_CONFIGMAP_CURRENCIES_OVERRIDE="${HEX_CONFIGMAP_CURRENCIES},${COIN_SYMBOL}"
          sed -i.bak "s/$HEX_CONFIGMAP_CURRENCIES/$HEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
          rm $CONFIGMAP_FILE_PATH.bak
      fi

      done

      echo "Allowing exchange external connections"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    else

      echo "Failed to remove existing coin $COIN_SYMBOL! Please try again.***"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL

      echo "Allowing exchange external connections"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml
      
    fi

    elif [[ ! "$USE_KUBERNETES" ]]; then


      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"
          
      # Overriding container prefix for develop server
      if [[ "$IS_DEVELOP" ]]; then
        
        CONTAINER_PREFIX=

      fi

      echo "Shutting down Nginx to block exchange external access"
      docker stop $(docker ps | grep $ENVIRONMENT_EXCHANGE_NAME-nginx | cut -f1 -d " ")

      echo "Adding new coin $COIN_SYMBOL on local exchange"
      if command docker exec --env "COIN_FULLNAME=${COIN_FULLNAME}" \
                  --env "COIN_SYMBOL=${COIN_SYMBOL}" \
                  --env "COIN_ALLOW_DEPOSIT=${COIN_ALLOW_DEPOSIT}" \
                  --env "COIN_ALLOW_WITHDRAWAL=${COIN_ALLOW_WITHDRAWAL}" \
                  --env "COIN_WITHDRAWAL_FEE=${COIN_WITHDRAWAL_FEE}" \
                  --env "COIN_MIN=${COIN_MIN}" \
                  --env "COIN_MAX=${COIN_MAX}" \
                  --env "COIN_INCREMENT_UNIT=${COIN_INCREMENT_UNIT}" \
                  --env "COIN_DEPOSIT_LIMITS=${COIN_DEPOSIT_LIMITS}" \
                  --env "COIN_WITHDRAWAL_LIMITS=${COIN_WITHDRAWAL_LIMITS}" \
                  --env "COIN_ACTIVE=${COIN_ACTIVE}"  \
                  ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                  node tools/dbs/addCoin.js; then

        echo "Running database triggers"
        docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js

        if  [[ "$IS_DEVELOP" ]]; then

          # Restarting containers after database init jobs.
          echo "Restarting containers to apply database changes."
          docker-compose -f $HEX_CODEBASE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

        else

          # Restarting containers after database init jobs.
          echo "Restarting containers to apply database changes."
          docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

        fi

        echo "Updating settings file to add new $COIN_SYMBOL."
        for i in ${CONFIG_FILE_PATH[@]}; do

        if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
            CONFIGMAP_FILE_PATH=$i
            HEX_CONFIGMAP_CURRENCIES_OVERRIDE="${HEX_CONFIGMAP_CURRENCIES},${COIN_SYMBOL}"
            sed -i.bak "s/$HEX_CONFIGMAP_CURRENCIES/$HEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
            rm $CONFIGMAP_FILE_PATH.bak
        fi

        done

      else

        echo "Failed to add new coin $COIN_SYMBOL on local exchange. Please confirm your input values and try again."

        if  [[ "$IS_DEVELOP" ]]; then

          # Restarting containers after database init jobs.
          echo "Restarting containers to apply database changes."
          docker-compose -f $HEX_CODEBASE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

        else

          # Restarting containers after database init jobs.
          echo "Restarting containers to apply database changes."
          docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

        fi

        exit 1;

      fi
      
  fi

}

function remove_coin_input() {

  echo "Coin Symbol: "
  read answer

  COIN_SYMBOL=$answer

  if [[ -z "$answer" ]]; then

    echo "Your value is empty. Please confirm your input and run the command again."
    exit 1;
  
  fi
  
  echo "*********************************************"
  echo "Symbol: $COIN_SYMBOL"
  echo "*********************************************"

  echo "Are the sure you want to remove this coin from your exchange? (y/N)"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "You chose false. Please confirm the values and run the command again."
    exit 1;
  
  fi

}

function remove_coin_exec() {

  if [[ "$USE_KUBERNETES" ]]; then

  echo "Blocking exchange external connections"
  kubectl delete -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

  echo "Removing existing coin $COIN_SYMBOL on Kubernetes"
    
    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set job.enable="true" \
                --set job.mode="remove_coin" \
                --set job.env.coin_symbol="$COIN_SYMBOL" \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_DOCKER_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_DOCKER_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hex.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server/values.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server; then

      echo "Kubernetes Job has been created for removing existing coin $COIN_SYMBOL."

      echo "Waiting until Job get completely run"
      sleep 30;

    else 

      echo "Failed to create Kubernetes Job for removing existing coin $COIN_SYMBOL, Please confirm your input values and try again."
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL

      echo "Allowing exchange external connections"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL \
            --namespace $ENVIRONMENT_EXCHANGE_NAME \
            -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Coin $COIN_SYMBOL has been successfully removed on your exchange!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL
      
      echo "Restarting containers..."
      kubectl delete pods --namespace $ENVIRONMENT_EXCHANGE_NAME -l role=$ENVIRONMENT_EXCHANGE_NAME

      echo "Removing created Kubernetes Job for removing existing coin..."
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL

      echo "Updating settings file to remove $COIN_SYMBOL."
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          if [[ "$COIN_SYMBOL" == "hex" ]]; then
            HEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HEX_CONFIGMAP_CURRENCIES//$COIN_SYMBOL,}")
          else
            HEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HEX_CONFIGMAP_CURRENCIES//,$COIN_SYMBOL}")
          fi
          sed -i.bak "s/$HEX_CONFIGMAP_CURRENCIES/$HEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
          rm $CONFIGMAP_FILE_PATH.bak
      fi

      done

      echo "Allowing exchange external connections"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    else

      echo "Failed to remove existing coin $COIN_SYMBOL! Please try again.***"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL

      echo "Allowing exchange external connections"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml
      
    fi

  elif [[ ! "$USE_KUBERNETES" ]]; then

      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

      # Overriding container prefix for develop server
      if [[ "$IS_DEVELOP" ]]; then
        
        CONTAINER_PREFIX=

      fi

      echo "Shutting down Nginx to block exchange external access"
      docker stop $(docker ps -a | grep $ENVIRONMENT_EXCHANGE_NAME-nginx | cut -f1 -d " ")

      echo "Removing new coin $COIN_SYMBOL on local docker"
      if command docker exec --env "COIN_SYMBOL=${COIN_SYMBOL}" \
                  ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                  node tools/dbs/removeCoin.js; then

      # Running database triggers
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js;


      if  [[ "$IS_DEVELOP" ]]; then

        # Restarting containers after database init jobs.
        echo "Restarting containers to apply database changes."
        docker-compose -f $HEX_CODEBASE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

      else

        # Restarting containers after database init jobs.
        echo "Restarting containers to apply database changes."
        docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

      fi

      echo "Updating settings file to remove $COIN_SYMBOL."
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          IFS="," read -ra CURRENCIES_TO_ARRAY <<< "${HEX_CONFIGMAP_CURRENCIES}"
          local REVOME_SELECTED_CURRENCY=${CURRENCIES_TO_ARRAY[@]/$COIN_SYMBOL}
          local CURRENCIES_ARRAY_TO_STRING=$(echo ${REVOME_SELECTED_CURRENCY[@]} | tr -d ' ') 
          local CURRENCIES_STRING_TO_COMMNA_SEPARATED=${CURRENCIES_ARRAY_TO_STRING// /,}

          sed -i.bak "s/$HEX_CONFIGMAP_CURRENCIES/$CURRENCIES_STRING_TO_COMMNA_SEPARATED/" $CONFIGMAP_FILE_PATH

          export HEX_CONFIGMAP_CURRENCIES=$CURRENCIES_STRING_TO_COMMNA_SEPARATED

          rm $CONFIGMAP_FILE_PATH.bak
      fi

      done

      else

        echo "Failed to remove coin $COIN_SYMBOL on local exchange. Please confirm your input values and try again."
        exit 1;

        if  [[ "$IS_DEVELOP" ]]; then

          # Restarting containers after database init jobs.
          echo "Restarting containers to apply database changes."
          docker-compose -f $HEX_CODEBASE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

        else

          # Restarting containers after database init jobs.
          echo "Restarting containers to apply database changes."
          docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

        fi

      fi

  fi

}

function add_pair_input() {

  echo "Name of new Trading Pair : (eth-usdt)"
  read answer

  PAIR_NAME=${answer:-eth-usdt}
  PAIR_BASE=$(echo $PAIR_NAME | cut -f1 -d '-')
  PAIR_2=$(echo $PAIR_NAME | cut -f2 -d '-')

  # Checking user level setup on settings file is set or not
  if [[ ! "$HEX_CONFIGMAP_USER_LEVEL_NUMBER" ]]; then

    echo "Warning: Settings value - HEX_CONFIGMAP_USER_LEVEL_NUMBER is not configured. Please confirm your settings files."
    exit 1;

  fi

  # Side-by-side printer 
  function print_taker_fees_array_side_by_side() { #LEVEL FRIST, VALUE NEXT.
    for ((i=0; i<=${#RANGE_TAKER_FEES_LEVEL[@]}; i++)); do
    printf '%s %s\n' "${RANGE_TAKER_FEES_LEVEL[i]}" "${VALUE_TAKER_FEES_LEVEL[i]}"
    done
  }

  # Side-by-side printer 
  function print_maker_fees_array_side_by_side() { #LEVEL FRIST, VALUE NEXT.
    for ((i=0; i<=${#RANGE_MAKER_FEES_LEVEL[@]}; i++)); do
    printf '%s %s\n' "${RANGE_MAKER_FEES_LEVEL[i]}" "${VALUE_MAKER_FEES_LEVEL[i]}"
    done
  }

  # Asking deposit limit of new coin per level
  for i in $(seq 1 $HEX_CONFIGMAP_USER_LEVEL_NUMBER);

    do echo "Taker fee of user level $i?" && read answer && export TAKER_FEES_LEVEL_$i=$answer
  
  done;

  local PARSE_RANGE_TAKER_FEES_LEVEL=$(set -o posix ; set | grep "TAKER_FEES_LEVEL_" | cut -c18 )
  local PARSE_VALUE_TAKER_FEES_LEVEL=$(set -o posix ; set | grep "TAKER_FEES_LEVEL_" | cut -f2 -d "=" )

  read -ra RANGE_TAKER_FEES_LEVEL <<< ${PARSE_RANGE_TAKER_FEES_LEVEL[@]}
  read -ra VALUE_TAKER_FEES_LEVEL <<< ${PARSE_VALUE_TAKER_FEES_LEVEL[@]}

  TAKER_FEES=$(join_array_to_json $(print_taker_fees_array_side_by_side))

  # Asking withdrawal limit of new coin per level
  for i in $(seq 1 $HEX_CONFIGMAP_USER_LEVEL_NUMBER);

    do echo "Maker fee of user level $i?" && read answer && export MAKER_FEES_LEVEL_$i=$answer
  
  done;

  local PARSE_RANGE_MAKER_FEES_LEVEL=$(set -o posix ; set | grep "MAKER_FEES_LEVEL_" | cut -c18 )
  local PARSE_VALUE_MAKER_FEES_LEVEL=$(set -o posix ; set | grep "MAKER_FEES_LEVEL_" | cut -f2 -d "=" )

  read -ra RANGE_MAKER_FEES_LEVEL <<< ${PARSE_RANGE_MAKER_FEES_LEVEL[@]}
  read -ra VALUE_MAKER_FEES_LEVEL <<< ${PARSE_VALUE_MAKER_FEES_LEVEL[@]}

  MAKER_FEES=$(join_array_to_json $(print_maker_fees_array_side_by_side))

  echo "Minimum Size: (0.001)"
  read answer

  MIN_SIZE=${answer:-0.001}

  echo "Maximum Size: (20000000)"
  read answer

  MAX_SIZE=${answer:-20000000}

  echo "Minimum Price: (0.0001)"
  read answer

  MIN_PRICE=${answer:-0.0001}

  echo "Maximum Price: (10)"
  read answer

  MAX_PRICE=${answer:-10}

  echo "Increment Size: (0.001)"
  read answer

  INCREMENT_SIZE=${answer:-0.001}

  echo "Increment Price: (1)"
  read answer

  INCREMENT_PRICE=${answer:-1}

  echo "Activate: (Y/n) [Default: y]"
  read answer
  
  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    PAIR_ACTIVE=false
  
  else

    PAIR_ACTIVE=true

  fi

  function print_taker_fees_deposit_level(){ 

    for i in $(set -o posix ; set | grep "TAKER_FEES_LEVEL_");

      do echo -e "$i"

    done;

  }

  function print_maker_fees_withdrawal_level(){ 

    for i in $(set -o posix ; set | grep "MAKER_FEES_LEVEL_");

      do echo -e "$i"

    done;

  }
  
  echo "*********************************************"
  echo "Full name: $PAIR_NAME"
  echo "First currency: $PAIR_BASE"
  echo "Second currency: $PAIR_2"
  echo "Taker fees per level: $TAKER_FEES"
  echo "Maker limits per level: $MAKER_FEES"
  echo "Minimum size: $MIN_SIZE"
  echo "Maximum size: $MAX_SIZE"
  echo "Minimum price: $MIN_PRICE"
  echo "Maximum price: $MAX_PRICE"
  echo "Increment size: $INCREMENT_SIZE"
  echo "Increment price: $INCREMENT_PRICE"
  echo "Activation: $PAIR_ACTIVE"
  echo "*********************************************"

  echo "Are the values are all correct? (y/N)"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "You chose false. Please confirm the values and re-run the command."
    exit 1;
  
  fi

}


function add_pair_exec() {

  if [[ "$USE_KUBERNETES" ]]; then

    function generate_kubernetes_add_pair_values() {

    # Generate Kubernetes Configmap
    cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/add-pair.yaml <<EOL
job:
  enable: true
  mode: add_pair
  env:
    pair_name: ${PAIR_NAME}
    pair_base: ${PAIR_BASE}
    pair_2: ${PAIR_2}
    taker_fees: '${TAKER_FEES}'
    maker_fees: '${MAKER_FEES}'
    min_size: ${MIN_SIZE}
    max_size: ${MAX_SIZE}
    min_price: ${MIN_PRICE}
    max_price: ${MAX_PRICE}
    increment_size: ${INCREMENT_SIZE}
    increment_price: ${INCREMENT_PRICE}
    pair_active: ${PAIR_ACTIVE}
EOL

      }

    generate_kubernetes_add_pair_values;

    echo "Blocking exchange external connections"
    kubectl delete -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    echo "Adding new pair $PAIR_NAME on Kubernetes"
    
    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set job.enable="true" \
                --set job.mode="add_pair" \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_DOCKER_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_DOCKER_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hex.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server/values.yaml \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/add-pair.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server; then

      echo "Kubernetes Job has been created for adding new pair $PAIR_NAME."

      echo "Waiting until Job get completely run"
      sleep 30;

    else 

      echo "Failed to create Kubernetes Job for adding new pair $PAIR_NAME, Please confirm your input values and try again."
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME

      echo "Allowing exchange external connections"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME \
            --namespace $ENVIRONMENT_EXCHANGE_NAME \
            -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Pair $PAIR_NAME has been successfully added on your exchange!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME

      echo "Updating settings file to add new $PAIR_NAME."
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          HEX_CONFIGMAP_PAIRS_OVERRIDE="${HEX_CONFIGMAP_PAIRS},${PAIR_NAME}"
          sed -i.bak "s/$HEX_CONFIGMAP_PAIRS/$HEX_CONFIGMAP_PAIRS_OVERRIDE/" $CONFIGMAP_FILE_PATH
          rm $CONFIGMAP_FILE_PATH.bak
      fi

      done

      # Reading variable again
      for i in ${CONFIG_FILE_PATH[@]}; do
        source $i
      done;
      
      source $SCRIPTPATH/tools_generator.sh
      load_config_variables;
      
      echo "Upgrading exchange with latest settings..."
      hex upgrade --kube --no_verify

      echo "Removing created Kubernetes Job for adding new coin..."
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME

    else

      echo "Failed to add new pair $PAIR_NAME! Please try again.***"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME

      echo "Allowing exchange external connections"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml
      
    fi

  elif [[ ! "$USE_KUBERNETES" ]]; then

      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"
          
      # Overriding container prefix for develop server
      if [[ "$IS_DEVELOP" ]]; then
        
        CONTAINER_PREFIX=

      fi

      echo "Shutting down Nginx to block exchange external access"
      docker stop $(docker ps | grep $ENVIRONMENT_EXCHANGE_NAME-nginx | cut -f1 -d " ")

      echo "Adding new pair $PAIR_NAME on local exchange"
      if command docker exec --env "PAIR_NAME=${PAIR_NAME}" \
                  --env "PAIR_BASE=${PAIR_BASE}" \
                  --env "PAIR_2=${PAIR_2}" \
                  --env "TAKER_FEES=${TAKER_FEES}" \
                  --env "MAKER_FEES=${MAKER_FEES}" \
                  --env "MIN_SIZE=${MIN_SIZE}" \
                  --env "MAX_SIZE=${MAX_SIZE}" \
                  --env "MIN_PRICE=${MIN_PRICE}" \
                  --env "MAX_PRICE=${MAX_PRICE}" \
                  --env "INCREMENT_SIZE=${INCREMENT_SIZE}" \
                  --env "INCREMENT_PRICE=${INCREMENT_PRICE}"  \
                  --env "PAIR_ACTIVE=${PAIR_ACTIVE}" \
                  ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                  node tools/dbs/addPair.js; then

           # Running database triggers
          docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js;

          echo "Updating settings file to add new $PAIR_NAME."
          for i in ${CONFIG_FILE_PATH[@]}; do

          if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
              CONFIGMAP_FILE_PATH=$i
              HEX_CONFIGMAP_PAIRS_OVERRIDE="${HEX_CONFIGMAP_PAIRS},${PAIR_NAME}"
              sed -i.bak "s/$HEX_CONFIGMAP_PAIRS/$HEX_CONFIGMAP_PAIRS_OVERRIDE/" $CONFIGMAP_FILE_PATH
              export HEX_CONFIGMAP_PAIRS="$HEX_CONFIGMAP_PAIRS_OVERRIDE"
              rm $CONFIGMAP_FILE_PATH.bak
          fi

          done

          if  [[ "$IS_DEVELOP" ]]; then

            # Restarting containers after database init jobs.
            echo "Restarting containers to apply database changes."
            docker-compose -f $HEX_CODEBASE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart
            generate_local_docker_compose;
            docker-compose -f $HEX_CODEBASE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d

          else

            # Restarting containers after database init jobs.
            echo "Restarting containers to apply database changes."
            docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart
            generate_local_docker_compose;
            docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d

          fi

      else

        echo "Failed to add new pair $PAIR_NAME on local exchange. Please confirm your input values and try again."

        if  [[ "$IS_DEVELOP" ]]; then

          # Restarting containers after database init jobs.
          echo "Restarting containers to apply database changes."
          docker-compose -f $HEX_CODEBASE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

        else

          # Restarting containers after database init jobs.
          echo "Restarting containers to apply database changes."
          docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

        fi

        exit 1;

      fi

  fi

}

function remove_pair_input() {

  echo "Pair name to remove: "
  read answer

  PAIR_NAME=$answer

  if [[ -z "$answer" ]]; then

    echo "Your value is empty. Please confirm your input and run the command again."
    exit 1;
  
  fi
  
  echo "*********************************************"
  echo "Name: $PAIR_NAME"
  echo "*********************************************"

  echo "Are the sure you want to remove this trading pair from your exchange? (y/N)"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "You chose false. Please confirm the values and run the command again."
    exit 1;
  
  fi

}

function remove_pair_exec() {

  if [[ "$USE_KUBERNETES" ]]; then

    echo "Blocking exchange external connections"
    kubectl delete -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml


    echo "*** Removing existing pair $PAIR_NAME on Kubernetes ***"
      
    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set job.enable="true" \
                --set job.mode="remove_pair" \
                --set job.env.pair_name="$PAIR_NAME" \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_DOCKER_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_DOCKER_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hex.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server/values.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server; then

      echo "*** Kubernetes Job has been created for removing existing pair $PAIR_NAME. ***"

      echo "*** Waiting until Job get completely run ***"
      sleep 30;

    else 

      echo "*** Failed to create Kubernetes Job for removing existing pair $PAIR_NAME, Please confirm your input values and try again. ***"
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME

      echo "Allowing exchange external connections"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME \
            --namespace $ENVIRONMENT_EXCHANGE_NAME \
            -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "*** Pair $PAIR_NAME has been successfully removed on your exchange! ***"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME

      echo "*** Removing existing $PAIR_NAME container from Kubernetes ***"
      PAIR_BASE=$(echo $PAIR_NAME | cut -f1 -d '-')
      PAIR_2=$(echo $PAIR_NAME | cut -f2 -d '-')

      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-server-queue-$PAIR_BASE$PAIR_2

      echo "*** Restarting containers... ***"
      kubectl delete pods --namespace $ENVIRONMENT_EXCHANGE_NAME -l role=$ENVIRONMENT_EXCHANGE_NAME

      echo "*** Removing created Kubernetes Job for removing existing pair... ***"
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME

      echo "*** Updating settings file to remove existing $PAIR_NAME. ***"
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          if [[ "$PAIR_NAME" == "hex-usdt" ]]; then
              HEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HEX_CONFIGMAP_PAIRS//$PAIR_NAME,}")
            else
              HEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HEX_CONFIGMAP_PAIRS//,$PAIR_NAME}")
          fi
          sed -i.bak "s/$HEX_CONFIGMAP_PAIRS/$HEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
          rm $CONFIGMAP_FILE_PATH.bak
      fi

      done

      echo "Allowing exchange external connections"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    else

      echo "*** Failed to remove existing pair $PAIR_NAME! Please try again.***"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME

      echo "Allowing exchange external connections"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml
      
    fi

  elif [[ ! "$USE_KUBERNETES" ]]; then

      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

      # Overriding container prefix for develop server
      if [[ "$IS_DEVELOP" ]]; then
        
        CONTAINER_PREFIX=

      fi

      echo "Shutting down Nginx to block exchange external access"
      docker stop $(docker ps | grep $ENVIRONMENT_EXCHANGE_NAME-nginx | cut -f1 -d " ")

      echo "*** Removing new pair $PAIR_NAME on local exchange ***"
      if command docker exec --env "PAIR_NAME=${PAIR_NAME}" ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/removePair.js; then

        # Running database triggers
        docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js;

        echo "*** Updating settings file to remove existing $PAIR_NAME. ***"
        for i in ${CONFIG_FILE_PATH[@]}; do

        if command grep -q "HEX_CONFIGMAP_PAIRS" $i > /dev/null ; then
            CONFIGMAP_FILE_PATH=$i

            IFS="," read -ra PAIRS_TO_ARRAY <<< "${HEX_CONFIGMAP_PAIRS}"
            local REVOME_SELECTED_PAIR=${PAIRS_TO_ARRAY[@]/$PAIR_NAME}
            local PAIRS_ARRAY_TO_STRING=$(echo ${REVOME_SELECTED_PAIR[@]} | tr -d ' ') 
            local PAIRS_STRING_TO_COMMNA_SEPARATED=${PAIRS_ARRAY_TO_STRING// /,}

            sed -i.bak "s/$HEX_CONFIGMAP_PAIRS/$PAIRS_STRING_TO_COMMNA_SEPARATED/" $CONFIGMAP_FILE_PATH

            export HEX_CONFIGMAP_PAIRS=$PAIRS_STRING_TO_COMMNA_SEPARATED

            rm $CONFIGMAP_FILE_PATH.bak
        fi

        done


        if  [[ "$IS_DEVELOP" ]]; then

          # Restarting containers after database init jobs.
          echo "Restarting containers to apply database changes."
          docker-compose -f $HEX_CODEBASE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart
          generate_local_docker_compose;
          docker-compose -f $HEX_CODEBASE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d --remove-orphans

        else

          # Restarting containers after database init jobs.
          echo "Restarting containers to apply database changes."
          docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart
          generate_local_docker_compose;
          docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d --remove-orphans

        fi

      else

        echo "Failed to remove trading pair $PAIR_NAME on local exchange. Please confirm your input values and try again."

        if  [[ "$IS_DEVELOP" ]]; then

          # Restarting containers after database init jobs.
          echo "Restarting containers to apply database changes."
          docker-compose -f $HEX_CODEBASE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

        else

          # Restarting containers after database init jobs.
          echo "Restarting containers to apply database changes."
          docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

        fi
        
        exit 1;

      fi

  fi

}

function generate_hex_web_local_env() {

cat > $HEX_CLI_INIT_PATH/web/.env <<EOL

NODE_ENV=production

PUBLIC_URL=${HEX_CONFIGMAP_DOMAIN}
REACT_APP_PUBLIC_URL=${HEX_CONFIGMAP_DOMAIN}
REACT_APP_SERVER_ENDPOINT=${HEX_CONFIGMAP_API_HOST}
REACT_APP_NETWORK=${HEX_CONFIGMAP_NETWORK}

REACT_APP_EXCHANGE_NAME=${ENVIRONMENT_EXCHANGE_NAME}

REACT_APP_CAPTCHA_SITE_KEY=${ENVIRONMENT_WEB_CAPTCHA_SITE_KEY}

REACT_APP_DEFAULT_LANGUAGE=${ENVIRONMENT_WEB_DEFAULT_LANGUAGE}
REACT_APP_DEFAULT_COUNTRY=${ENVIRONMENT_WEB_DEFAULT_COUNTRY}

REACT_APP_BASE_CURRENCY=${ENVIRONMENT_WEB_BASE_CURRENCY}

EOL
}

function generate_hex_web_local_nginx_conf() {

cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/web.conf <<EOL
server_name hex.exchange; #Client domain
access_log   /var/log/nginx/web.access.log  main;
      
location / {
  proxy_pass      http://web;
}

EOL
}


function generate_hex_web_configmap() {

cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-web-configmap.yaml <<EOL
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-web-env
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
data:
  PUBLIC_URL: ${HEX_CONFIGMAP_DOMAIN}
  REACT_APP_PUBLIC_URL: https://${HEX_CONFIGMAP_API_HOST}
  REACT_APP_SERVER_ENDPOINT: https://${HEX_CONFIGMAP_API_HOST}

  REACT_APP_NETWORK: ${HEX_CONFIGMAP_NETWORK}

  REACT_APP_CAPTCHA_SITE_KEY: ${ENVIRONMENT_WEB_CAPTCHA_SITE_KEY}

  REACT_APP_DEFAULT_LANGUAGE: ${ENVIRONMENT_WEB_DEFAULT_LANGUAGE}
  REACT_APP_DEFAULT_COUNTRY: ${ENVIRONMENT_WEB_DEFAULT_COUNTRY}

  REACT_APP_BASE_CURRENCY: ${ENVIRONMENT_WEB_BASE_CURRENCY}
  
EOL
}


function launch_basic_settings_input() {

  /bin/cat << EOF
  
Please fill up the interaction form to launch your own exchange.

If you don't have activation code for HEX Core yet, We also provide trial license.
Please visit dash.bitholla.com to see more details.

For setting up the exchange name, You should only use alphanumeric. No space or special character allowed.

EOF

  # Exchange name (API_NAME)
  echo "Exchange name: ($HEX_CONFIGMAP_API_NAME)"
  read answer

  local PARSE_CHARACTERS_FOR_API_NAME=$(echo $answer | tr -dc '[:alnum:]' | tr -d ' ')
  local EXCHANGE_API_NAME_OVERRIDE=${PARSE_CHARACTERS_FOR_API_NAME:-$HEX_CONFIGMAP_API_NAME}
  local EXCHANGE_NAME_OVERRIDE=$(echo $EXCHANGE_API_NAME_OVERRIDE | tr '[:upper:]' '[:lower:]')

  # Activation Code
  echo "Activation Code: ($HEX_SECRET_ACTIVATION_CODE)"
  read answer

  local EXCHANGE_ACTIVATION_CODE_OVERRIDE=${answer:-$HEX_SECRET_ACTIVATION_CODE}

  # Web Domain
  echo "Exchange URL: ($HEX_CONFIGMAP_DOMAIN)"
  read answer

  local ESCAPED_HEX_CONFIGMAP_DOMAIN=${HEX_CONFIGMAP_DOMAIN//\//\\/}

  local ORIGINAL_CHARACTER_FOR_HEX_CONFIGMAP_DOMAIN="${answer:-$HEX_CONFIGMAP_DOMAIN}"
  local PARSE_CHARACTER_FOR_HEX_CONFIGMAP_DOMAIN=${ORIGINAL_CHARACTER_FOR_HEX_CONFIGMAP_DOMAIN//\//\\/}
  local EXCHANGE_WEB_DOMAIN_OVERRIDE="$PARSE_CHARACTER_FOR_HEX_CONFIGMAP_DOMAIN"

  # Light Logo Path
  echo "Exchange Light Logo Path: ($HEX_CONFIGMAP_LOGO_PATH)"
  echo "- Image always should be png"
  read answer

  local ESCAPED_HEX_CONFIGMAP_LOGO_PATH=${HEX_CONFIGMAP_LOGO_PATH//\//\\/}

  local ORIGINAL_CHARACTER_FOR_LOGO_PATH="${answer:-$HEX_CONFIGMAP_LOGO_PATH}"
  local PARSE_CHARACTER_FOR_LOGO_PATH=${ORIGINAL_CHARACTER_FOR_LOGO_PATH//\//\\/}
  local HEX_CONFIGMAP_LOGO_PATH_OVERRIDE="$PARSE_CHARACTER_FOR_LOGO_PATH"

  # Dark Logo Path
  echo "Exchange Dark Logo Path: ($HEX_CONFIGMAP_LOGO_BLACK_PATH)"
  echo "- Image always should be png"
  read answer

  local ESCAPED_HEX_CONFIGMAP_LOGO_BLACK_PATH=${HEX_CONFIGMAP_LOGO_BLACK_PATH//\//\\/}}

  local ORIGINAL_CHARACTER_FOR_LOGO_BLACK_PATH="${answer:-$HEX_CONFIGMAP_LOGO_BLACK_PATH}"
  local PARSE_CHARACTER_FOR_LOGO_BLACK_PATH=${ORIGINAL_CHARACTER_FOR_LOGO_BLACK_PATH//\//\\/}
  local HEX_CONFIGMAP_LOGO_BLACK_PATH_OVERRIDE="$PARSE_CHARACTER_FOR_LOGO_BLAKC_PATH"

  # WEB CAPTCHA SITE KEY
  echo "Exchange Web Google reCpatcha Sitekey: ($ENVIRONMENT_WEB_CAPTCHA_SITE_KEY)"
  read answer

  local ENVIRONMENT_WEB_CAPTCHA_SITE_KEY_OVERRIDE="${answer:-$ENVIRONMENT_WEB_CAPTCHA_SITE_KEY}"

  # Server CAPTCHA Secret key
  echo "Exchange API Server Google reCpatcha Secretkey: ($HEX_SECRET_CAPTCHA_SECRET_KEY)"
  read answer

  local HEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE="${answer:-$HEX_SECRET_CAPTCHA_SECRET_KEY}"

  # Web default country
  echo "Default Country: ($ENVIRONMENT_WEB_DEFAULT_COUNTRY)"
  read answer

  local ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE="${answer:-$ENVIRONMENT_WEB_DEFAULT_COUNTRY}"

  # Emails timezone
  echo "Timezone: ($HEX_CONFIGMAP_EMAILS_TIMEZONE)"
  read answer

  local ESCAPED_HEX_CONFIGMAP_EMAILS_TIMEZONE=${HEX_CONFIGMAP_EMAILS_TIMEZONE/\//\\/}

  local ORIGINAL_CHARACTER_FOR_TIMEZONE="${answer:-$HEX_CONFIGMAP_EMAILS_TIMEZONE}"
  local PARSE_CHARACTER_FOR_TIMEZONE=${ORIGINAL_CHARACTER_FOR_TIMEZONE/\//\\/}
  local HEX_CONFIGMAP_EMAILS_TIMEZONE_OVERRIDE="$PARSE_CHARACTER_FOR_TIMEZONE"

  # Valid languages
  echo "Valid Languages: ($HEX_CONFIGMAP_VALID_LANGUAGES)"
  echo "- Separate with comma (,)"
  read answer

  local HEX_CONFIGMAP_VALID_LANGUAGES_OVERRIDE="${answer:-$HEX_CONFIGMAP_VALID_LANGUAGES}"

  # Default language
  echo "Default Language: ($HEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE)"
  read answer

  local HEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE="${answer:-$HEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE}"

  # Default theme
  echo "Default Theme: ($HEX_CONFIGMAP_DEFAULT_THEME)"
  echo "- Between light and dark."
  read answer

  local HEX_CONFIGMAP_DEFAULT_THEME_OVERRIDE="${answer:-$HEX_CONFIGMAP_DEFAULT_THEME}"

  # API Domain
  echo "Exchange Server API URL: ($HEX_CONFIGMAP_API_HOST)"
  read answer

  local ESCAPED_HEX_CONFIGMAP_API_HOST=${HEX_CONFIGMAP_API_HOST//\//\\/}

  local ORIGINAL_CHARACTER_FOR_HEX_CONFIGMAP_API_HOST="${answer:-$HEX_CONFIGMAP_API_HOST}"
  local PARSE_CHARACTER_FOR_HEX_CONFIGMAP_API_HOST=${ORIGINAL_CHARACTER_FOR_HEX_CONFIGMAP_API_HOST//\//\\/}
  local EXCHANGE_SERVER_DOMAIN_OVERRIDE="$PARSE_CHARACTER_FOR_HEX_CONFIGMAP_API_HOST"

  # User tier number
  echo "Number of User Tiers: ($HEX_CONFIGMAP_USER_LEVEL_NUMBER)"
  read answer

  local EXCHANGE_USER_LEVEL_NUMBER_OVERRIDE=${answer:-$HEX_CONFIGMAP_USER_LEVEL_NUMBER}

  # Admin Email
  echo "Admin Email: ($HEX_CONFIGMAP_ADMIN_EMAIL)"
  read answer

  local HEX_CONFIGMAP_ADMIN_EMAIL_OVERRIDE=${answer:-$HEX_CONFIGMAP_ADMIN_EMAIL}

  # Admin Password
  echo "Admin Password: ($HEX_SECRET_ADMIN_PASSWORD)"
  read answer

  local HEX_SECRET_ADMIN_PASSWORD_OVERRIDE=${answer:-$HEX_SECRET_ADMIN_PASSWORD}

  # Supervisor Email
  echo "Supervisor Email: ($HEX_CONFIGMAP_SUPERVISOR_EMAIL)"
  read answer

  local HEX_CONFIGMAP_SUPERVISOR_EMAIL_OVERRIDE=${answer:-$HEX_CONFIGMAP_SUPERVISOR_EMAIL}

  # KYC email
  echo "KYC Email: ($HEX_CONFIGMAP_KYC_EMAIL)"
  read answer

  local HEX_CONFIGMAP_KYC_EMAIL_OVERRIDE=${answer:-$HEX_CONFIGMAP_KYC_EMAIL}

  # Support Email
  echo "Support Email: ($HEX_CONFIGMAP_SUPPORT_EMAIL)"
  read answer

  local HEX_CONFIGMAP_SUPPORT_EMAIL_OVERRIDE=${answer:-$HEX_CONFIGMAP_SUPPORT_EMAIL}

  # Sender Email
  echo "Sender Email: ($HEX_CONFIGMAP_SENDER_EMAIL)"
  read answer

  local HEX_CONFIGMAP_SENDER_EMAIL_OVERRIDE=${answer:-$HEX_CONFIGMAP_SENDER_EMAIL}

  # New user is activated
  echo "Allow New User Signup?: (Y/n)"
  read answer

  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    HEX_CONFIGMAP_NEW_USER_IS_ACTIVATED_OVERRIDE=false
  
  else

    HEX_CONFIGMAP_NEW_USER_IS_ACTIVATED_OVERRIDE=true

  fi

  /bin/cat << EOF
  
*********************************************
Exchange Name: $EXCHANGE_API_NAME_OVERRIDE
Activation Code: $EXCHANGE_ACTIVATION_CODE_OVERRIDE

Exchange URL: $ORIGINAL_CHARACTER_FOR_HEX_CONFIGMAP_DOMAIN

Light Logo Path: $ORIGINAL_CHARACTER_FOR_LOGO_PATH
Dark Logo Path: $ORIGINAL_CHARACTER_FOR_LOGO_BLACK_PATH

Web Captcha Sitekey: $ENVIRONMENT_WEB_CAPTCHA_SITE_KEY_OVERRIDE
Server Captcha Secretkey: $HEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE

Default Country: $ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE
Timezone: $ORIGINAL_CHARACTER_FOR_TIMEZONE
Valid Languages: $HEX_CONFIGMAP_VALID_LANGUAGES_OVERRIDE
Default Language: $HEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE
Default Theme: $HEX_CONFIGMAP_DEFAULT_THEME_OVERRIDE

Exchange API URL: $ORIGINAL_CHARACTER_FOR_HEX_CONFIGMAP_API_HOST

User Tiers: $EXCHANGE_USER_LEVEL_NUMBER_OVERRIDE

Admin Email: $HEX_CONFIGMAP_ADMIN_EMAIL_OVERRIDE
Admin Password: $HEX_SECRET_ADMIN_PASSWORD_OVERRIDE
Supervisor Email: $HEX_CONFIGMAP_SUPERVISOR_EMAIL_OVERRIDE
KYC Email: $HEX_CONFIGMAP_KYC_EMAIL_OVERRIDE
Support Email: $HEX_CONFIGMAP_SUPPORT_EMAIL_OVERRIDE
Sender Email: $HEX_CONFIGMAP_SENDER_EMAIL_OVERRIDE

Allow New User Signup: $HEX_CONFIGMAP_NEW_USER_IS_ACTIVATED_OVERRIDE
*********************************************

EOF

  echo "Are the values are all correct? (Y/n)"
  read answer

  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    echo "You chose false. Please confirm the values and re-run the command."
    exit 1;
  
  fi

  echo "Provided values would be updated on your settings files automatically."

  for i in ${CONFIG_FILE_PATH[@]}; do

    # Update exchange name
    if command grep -q "ENVIRONMENT_EXCHANGE_NAME" $i > /dev/null ; then
    CONFIGMAP_FILE_PATH=$i
    sed -i.bak "s/ENVIRONMENT_EXCHANGE_NAME=$ENVIRONMENT_EXCHANGE_NAME/ENVIRONMENT_EXCHANGE_NAME=$EXCHANGE_NAME_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HEX_CONFIGMAP_API_NAME=$HEX_CONFIGMAP_API_NAME/HEX_CONFIGMAP_API_NAME=$EXCHANGE_API_NAME_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HEX_CONFIGMAP_DOMAIN=.*/HEX_CONFIGMAP_DOMAIN=$EXCHANGE_WEB_DOMAIN_OVERRIDE/" $CONFIGMAP_FILE_PATH

    sed -i.bak "s/ESCAPED_HEX_CONFIGMAP_LOGO_PATH=.*/ESCAPED_HEX_CONFIGMAP_LOGO_PATH=$HEX_CONFIGMAP_LOGO_PATH_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/ESCAPED_HEX_CONFIGMAP_LOGO_BLACK_PATH=.*/ESCAPED_HEX_CONFIGMAP_LOGO_BLACK_PATH=$HEX_CONFIGMAP_LOGO_BLACK_PATH_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/ENVIRONMENT_WEB_CAPTCHA_SITE_KEY=$ENVIRONMENT_WEB_CAPTCHA_SITE_KEY/ENVIRONMENT_WEB_CAPTCHA_SITE_KEY=$ENVIRONMENT_WEB_CAPTCHA_SITE_KEY_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/ENVIRONMENT_WEB_DEFAULT_COUNTRY=$ENVIRONMENT_WEB_DEFAULT_COUNTRY/ENVIRONMENT_WEB_DEFAULT_COUNTRY=$ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HEX_CONFIGMAP_EMAILS_TIMEZONE=.*/HEX_CONFIGMAP_EMAILS_TIMEZONE=$HEX_CONFIGMAP_EMAILS_TIMEZONE_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HEX_CONFIGMAP_VALID_LANGUAGES=$HEX_CONFIGMAP_VALID_LANGUAGES/HEX_CONFIGMAP_VALID_LANGUAGES=$HEX_CONFIGMAP_VALID_LANGUAGES_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/ENVIRONMENT_WEB_DEFAULT_LANGUAGE=$ENVIRONMENT_WEB_DEFAULT_LANGUAGE/ENVIRONMENT_WEB_DEFAULT_LANGUAGE=$HEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE=$HEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE/HEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE=$HEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HEX_CONFIGMAP_DEFAULT_THEME=$HEX_CONFIGMAP_DEFAULT_THEME/HEX_CONFIGMAP_DEFAULT_THEME=$HEX_CONFIGMAP_DEFAULT_THEME_OVERRIDE/" $CONFIGMAP_FILE_PATH

    sed -i.bak "s/HEX_CONFIGMAP_API_HOST=.*/HEX_CONFIGMAP_API_HOST=$EXCHANGE_SERVER_DOMAIN_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HEX_CONFIGMAP_USER_LEVEL_NUMBER=$HEX_CONFIGMAP_USER_LEVEL_NUMBER/HEX_CONFIGMAP_USER_LEVEL_NUMBER=$EXCHANGE_USER_LEVEL_NUMBER_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HEX_CONFIGMAP_ADMIN_EMAIL=$HEX_CONFIGMAP_ADMIN_EMAIL/HEX_CONFIGMAP_ADMIN_EMAIL=$HEX_CONFIGMAP_ADMIN_EMAIL_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HEX_CONFIGMAP_SUPERVISOR_EMAIL=$HEX_CONFIGMAP_SUPERVISOR_EMAIL/HEX_CONFIGMAP_SUPERVISOR_EMAIL=$HEX_CONFIGMAP_SUPERVISOR_EMAIL_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HEX_CONFIGMAP_KYC_EMAIL=$HEX_CONFIGMAP_KYC_EMAIL/HEX_CONFIGMAP_KYC_EMAIL=$HEX_CONFIGMAP_KYC_EMAIL_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HEX_CONFIGMAP_SUPPORT_EMAIL=$HEX_CONFIGMAP_SUPPORT_EMAIL/HEX_CONFIGMAP_SUPPORT_EMAIL=$HEX_CONFIGMAP_SUPPORT_EMAIL_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HEX_CONFIGMAP_SENDER_EMAIL=$HEX_CONFIGMAP_SENDER_EMAIL/HEX_CONFIGMAP_SENDER_EMAIL=$HEX_CONFIGMAP_SENDER_EMAIL_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HEX_CONFIGMAP_NEW_USER_IS_ACTIVATED=$HEX_CONFIGMAP_NEW_USER_IS_ACTIVATED/HEX_CONFIGMAP_NEW_USER_IS_ACTIVATED=$HEX_CONFIGMAP_NEW_USER_IS_ACTIVATED_OVERRIDE/" $CONFIGMAP_FILE_PATH
    rm $CONFIGMAP_FILE_PATH.bak
    fi

    # Update activation code
    if command grep -q "HEX_SECRET_ACTIVATION_CODE" $i > /dev/null ; then
    SECRET_FILE_PATH=$i
    sed -i.bak "s/HEX_SECRET_ACTIVATION_CODE=$HEX_SECRET_ACTIVATION_CODE/HEX_SECRET_ACTIVATION_CODE=$EXCHANGE_ACTIVATION_CODE_OVERRIDE/" $SECRET_FILE_PATH
    sed -i.bak "s/HEX_SECRET_CAPTCHA_SECRET_KEY=$HEX_SECRET_CAPTCHA_SECRET_KEY/HEX_SECRET_CAPTCHA_SECRET_KEY=$HEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE/" $SECRET_FILE_PATH
    sed -i.bak "s/HEX_SECRET_ADMIN_PASSWORD=$HEX_SECRET_ADMIN_PASSWORD/HEX_SECRET_ADMIN_PASSWORD=$HEX_SECRET_ADMIN_PASSWORD_OVERRIDE/" $SECRET_FILE_PATH
    rm $SECRET_FILE_PATH.bak
    fi
      
  done

  export ENVIRONMENT_EXCHANGE_NAME=$EXCHANGE_NAME_OVERRIDE
  export HEX_CONFIGMAP_API_NAME=$EXCHANGE_API_NAME_OVERRIDE
  export HEX_SECRET_ACTIVATION_CODE=$EXCHANGE_ACTIVATION_CODE_OVERRIDE

  export HEX_CONFIGMAP_DOMAIN=$ORIGINAL_CHARACTER_FOR_HEX_CONFIGMAP_DOMAIN

  export HEX_CONFIGMAP_LOGO_PATH="$HEX_CONFIGMAP_LOGO_PATH_OVERRIDE"
  export HEX_CONFIGMAP_LOGO_BLACK_PATH="$HEX_CONFIGMAP_LOGO_BLACK_PATH_OVERRIDE"

  export ENVIRONMENT_WEB_CAPTCHA_SITE_KEY=$ENVIRONMENT_WEB_CAPTCHA_SITE_KEY_OVERRIDE
  export HEX_SECRET_CAPTCHA_SECRET_KEY=$HEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE

  export ENVIRONMENT_WEB_DEFAULT_COUNTRY=$ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE
  export HEX_CONFIGMAP_EMAILS_TIMEZONE=$ORIGINAL_CHARACTER_FOR_TIMEZONE
  export HEX_CONFIGMAP_VALID_LANGUAGES=$HEX_CONFIGMAP_VALID_LANGUAGES_OVERRIDE
  export HEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE=$HEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE
  export ENVIRONMENT_WEB_DEFAULT_LANGUAGE=$HEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE
  export HEX_CONFIGMAP_DEFAULT_THEME=$HEX_CONFIGMAP_DEFAULT_THEME_OVERRIDE

  export HEX_CONFIGMAP_API_HOST=$ORIGINAL_CHARACTER_FOR_HEX_CONFIGMAP_API_HOST
  export HEX_CONFIGMAP_USER_LEVEL_NUMBER=$EXCHANGE_USER_LEVEL_NUMBER_OVERRIDE

  export HEX_CONFIGMAP_ADMIN_EMAIL=$HEX_CONFIGMAP_ADMIN_EMAIL_OVERRIDE
  export HEX_SECRET_ADMIN_PASSWORD=$HEX_SECRET_ADMIN_PASSWORD_OVERRIDE
  export HEX_CONFIGMAP_SUPERVISOR_EMAIL=$HEX_CONFIGMAP_SUPERVISOR_EMAIL_OVERRIDE
  export HEX_CONFIGMAP_KYC_EMAIL=$HEX_CONFIGMAP_KYC_EMAIL_OVERRIDE
  export HEX_CONFIGMAP_SUPPORT_EMAIL=$HEX_CONFIGMAP_SUPPORT_EMAIL_OVERRIDE
  export HEX_CONFIGMAP_SENDER_EMAIL=$HEX_CONFIGMAP_SENDER_EMAIL_OVERRIDE

}

function basic_settings_for_web_client_input() {

  /bin/cat << EOF
  
Please fill up the interaction form to setup your Web Client.

Make sure to you already setup HEX exchange first before setup the web client.
Web client relies on HEX exchange to function.

Please visit docs.bitholla.com to see the details or need any help.

EOF
  # Web Domain
  echo "Exchange URL: ($HEX_CONFIGMAP_DOMAIN)"
  read answer

  local ESCAPED_HEX_CONFIGMAP_DOMAIN=${HEX_CONFIGMAP_DOMAIN//\//\\/}

  local ORIGINAL_CHARACTER_FOR_HEX_CONFIGMAP_DOMAIN="${answer:-$HEX_CONFIGMAP_DOMAIN}"
  local PARSE_CHARACTER_FOR_HEX_CONFIGMAP_DOMAIN=${ORIGINAL_CHARACTER_FOR_HEX_CONFIGMAP_DOMAIN//\//\\/}
  local EXCHANGE_WEB_DOMAIN_OVERRIDE="$PARSE_CHARACTER_FOR_HEX_CONFIGMAP_DOMAIN"

  # WEB CAPTCHA SITE KEY
  echo "Exchange Web Google reCpatcha Sitekey: ($ENVIRONMENT_WEB_CAPTCHA_SITE_KEY)"
  read answer

  local ENVIRONMENT_WEB_CAPTCHA_SITE_KEY_OVERRIDE="${answer:-$ENVIRONMENT_WEB_CAPTCHA_SITE_KEY}"

  # Web default country
  echo "Default Country: ($ENVIRONMENT_WEB_DEFAULT_COUNTRY)"
  read answer

  local ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE="${answer:-$ENVIRONMENT_WEB_DEFAULT_COUNTRY}"

  # Default language
  echo "Default Language: ($ENVIRONMENT_WEB_DEFAULT_LANGUAGE)"
  read answer

  local ENVIRONMENT_WEB_DEFAULT_LANGUAGE_OVERRIDE="${answer:-$ENVIRONMENT_WEB_DEFAULT_LANGUAGE}"

  # Default language
  echo "Default Currency: ($ENVIRONMENT_WEB_BASE_CURRENCY)"
  read answer

  local ENVIRONMENT_WEB_BASE_CURRENCY_OVERRIDE="${answer:-$ENVIRONMENT_WEB_BASE_CURRENCY}"

  /bin/cat << EOF
  
*********************************************
Exchange URL: $ORIGINAL_CHARACTER_FOR_HEX_CONFIGMAP_DOMAIN

Web Captcha Sitekey: $ENVIRONMENT_WEB_CAPTCHA_SITE_KEY_OVERRIDE

Default Country: $ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE

Default Language: $ENVIRONMENT_WEB_DEFAULT_LANGUAGE_OVERRIDE

Default Currency: $ENVIRONMENT_WEB_BASE_CURRENCY_OVERRIDE
*********************************************

EOF

  echo "Are the values are all correct? (Y/n)"
  read answer

  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    echo "You chose false. Please confirm the values and re-run the command."
    exit 1;
  
  fi

  echo "Provided values would be updated on your settings files automatically."

  for i in ${CONFIG_FILE_PATH[@]}; do

    # Update exchange name
    if command grep -q "ENVIRONMENT_EXCHANGE_NAME" $i > /dev/null ; then
    CONFIGMAP_FILE_PATH=$i
    sed -i.bak "s/HEX_CONFIGMAP_DOMAIN=.*/HEX_CONFIGMAP_DOMAIN=$EXCHANGE_WEB_DOMAIN_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/ENVIRONMENT_WEB_CAPTCHA_SITE_KEY=$ENVIRONMENT_WEB_CAPTCHA_SITE_KEY/ENVIRONMENT_WEB_CAPTCHA_SITE_KEY=$ENVIRONMENT_WEB_CAPTCHA_SITE_KEY_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/ENVIRONMENT_WEB_DEFAULT_COUNTRY=$ENVIRONMENT_WEB_DEFAULT_COUNTRY/ENVIRONMENT_WEB_DEFAULT_COUNTRY=$ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/ENVIRONMENT_WEB_DEFAULT_LANGUAGE=$ENVIRONMENT_WEB_DEFAULT_LANGUAGE/ENVIRONMENT_WEB_DEFAULT_LANGUAGE=$ENVIRONMENT_WEB_DEFAULT_LANGUAGE_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/ENVIRONMENT_WEB_BASE_CURRENCY=$ENVIRONMENT_WEB_BASE_CURRENCY/ENVIRONMENT_WEB_BASE_CURRENCY=$ENVIRONMENT_WEB_BASE_CURRENCY_OVERRIDE/" $CONFIGMAP_FILE_PATH
    rm $CONFIGMAP_FILE_PATH.bak
    fi
      
  done

  export HEX_CONFIGMAP_DOMAIN=$ORIGINAL_CHARACTER_FOR_HEX_CONFIGMAP_DOMAIN

  export ENVIRONMENT_WEB_CAPTCHA_SITE_KEY=$ENVIRONMENT_WEB_CAPTCHA_SITE_KEY_OVERRIDE
  
  export ENVIRONMENT_WEB_DEFAULT_COUNTRY=$ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE

  export ENVIRONMENT_WEB_DEFAULT_LANGUAGE=$ENVIRONMENT_WEB_DEFAULT_LANGUAGE_OVERRIDE

  export ENVIRONMENT_WEB_BASE_CURRENCY=$ENVIRONMENT_WEB_BASE_CURRENCY_OVERRIDE

}

function reactivate_exchange() {
  
echo "Are the sure your want to reactivate your exchange? (y/N)"
echo "Make sure you already updated your Activation Code, Exchange Name, or API Server URL."
read answer

if [[ "$answer" = "${answer#[Yy]}" ]]; then
    
  echo "You chose false. Please confirm the values and re-run the command."
  exit 1;

fi

if [[ "$USE_KUBERNETES" ]]; then

  echo "Reactivating the exchange..."

  if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-reactivate-exchange \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_DOCKER_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_DOCKER_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hex.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server/values.yaml \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/add-pair.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/bitholla-hex-server; then

    echo "Kubernetes Job has been created for reactivating your exchange."

    echo "Waiting until Job get completely run"
    sleep 30;

  else 

    echo "Failed to create Kubernetes Job for reactivating your exchange, Please confirm your input values and try again."
    helm del --purge $ENVIRONMENT_EXCHANGE_NAME-reactivate-exchange
  
  fi

  if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-reactivate-exchange \
            --namespace $ENVIRONMENT_EXCHANGE_NAME \
            -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

    echo "Successfully reactivated your exchange!"
    kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-reactivate-exchange

    echo "Removing created Kubernetes Job for adding new coin..."
    helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME

    echo "Restarting the exchange..."
    kubectl delete pods --namespace $ENVIRONMENT_EXCHANGE_NAME -l role=$$ENVIRONMENT_EXCHANGE_NAME
  
  else 

    echo "Failed to create Kubernetes Job for reactivating your exchange, Please confirm your input values and try again."
    helm del --purge $ENVIRONMENT_EXCHANGE_NAME-reactivate-exchange
  
  fi

elif [[ ! "$USE_KUBERNETES" ]]; then

  IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

  # Overriding container prefix for develop server
  if [[ "$IS_DEVELOP" ]]; then
    
    CONTAINER_PREFIX=

  fi

  echo "Reactivating the exchange..."
  if command docker exec --env "API_HOST=${PAIR_NAME}" \
                  --env "API_NA<E=${PAIR_BASE}" \
                  --env "ACTIVATION_CODE=${PAIR_2}" \
                  ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                  node tools/dbs/setExchange.js; then
  
    echo "Restarting the exchange to apply changes."

    if  [[ "$IS_DEVELOP" ]]; then

      # Restarting containers after database init jobs.
      echo "Restarting containers to apply database changes."
      docker-compose -f $HEX_CODEBASE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

    else

      # Restarting containers after database init jobs.
      echo "Restarting containers to apply database changes."
      docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

    fi

    echo "Successfully reactivated the exchange."
  
  else 

    echo "Failed to reactivate the exchange. Please review your configurations and try again."
    exit 1;

  fi

fi

exit 0;

} 
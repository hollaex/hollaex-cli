#!/bin/bash 
SCRIPTPATH=$HOME/.hollaex-cli

function local_hollaex_network_database_init() {

    echo "Preparing to initialize exchange database..."
    sleep 10;
    
    if [[ "$1" == "start" ]]; then

      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

      echo "Running sequelize db:migrate"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 sequelize db:migrate

      echo "Running database triggers"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js

      echo "Running sequelize db:seed:all"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 sequelize db:seed:all

      echo "Setting up the InfluxDB"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/createInflux.js

      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/migrateInflux.js

      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/initializeInflux.js

    elif [[ "$1" == 'upgrade' ]]; then

      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

      echo "Running sequelize db:migrate"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 sequelize db:migrate

      echo "Running database triggers"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/runTriggers.js

      echo "Initializing the InfluxDB"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/initializeInflux.js
    
    fi
}

function local_database_init() {

    echo "Preparing to initialize exchange database..."
    sleep 10;
    
    if [[ "$1" == "start" ]]; then

      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

      echo "Running sequelize db:migrate"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 sequelize db:migrate

      echo "Running database triggers"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js

      echo "Running sequelize db:seed:all"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 sequelize db:seed:all

      echo "Setting up the exchange with provided activation code"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/setActivationCode.js

      echo "Updating the secrets.."
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/checkConfig.js

      echo "Setting up the version number based on the current Kit."
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/setKitVersion.js

    elif [[ "$1" == 'upgrade' ]]; then

      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

      echo "Running sequelize db:migrate"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 sequelize db:migrate

      echo "Running database triggers"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/runTriggers.js

      echo "Updating the secrets.."
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/checkConfig.js

      echo "Setting up the version number based on the current Kit."
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/setKitVersion.js
    
    fi
}

function kubernetes_database_init() {

  if [[ "$1" == "launch" ]]; then

    sleep 30

     # Checks the api container(s) get ready enough to run database upgrade jobs.
    while ! kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- echo "API is ready!" > /dev/null 2>&1;
        do echo "API container is not ready! Retrying..."
        sleep 15;
    done;

    echo "API container become ready to run Database initialization jobs!"
    sleep 10;

    echo "Running sequelize db:migrate"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- sequelize db:migrate 

    echo "Running Database Triggers"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/runTriggers.js

    echo "Running sequelize db:seed:all"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- sequelize db:seed:all 

    echo "Setting up the exchange with provided activation code"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/setActivationCode.js

    echo "Setting up the secret"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/checkConfig.js

    echo "Setting up the version"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/setKitVersion.js
    
  elif [[ "$1" == "upgrade" ]]; then

    echo "Running database jobs..."

    if command helm install $ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                --set job.enable=true \
                --set job.mode=hollaex_upgrade \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server; then

      while ! [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]] ;
          do echo "Waiting for the database job gets done..."
          sleep 10;
      done;

      echo "Successfully ran the database jobs!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade

      echo "Removing the Kubernetes Job for running database jobs..."
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade --namespace $ENVIRONMENT_EXCHANGE_NAME

    else 

      printf "\033[91mFailed to create Kubernetes Job for running database jobs, Please confirm your input values and try again.\033[39m\n"

      echo "Displayling logs..."
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade
      
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade --namespace $ENVIRONMENT_EXCHANGE_NAME

      # Only tries to attempt apply ingress rules from Kubernetes if it doesn't exists.
      if ! command kubectl get ingress -n $ENVIRONMENT_EXCHANGE_NAME > /dev/null; then
      
          echo "Applying $HOLLAEX_CONFIGMAP_API_NAME ingress rule on the cluster."
          kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

      fi

      exit 1;

    fi

  fi

}

function kubernetes_hollaex_network_database_init() {

  if [[ "$1" == "launch" ]]; then

    sleep 30

     # Checks the api container(s) get ready enough to run database upgrade jobs.
    while ! kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- echo "API is ready!" > /dev/null 2>&1;
        do echo "API container is not ready! Retrying..."
        sleep 15;
    done;

    echo "API container become ready to run Database initialization jobs!"
    sleep 10;

    echo "Running sequelize db:migrate"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- sequelize db:migrate 

    echo "Running Database Triggers"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/runTriggers.js

    echo "Running sequelize db:seed:all"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- sequelize db:seed:all 

    echo "Running InfluxDB initialization jobs"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/createInflux.js
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/migrateInflux.js
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/initializeInflux.js
    
  elif [[ "$1" == "upgrade" ]]; then

    echo "Running database jobs..."

    if command helm install $ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                --set job.enable=true \
                --set job.mode=run_triggers \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server/values.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server; then

      while ! [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]] ;
          do echo "Waiting for the database job gets done..."
          sleep 10;
      done;

      echo "Successfully ran the database jobs!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade

      echo "Removing the Kubernetes Job for running database jobs..."
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade --namespace $ENVIRONMENT_EXCHANGE_NAME

    else 

      printf "\033[91mFailed to create Kubernetes Job for running database jobs, Please confirm your input values and try again.\033[39m\n"

      echo "Displayling logs..."
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade
      
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade --namespace $ENVIRONMENT_EXCHANGE_NAME

      # Only tries to attempt apply ingress rules from Kubernetes if it doesn't exists.
      if ! command kubectl get ingress -n $ENVIRONMENT_EXCHANGE_NAME > /dev/null; then
      
          echo "Applying $HOLLAEX_CONFIGMAP_API_NAME ingress rule on the cluster."
          kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

      fi

      exit 1;

    fi

  fi

}

function local_code_test() {

    echo "Running mocha code test"
    docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server-api_1 mocha --exit

    exit 0;
}

function check_kubernetes_dependencies() {

    # Checking kubectl and helm are installed on this machine.
    if command kubectl version > /dev/null 2>&1 && command helm version > /dev/null 2>&1; then

         echo "*********************************************"
         echo "kubectl and helm detected"
         echo "# kubectl version:"
         echo "$(kubectl version)"
         echo "# helm version:"
         echo "$(helm version)"
         echo "*********************************************"

    else

         printf "\033[91mHollaEx CLI failed to detect kubectl or helm installed on this machine. Please install it before running HollaEx CLI.\033[39m\n"
         exit 1;

    fi

}

 
function load_config_variables() {

  function base64_line_break_per_os() {

    if [[ "$OSTYPE" == *"darwin"* ]]; then

      base64 -b 0
    
    else 

      base64 -w 0

    fi

  }

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

  HOLLAEX_SECRET_VARIABLES_QUOTETRIM=$(for value in ${HOLLAEX_SECRET_VARIABLES} 
  do   
      parseKey=$(echo $value | cut -f1 -d '=')
      parseValue=$(echo $value | cut -f2 -d '=')

      suffixTrim="${parseValue%\'}"
      prefixSuffixTrim="${suffixTrim#\'}"

      echo "$parseKey=$prefixSuffixTrim"

  done)

  HOLLAEX_SECRET_VARIABLES_BASE64=$(for value in ${HOLLAEX_SECRET_VARIABLES_QUOTETRIM} 
  do  
      printf "${value//=$(cut -d "=" -f 2 <<< "$value")/=\'$(cut -d "=" -f 2 <<< "$value" | tr -d '\n' | base64_line_break_per_os)\'} ";
  
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

$(echo "$HOLLAEX_SECRET_VARIABLES" | tr -d '\'\')
EOL

}

function generate_nginx_upstream() {

IFS=',' read -ra LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE <<< "$ENVIRONMENT_EXCHANGE_RUN_MODE"

for i in ${LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE[@]}; do
  
  # Generate local nginx conf
  cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream.conf <<EOL
  upstream api {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-api:10010;
  }
  upstream socket {
    ip_hash;
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-stream:10080;
  }
  upstream plugins {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-plugins:10011;
  }
EOL

done

}

function generate_nginx_upstream_for_network() {

IFS=',' read -ra LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE <<< "$ENVIRONMENT_EXCHANGE_RUN_MODE"

for i in ${LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE[@]}; do
  
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

done

}

function generate_nginx_upstream_for_web(){

  # Generate local nginx conf
  cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream-web.conf <<EOL

  upstream web {
    server ${ENVIRONMENT_EXCHANGE_NAME}-web:80;
  }
EOL

}

function apply_nginx_user_defined_values(){
    #sed -i.bak "s/$ENVIRONMENT_DOCKER_IMAGE_VERSION/$ENVIRONMENT_DOCKER_IMAGE_VERSION_OVERRIDE/" $CONFIGMAP_FILE_PATH

    local SERVER_DOMAIN=$(echo $HOLLAEX_CONFIGMAP_API_HOST | cut -f3 -d "/")
    sed -i.bak "s/server_name.*\#Server.*/server_name $SERVER_DOMAIN; \#Server domain/" $TEMPLATE_GENERATE_PATH/local/nginx/nginx.conf
    rm $TEMPLATE_GENERATE_PATH/local/nginx/nginx.conf.bak

    if [[ -f "$TEMPLATE_GENERATE_PATH/local/nginx/conf.d/web.conf" ]]; then 
      CLIENT_DOMAIN=$(echo $HOLLAEX_CONFIGMAP_DOMAIN | cut -f3 -d "/")
      sed -i.bak "s/server_name.*\#Client.*/server_name $CLIENT_DOMAIN; \#Client domain/" $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/web.conf
      rm $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/web.conf.bak
    fi
}

function generate_local_docker_compose_for_core_dev() {

# Generate docker-compose
cat > $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
version: '3'
services:

  ${ENVIRONMENT_EXCHANGE_NAME}-redis:
    image: ${ENVIRONMENT_DOCKER_IMAGE_REDIS_REGISTRY:-redis}:${ENVIRONMENT_DOCKER_IMAGE_REDIS_VERSION:-5.0.5-alpine}
    restart: unless-stopped
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
    ports:
      - 6379:6379
    environment:
      - REDIS_PASSWORD=${HOLLAEX_SECRET_REDIS_PASSWORD}
    command : ["sh", "-c", "redis-server --requirepass \$\${REDIS_PASSWORD}"]
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network

  ${ENVIRONMENT_EXCHANGE_NAME}-db:
    image: ${ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_REGISTRY:-postgres}:${ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_VERSION:-10.9-alpine}
    restart: unless-stopped
    ports:
      - 5432:5432
    environment:
      - POSTGRES_DB=$HOLLAEX_SECRET_DB_NAME
      - POSTGRES_USER=$HOLLAEX_SECRET_DB_USERNAME
      - POSTGRES_PASSWORD=$HOLLAEX_SECRET_DB_PASSWORD
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network

  ${ENVIRONMENT_EXCHANGE_NAME}-influxdb:
    image: ${ENVIRONMENT_DOCKER_IMAGE_INFLUXDB_REGISTRY:-influxdb}:${ENVIRONMENT_DOCKER_IMAGE_INFLUXDB_VERSION:-1.7.8-alpine}
    restart: unless-stopped
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

  ${ENVIRONMENT_EXCHANGE_NAME}-server-api:
    image: ${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY}:${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION}
    restart: unless-stopped
    env_file:
      - ${TEMPLATE_GENERATE_PATH}/local/${ENVIRONMENT_EXCHANGE_NAME}.env.local
    environment:
      - DEPLOYMENT_MODE=api
    entrypoint:
      - pm2-runtime
      - start
      - ecosystem.config.js
      - --env
      - development
    volumes:
      - ${HOLLAEX_CLI_INIT_PATH}/plugins:/app/plugins
      - ${HOLLAEX_CORE_PATH}/api:/app/api
      - ${HOLLAEX_CORE_PATH}/config:/app/config
      - ${HOLLAEX_CORE_PATH}/db:/app/db
      - ${HOLLAEX_CLI_INIT_PATH}/db/migrations:/app/db/migrations
      - ${HOLLAEX_CLI_INIT_PATH}/db/models:/app/db/models
      - ${HOLLAEX_CLI_INIT_PATH}/db/seeders:/app/db/seeders
      - ${HOLLAEX_CLI_INIT_PATH}/mail:/app/mail
      - ${HOLLAEX_CORE_PATH}/queue:/app/queue
      - ${HOLLAEX_CORE_PATH}/ws:/app/ws
      - ${HOLLAEX_CORE_PATH}/server.js:/app/server.js
      - ${HOLLAEX_CORE_PATH}/ecosystem.config.js:/app/ecosystem.config.js
      - ${HOLLAEX_CORE_PATH}/constants.js:/app/constants.js
      - ${HOLLAEX_CORE_PATH}/messages.js:/app/messages.js
      - ${HOLLAEX_CORE_PATH}/logs:/app/logs
      - ${HOLLAEX_CORE_PATH}/test:/app/test
      - ${HOLLAEX_CORE_PATH}/tools:/app/tools
      - ${HOLLAEX_CORE_PATH}/utils:/app/utils
      - ${HOLLAEX_CORE_PATH}/init.js:/app/init.js
    ports:
      - 10010:10010
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-influxdb
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
  
  ${ENVIRONMENT_EXCHANGE_NAME}-server-plugins:
    image: ${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY}:${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION}
    restart: unless-stopped
    env_file:
      - ${TEMPLATE_GENERATE_PATH}/local/${ENVIRONMENT_EXCHANGE_NAME}.env.local
    environment:
      - DEPLOYMENT_MODE=plugins
    entrypoint:
      - pm2-runtime
      - start
      - ecosystem.config.js
      - --env
      - development
    volumes:
      - ${HOLLAEX_CLI_INIT_PATH}/plugins:/app/plugins
      - ${HOLLAEX_CORE_PATH}/api:/app/api
      - ${HOLLAEX_CORE_PATH}/config:/app/config
      - ${HOLLAEX_CORE_PATH}/db:/app/db
      - ${HOLLAEX_CLI_INIT_PATH}/db/migrations:/app/db/migrations
      - ${HOLLAEX_CLI_INIT_PATH}/db/models:/app/db/models
      - ${HOLLAEX_CLI_INIT_PATH}/db/seeders:/app/db/seeders
      - ${HOLLAEX_CLI_INIT_PATH}/mail:/app/mail
      - ${HOLLAEX_CORE_PATH}/queue:/app/queue
      - ${HOLLAEX_CORE_PATH}/ws:/app/ws
      - ${HOLLAEX_CORE_PATH}/server.js:/app/server.js
      - ${HOLLAEX_CORE_PATH}/ecosystem.config.js:/app/ecosystem.config.js
      - ${HOLLAEX_CORE_PATH}/constants.js:/app/constants.js
      - ${HOLLAEX_CORE_PATH}/messages.js:/app/messages.js
      - ${HOLLAEX_CORE_PATH}/logs:/app/logs
      - ${HOLLAEX_CORE_PATH}/test:/app/test
      - ${HOLLAEX_CORE_PATH}/tools:/app/tools
      - ${HOLLAEX_CORE_PATH}/utils:/app/utils
      - ${HOLLAEX_CORE_PATH}/init.js:/app/init.js
    ports:
      - 10011:10011
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-influxdb
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
      - ${ENVIRONMENT_EXCHANGE_NAME}-db

  ${ENVIRONMENT_EXCHANGE_NAME}-server-stream:
    image: ${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY}:${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION}
    restart: unless-stopped
    env_file:
      - ${TEMPLATE_GENERATE_PATH}/local/${ENVIRONMENT_EXCHANGE_NAME}.env.local
    environment:
      - DEPLOYMENT_MODE=ws
    entrypoint:
      - pm2-runtime
      - start
      - ecosystem.config.js
      - --env
      - development
    volumes:
      - ${HOLLAEX_CORE_PATH}/api:/app/api
      - ${HOLLAEX_CORE_PATH}/config:/app/config
      - ${HOLLAEX_CORE_PATH}/db:/app/db
      - ${HOLLAEX_CLI_INIT_PATH}/db/migrations:/app/db/migrations
      - ${HOLLAEX_CLI_INIT_PATH}/db/models:/app/db/models
      - ${HOLLAEX_CLI_INIT_PATH}/db/seeders:/app/db/seeders
      - ${HOLLAEX_CLI_INIT_PATH}/mail:/app/mail
      - ${HOLLAEX_CORE_PATH}/queue:/app/queue
      - ${HOLLAEX_CORE_PATH}/ws:/app/ws
      - ${HOLLAEX_CORE_PATH}/server.js:/app/server.js
      - ${HOLLAEX_CORE_PATH}/ecosystem.config.js:/app/ecosystem.config.js
      - ${HOLLAEX_CORE_PATH}/constants.js:/app/constants.js
      - ${HOLLAEX_CORE_PATH}/messages.js:/app/messages.js
      - ${HOLLAEX_CORE_PATH}/logs:/app/logs
      - ${HOLLAEX_CORE_PATH}/test:/app/test
      - ${HOLLAEX_CORE_PATH}/tools:/app/tools
      - ${HOLLAEX_CORE_PATH}/utils:/app/utils
      - ${HOLLAEX_CORE_PATH}/init.js:/app/init.js
    ports:
      - 10080:10080
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-influxdb
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
      - ${ENVIRONMENT_EXCHANGE_NAME}-db

  ${ENVIRONMENT_EXCHANGE_NAME}-nginx:
    image: ${ENVIRONMENT_DOCKER_IMAGE_LOCAL_NGINX_REGISTRY:-bitholla/nginx-with-certbot}:${ENVIRONMENT_DOCKER_IMAGE_LOCAL_NGINX_VERSION:-1.15.8}
    restart: unless-stopped
    volumes:
      - ./nginx:/etc/nginx
      - ./logs/nginx:/var/log/nginx
      - ./nginx/static/:/usr/share/nginx/html
      - ./letsencrypt:/etc/letsencrypt
    ports:
      - ${ENVIRONMENT_LOCAL_NGINX_HTTP_PORT:-80}:80
      - ${ENVIRONMENT_LOCAL_NGINX_HTTPS_PORT:-443}:443
    environment:
      - NGINX_PORT=80
    entrypoint: 
      - /bin/sh
      - -c 
      - ip -4 route list match 0/0 | awk '{print \$\$3 " host.access"}' >> /etc/hosts && nginx -g "daemon off;"
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-server-api
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
      
EOL

  IFS=',' read -ra PAIRS <<< "$HOLLAEX_CONFIGMAP_PAIRS"    #Convert string to array

  for j in "${PAIRS[@]}"; do
    TRADE_PARIS_DEPLOYMENT=$(echo $j | cut -f1 -d ",")

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

  ${ENVIRONMENT_EXCHANGE_NAME}-server-engine-$TRADE_PARIS_DEPLOYMENT:
    image: ${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY}:${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION}
    restart: unless-stopped
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    environment:
      - DEPLOYMENT_MODE=queue ${TRADE_PARIS_DEPLOYMENT}
    entrypoint:
      - pm2-runtime
      - start
      - ecosystem.config.js
      - --env
      - development
    volumes:
      - ${HOLLAEX_CORE_PATH}/api:/app/api
      - ${HOLLAEX_CORE_PATH}/config:/app/config
      - ${HOLLAEX_CORE_PATH}/db:/app/db
      - ${HOLLAEX_CLI_INIT_PATH}/db/migrations:/app/db/migrations
      - ${HOLLAEX_CLI_INIT_PATH}/db/models:/app/db/models
      - ${HOLLAEX_CLI_INIT_PATH}/db/seeders:/app/db/seeders
      - ${HOLLAEX_CLI_INIT_PATH}/mail:/app/mail
      - ${HOLLAEX_CORE_PATH}/queue:/app/queue
      - ${HOLLAEX_CORE_PATH}/ws:/app/ws
      - ${HOLLAEX_CORE_PATH}/server.js:/app/server.js
      - ${HOLLAEX_CORE_PATH}/ecosystem.config.js:/app/ecosystem.config.js
      - ${HOLLAEX_CORE_PATH}/constants.js:/app/constants.js
      - ${HOLLAEX_CORE_PATH}/messages.js:/app/messages.js
      - ${HOLLAEX_CORE_PATH}/logs:/app/logs
      - ${HOLLAEX_CORE_PATH}/test:/app/test
      - ${HOLLAEX_CORE_PATH}/tools:/app/tools
      - ${HOLLAEX_CORE_PATH}/utils:/app/utils
      - ${HOLLAEX_CORE_PATH}/init.js:/app/init.js
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
      
EOL

  done

# Generate docker-compose
cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
networks:
  ${ENVIRONMENT_EXCHANGE_NAME}-network:
  
EOL
}

function generate_local_docker_compose_for_dev() {

# Generate docker-compose
cat > $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
version: '3'
services:

  ${ENVIRONMENT_EXCHANGE_NAME}-redis:
    image: ${ENVIRONMENT_DOCKER_IMAGE_REDIS_REGISTRY:-redis}:${ENVIRONMENT_DOCKER_IMAGE_REDIS_VERSION:-6.0.9-alpine}
    restart: unless-stopped
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
    ports:
      - 6379:6379
    environment:
      - REDIS_PASSWORD=${HOLLAEX_SECRET_REDIS_PASSWORD}
    command : ["sh", "-c", "redis-server --requirepass \$\${REDIS_PASSWORD}"]
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network

  ${ENVIRONMENT_EXCHANGE_NAME}-db:
    image: ${ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_REGISTRY:-postgres}:${ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_VERSION:-10.9}
    restart: unless-stopped
    ports:
      - 5432:5432
    environment:
      - POSTGRES_DB=$HOLLAEX_SECRET_DB_NAME
      - POSTGRES_USER=$HOLLAEX_SECRET_DB_USERNAME
      - POSTGRES_PASSWORD=$HOLLAEX_SECRET_DB_PASSWORD
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network

  ${ENVIRONMENT_EXCHANGE_NAME}-server-api:
    image: ${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY}:${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION}
    restart: unless-stopped
    env_file:
      - ${TEMPLATE_GENERATE_PATH}/local/${ENVIRONMENT_EXCHANGE_NAME}.env.local
    environment:
      - DEPLOYMENT_MODE=api
    entrypoint:
      - pm2-runtime
      - start
      - ecosystem.config.js
      - --env
      - development
    volumes:
      - ${HOLLAEX_CLI_INIT_PATH}/server/plugins:/app/plugins
      - ${HOLLAEX_CLI_INIT_PATH}/server/api:/app/api
      - ${HOLLAEX_CLI_INIT_PATH}/server/config:/app/config
      - ${HOLLAEX_CLI_INIT_PATH}/server/db:/app/db
      - ${HOLLAEX_CLI_INIT_PATH}/server/db/migrations:/app/db/migrations
      - ${HOLLAEX_CLI_INIT_PATH}/server/db/models:/app/db/models
      - ${HOLLAEX_CLI_INIT_PATH}/server/db/seeders:/app/db/seeders
      - ${HOLLAEX_CLI_INIT_PATH}/server/mail:/app/mail
      - ${HOLLAEX_CLI_INIT_PATH}/server/ws:/app/ws
      - ${HOLLAEX_CLI_INIT_PATH}/server/server.js:/app/server.js
      - ${HOLLAEX_CLI_INIT_PATH}/server/ecosystem.config.js:/app/ecosystem.config.js
      - ${HOLLAEX_CLI_INIT_PATH}/server/constants.js:/app/constants.js
      - ${HOLLAEX_CLI_INIT_PATH}/server/messages.js:/app/messages.js
      - ${HOLLAEX_CLI_INIT_PATH}/server/logs:/app/logs
      - ${HOLLAEX_CLI_INIT_PATH}/server/test:/app/test
      - ${HOLLAEX_CLI_INIT_PATH}/server/tools:/app/tools
      - ${HOLLAEX_CLI_INIT_PATH}/server/utils:/app/utils
      - ${HOLLAEX_CLI_INIT_PATH}/server/init.js:/app/init.js
    ports:
      - 10010:10010
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
      - ${ENVIRONMENT_EXCHANGE_NAME}-db

  ${ENVIRONMENT_EXCHANGE_NAME}-server-stream:
    image: ${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY}:${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION}
    restart: always
    environment:
      - DEPLOYMENT_MODE=ws
    env_file:
      - ${TEMPLATE_GENERATE_PATH}/local/${ENVIRONMENT_EXCHANGE_NAME}.env.local
    entrypoint:
      - pm2-runtime
      - start
      - ecosystem.config.js
      - --env
      - development
    volumes:
      - ${HOLLAEX_CLI_INIT_PATH}/server/plugins:/app/plugins
      - ${HOLLAEX_CLI_INIT_PATH}/server/api:/app/api
      - ${HOLLAEX_CLI_INIT_PATH}/server/config:/app/config
      - ${HOLLAEX_CLI_INIT_PATH}/server/db:/app/db
      - ${HOLLAEX_CLI_INIT_PATH}/server/db/migrations:/app/db/migrations
      - ${HOLLAEX_CLI_INIT_PATH}/server/db/models:/app/db/models
      - ${HOLLAEX_CLI_INIT_PATH}/server/db/seeders:/app/db/seeders
      - ${HOLLAEX_CLI_INIT_PATH}/server/mail:/app/mail
      - ${HOLLAEX_CLI_INIT_PATH}/server/ws:/app/ws
      - ${HOLLAEX_CLI_INIT_PATH}/server/server.js:/app/server.js
      - ${HOLLAEX_CLI_INIT_PATH}/server/ecosystem.config.js:/app/ecosystem.config.js
      - ${HOLLAEX_CLI_INIT_PATH}/server/constants.js:/app/constants.js
      - ${HOLLAEX_CLI_INIT_PATH}/server/messages.js:/app/messages.js
      - ${HOLLAEX_CLI_INIT_PATH}/server/logs:/app/logs
      - ${HOLLAEX_CLI_INIT_PATH}/server/test:/app/test
      - ${HOLLAEX_CLI_INIT_PATH}/server/tools:/app/tools
      - ${HOLLAEX_CLI_INIT_PATH}/server/utils:/app/utils
      - ${HOLLAEX_CLI_INIT_PATH}/server/init.js:/app/init.js
    ports:
      - 10080:10080
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
      - ${ENVIRONMENT_EXCHANGE_NAME}-db

  ${ENVIRONMENT_EXCHANGE_NAME}-server-plugins:
    image: ${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY}:${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION}
    restart: always
    environment:
      - DEPLOYMENT_MODE=plugins
    env_file:
      - ${TEMPLATE_GENERATE_PATH}/local/${ENVIRONMENT_EXCHANGE_NAME}.env.local
    entrypoint:
      - pm2-runtime
      - start
      - ecosystem.config.js
      - --env
      - development
    volumes:
      - ${HOLLAEX_CLI_INIT_PATH}/server/plugins:/app/plugins
      - ${HOLLAEX_CLI_INIT_PATH}/server/api:/app/api
      - ${HOLLAEX_CLI_INIT_PATH}/server/config:/app/config
      - ${HOLLAEX_CLI_INIT_PATH}/server/db:/app/db
      - ${HOLLAEX_CLI_INIT_PATH}/server/db/migrations:/app/db/migrations
      - ${HOLLAEX_CLI_INIT_PATH}/server/db/models:/app/db/models
      - ${HOLLAEX_CLI_INIT_PATH}/server/db/seeders:/app/db/seeders
      - ${HOLLAEX_CLI_INIT_PATH}/server/mail:/app/mail
      - ${HOLLAEX_CLI_INIT_PATH}/server/ws:/app/ws
      - ${HOLLAEX_CLI_INIT_PATH}/server/server.js:/app/server.js
      - ${HOLLAEX_CLI_INIT_PATH}/server/ecosystem.config.js:/app/ecosystem.config.js
      - ${HOLLAEX_CLI_INIT_PATH}/server/constants.js:/app/constants.js
      - ${HOLLAEX_CLI_INIT_PATH}/server/messages.js:/app/messages.js
      - ${HOLLAEX_CLI_INIT_PATH}/server/logs:/app/logs
      - ${HOLLAEX_CLI_INIT_PATH}/server/test:/app/test
      - ${HOLLAEX_CLI_INIT_PATH}/server/tools:/app/tools
      - ${HOLLAEX_CLI_INIT_PATH}/server/utils:/app/utils
      - ${HOLLAEX_CLI_INIT_PATH}/server/init.js:/app/init.js
    ports:
      - 10011:10011
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-redis
      - ${ENVIRONMENT_EXCHANGE_NAME}-db

  ${ENVIRONMENT_EXCHANGE_NAME}-nginx:
    image: ${ENVIRONMENT_DOCKER_IMAGE_LOCAL_NGINX_REGISTRY:-bitholla/nginx-with-certbot}:${ENVIRONMENT_DOCKER_IMAGE_LOCAL_NGINX_VERSION:-1.15.8}
    restart: unless-stopped
    volumes:
      - ./nginx:/etc/nginx
      - ./logs/nginx:/var/log/nginx
      - ./nginx/static/:/usr/share/nginx/html
      - ./letsencrypt:/etc/letsencrypt
    ports:
      - ${ENVIRONMENT_LOCAL_NGINX_HTTP_PORT:-80}:80
      - ${ENVIRONMENT_LOCAL_NGINX_HTTPS_PORT:-443}:443
    environment:
      - NGINX_PORT=80
    entrypoint: 
      - /bin/sh
      - -c 
      - ip -4 route list match 0/0 | awk '{print \$\$3 " host.access"}' >> /etc/hosts && nginx -g "daemon off;"
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-server-api
    networks:

      - ${ENVIRONMENT_EXCHANGE_NAME}-network
      
EOL

# Generate docker-compose
cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
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
    image: ${ENVIRONMENT_DOCKER_IMAGE_REDIS_REGISTRY:-redis}:${ENVIRONMENT_DOCKER_IMAGE_REDIS_VERSION:-6.0.9-alpine}
    restart: unless-stopped
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
    ports:
      - 6379:6379
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    command : ["sh", "-c", "redis-server --requirepass \$\${REDIS_PASSWORD}"]
    deploy:
      resources:
        limits:
          cpus: "${ENVIRONMENT_REDIS_CPU_LIMITS:-0.1}"
          $(echo memory: "${ENVIRONMENT_REDIS_MEMORY_LIMITS:-100M}" | sed 's/i//g')
        reservations:
          cpus: "${ENVIRONMENT_REDIS_CPU_REQUESTS:-0.1}"
          $(echo memory: "${ENVIRONMENT_REDIS_MEMORY_REQUESTS:-100M}" | sed 's/i//g')
    networks:
      - $(if [[ "$HOLLAEX_NETWORK_LOCALHOST_MODE" ]]; then echo "local_hollaex-network-network"; else echo "${ENVIRONMENT_EXCHANGE_NAME}-network"; fi)
EOL

fi

if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" == "true" ]]; then 
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-db:
    image: ${ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_REGISTRY:-postgres}:${ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_VERSION:-10.9}
    restart: unless-stopped
    ports:
      - 5432:5432
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    deploy:
      resources:
        limits:
          cpus: "${ENVIRONMENT_POSTGRESQL_CPU_LIMITS:-0.1}"
          $(echo memory: "${ENVIRONMENT_POSTGRESQL_MEMORY_LIMITS:-100M}" | sed 's/i//g')
        reservations:
          cpus: "${ENVIRONMENT_POSTGRESQL_CPU_REQUESTS:-0.1}"
          $(echo memory: "${ENVIRONMENT_POSTGRESQL_MEMORY_REQUESTS:-100M}" | sed 's/i//g')
    command : ["sh", "-c", "export POSTGRES_DB=\$\${DB_NAME} && export POSTGRES_USER=\$\${DB_USERNAME} && export POSTGRES_PASSWORD=\$\${DB_PASSWORD} && ln -sf /usr/local/bin/docker-entrypoint.sh ./docker-entrypoint.sh && ./docker-entrypoint.sh postgres"]
    networks:
      - $(if [[ "$HOLLAEX_NETWORK_LOCALHOST_MODE" ]]; then echo "local_hollaex-network-network"; else echo "${ENVIRONMENT_EXCHANGE_NAME}-network"; fi)
EOL

fi

#LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE=$ENVIRONMENT_EXCHANGE_RUN_MODE

IFS=',' read -ra LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE <<< "$ENVIRONMENT_EXCHANGE_RUN_MODE"

for i in ${LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE[@]}; do

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

  ${ENVIRONMENT_EXCHANGE_NAME}-server-${i}:
    image: $ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION
    restart: unless-stopped
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    entrypoint:
      - node
    deploy:
      resources:
        limits:
          # CPU LIMIT
          $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_API_CPU_LIMITS:-0.1}\""; fi) 
          $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_STREAM_CPU_LIMITS:-0.1}\""; fi) 
          $(if [[ "${i}" == "plugins" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_PLUGINS_CPU_LIMITS:-0.1}\""; fi) 
          # MEMORY LIMIT
          $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_API_MEMORY_LIMITS:-512M}" | sed 's/i//g' ; fi) 
          $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_STREAM_MEMORY_LIMITS:-256M}" | sed 's/i//g' ; fi) 
          $(if [[ "${i}" == "plugins" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_PLUGINS_MEMORY_LIMITS:-512M}" | sed 's/i//g' ; fi) 
        reservations:
          # CPU REQUEST
          $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_API_CPU_REQUESTS:-0.05}\""; fi) 
          $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_STREAM_CPU_REQUESTS:-0.05}\""; fi) 
          $(if [[ "${i}" == "plugins" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_PLUGINS_CPU_REQUESTS:-0.05}\""; fi) 
          # MEMORY REQUEST
          $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_API_MEMORY_REQUESTS:-512M}" | sed 's/i//g' ; fi) 
          $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_STREAM_MEMORY_REQUESTS:-256M}" | sed 's/i//g' ; fi) 
          $(if [[ "${i}" == "plugins" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_PLUGINS_MEMORY_REQUESTS:-256M}" | sed 's/i//g' ; fi) 
    command:
      $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- app.js"; fi) 
      $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- ws/index.js"; fi) 
      $(if [[ "${i}" == "plugins" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- plugins/index.js"; fi) 
    $(if [[ "${i}" == "api" ]] || [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "ports:"; fi)
      $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- 10010:10010"; fi) 
      $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- 10080:10080"; fi)
      $(if [[ "${i}" == "plugins" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- 10011:10011"; fi)
    networks:
      - $(if [[ "$HOLLAEX_NETWORK_LOCALHOST_MODE" ]]; then echo "local_hollaex-network-network"; else echo "${ENVIRONMENT_EXCHANGE_NAME}-network"; fi)
    $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" ]] || [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" ]] || [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" ]]; then echo "depends_on:"; fi)
      $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-redis"; fi)
      $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-db"; fi)

EOL
  
  if [[ "$i" == "api" ]]; then
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

  ${ENVIRONMENT_EXCHANGE_NAME}-nginx:
    image: ${ENVIRONMENT_DOCKER_IMAGE_LOCAL_NGINX_REGISTRY:-bitholla/nginx-with-certbot}:${ENVIRONMENT_DOCKER_IMAGE_LOCAL_NGINX_VERSION:-1.15.8}
    restart: unless-stopped
    volumes:
      - ./nginx:/etc/nginx
      - ./logs/nginx:/var/log/nginx
      - ./nginx/static/:/usr/share/nginx/html
      - ./letsencrypt:/etc/letsencrypt
    ports:
      - ${ENVIRONMENT_LOCAL_NGINX_HTTP_PORT:-80}:80
      - ${ENVIRONMENT_LOCAL_NGINX_HTTPS_PORT:-443}:443
    environment:
      - NGINX_PORT=80
    entrypoint: 
      - /bin/sh
      - -c 
      - ip -4 route list match 0/0 | awk '{print \$\$3 " host.access"}' >> /etc/hosts && nginx -g "daemon off;"
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-server-${i}
      $(if [[ "$ENVIRONMENT_WEB_ENABLE" == true ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-web"; fi)
    networks:
      - $(if [[ "$HOLLAEX_NETWORK_LOCALHOST_MODE" ]]; then echo "local_hollaex-network-network"; else echo "${ENVIRONMENT_EXCHANGE_NAME}-network"; fi)
      
EOL

  fi

done

# Generate docker-compose
cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
networks:
  $(if [[ "$HOLLAEX_NETWORK_LOCALHOST_MODE" ]]; then echo "local_hollaex-network-network:"; else echo "${ENVIRONMENT_EXCHANGE_NAME}-network:"; fi)
    $(if [[ "$HOLLAEX_NETWORK_LOCALHOST_MODE" ]]; then echo "external: true"; fi)
EOL

}

function generate_local_docker_compose_for_network() {

# Generate docker-compose
cat > $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
version: '3'
services:
EOL

if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" == "true" ]]; then 

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-redis:
    image: ${ENVIRONMENT_DOCKER_IMAGE_REDIS_REGISTRY:-redis}:${ENVIRONMENT_DOCKER_IMAGE_REDIS_VERSION:-6.0.9-alpine}
    restart: unless-stopped
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
    ports:
      - 6380:6379
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    command : ["sh", "-c", "redis-server --requirepass \$\${REDIS_PASSWORD}"]
    deploy:
      resources:
        limits:
          cpus: "${ENVIRONMENT_REDIS_CPU_LIMITS:-0.1}"
          $(echo memory: "${ENVIRONMENT_REDIS_MEMORY_LIMITS:-100M}" | sed 's/i//g')
        reservations:
          cpus: "${ENVIRONMENT_REDIS_CPU_REQUESTS:-0.1}"
          $(echo memory: "${ENVIRONMENT_REDIS_MEMORY_REQUESTS:-100M}" | sed 's/i//g')
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL

fi

if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" == "true" ]]; then 
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-db:
    image: ${ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_REGISTRY:-postgres}:${ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_VERSION:-10.9}
    restart: unless-stopped

    ports:
      - 5433:5432

    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    deploy:
      resources:
        limits:
          cpus: "${ENVIRONMENT_POSTGRESQL_CPU_LIMITS:-0.1}"
          $(echo memory: "${ENVIRONMENT_POSTGRESQL_MEMORY_LIMITS:-100M}" | sed 's/i//g')
        reservations:
          cpus: "${ENVIRONMENT_POSTGRESQL_CPU_REQUESTS:-0.1}"
          $(echo memory: "${ENVIRONMENT_POSTGRESQL_MEMORY_REQUESTS:-100M}" | sed 's/i//g')
    command : ["sh", "-c", "export POSTGRES_DB=\$\${DB_NAME} && export POSTGRES_USER=\$\${DB_USERNAME} && export POSTGRES_PASSWORD=\$\${DB_PASSWORD} && ./docker-entrypoint.sh postgres"]
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL

fi

if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" == "true" ]]; then 
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-influxdb:
    image: ${ENVIRONMENT_DOCKER_IMAGE_INFLUXDB_REGISTRY:-influxdb}:${ENVIRONMENT_DOCKER_IMAGE_INFLUXDB_VERSION:-1.8.3}
    restart: unless-stopped

    ports:
      - 8087:8086

    deploy:
      resources:
        limits:
          cpus: "${ENVIRONMENT_INFLUXDB_CPU_LIMITS:-0.1}"
          $(echo memory: "${ENVIRONMENT_INFLUXDB_MEMORY_LIMITS:-100M}" | sed 's/i//g')
        reservations:
          cpus: "${ENVIRONMENT_INFLUXDB_CPU_REQUESTS:-0.1}"
          $(echo memory: "${ENVIRONMENT_INFLUXDB_MEMORY_REQUESTS:-100M}" | sed 's/i//g')
    environment:
      - INFLUX_DB=${HOLLAEX_SECRET_INFLUX_DB}
      - INFLUX_HOST=${ENVIRONMENT_EXCHANGE_NAME-influxdb}
      - INFLUX_PORT=${HOLLAEX_SECRET_INFLUX_PORT}
      - INFLUX_USER=${HOLLAEX_SECRET_INFLUX_USER}
      - INFLUX_PASSWORD=${HOLLAEX_SECRET_INFLUX_PASSWORD}
      - INFLUXDB_HTTP_LOG_ENABLED=false
      - INFLUXDB_DATA_QUERY_LOG_ENABLED=false
      - INFLUXDB_CONTINUOUS_QUERIES_LOG_ENABLED=false
      - INFLUXDB_LOGGING_LEVEL=error
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL

fi

if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_MONGODB" == "true" ]]; then 
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-mongodb:
    image: ${ENVIRONMENT_DOCKER_IMAGE_MONGODB_REGISTRY:-mongo}:${ENVIRONMENT_DOCKER_IMAGE_MONGODB_VERSION:-4.4.6-bionic}
    restart: unless-stopped

    ports:
      - 27108:27107

    deploy:
      resources:
        limits:
          cpus: "${ENVIRONMENT_MONGODB_CPU_LIMITS:-0.1}"
          $(echo memory: "${ENVIRONMENT_MONGODB_MEMORY_LIMITS:-100M}" | sed 's/i//g')
        reservations:
          cpus: "${ENVIRONMENT_MONGODB_CPU_REQUESTS:-0.1}"
          $(echo memory: "${ENVIRONMENT_IMONGODB_MEMORY_REQUESTS:-100M}" | sed 's/i//g')
    environment:
      - MONGO_INITDB_ROOT_USERNAME=${HOLLAEX_SECRET_MONGO_USERNAME}
      - MONGO_INITDB_ROOT_PASSWORD=${HOLLAEX_SECRET_MONGO_PASSWORD}
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
    image: $ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION
    restart: unless-stopped
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    entrypoint:
      - node
    deploy:
      resources:
        limits:
          # CPU LIMIT
          $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_API_CPU_LIMITS:-0.1}\""; fi) 
          $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_STREAM_CPU_LIMITS:-0.1}\""; fi) 
          $(if [[ "${i}" == "job" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_JOB_CPU_LIMITS:-0.1}\""; fi) 
          # MEMORY LIMIT
          $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_API_MEMORY_LIMITS:-512M}" | sed 's/i//g' ; fi) 
          $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_STREAM_MEMORY_LIMITS:-256M}" | sed 's/i//g' ; fi) 
          $(if [[ "${i}" == "job" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_JOB_MEMORY_LIMITS:-256M}" | sed 's/i//g' ; fi) 
        reservations:
          # CPU REQUEST
          $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_API_CPU_REQUESTS:-0.05}\""; fi) 
          $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_STREAM_CPU_REQUESTS:-0.05}\""; fi) 
          $(if [[ "${i}" == "job" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_JOB_CPU_REQUESTS:-0.05}\""; fi) 
          # MEMORY REQUEST
          $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_API_MEMORY_REQUESTS:-512M}" | sed 's/i//g' ; fi) 
          $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_STREAM_MEMORY_REQUESTS:-256M}" | sed 's/i//g' ; fi) 
          $(if [[ "${i}" == "job" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_JOB_MEMORY_REQUESTS:-256M}" | sed 's/i//g' ; fi) 
    $(if [[ ! "${i}" == "job" ]]; then echo "entrypoint:"; fi)
      $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- /app/api-binary"; fi) 
      $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- /app/stream-binary"; fi) 
    $(if [[ "${i}" == "job" ]]; then echo "command:"; fi) 
      $(if [[ "${i}" == "job" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- node tools/jobs/job.js"; fi) 

    $(if [[ "${i}" == "api" ]] || [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "ports:"; fi)
      $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- 10011:10010"; fi) 
      $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- 10081:10080"; fi)
      $(if [[ "${i}" == "plugins" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- 10012:10011"; fi)
  
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" ]] || [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" ]] || [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" ]]; then echo "depends_on:"; fi)
      $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-redis"; fi)
      $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-db"; fi)

EOL

  fi

  if [[ "$i" == "engine" ]]; then

    IFS=',' read -ra PAIRS <<< "$HOLLAEX_CONFIGMAP_PAIRS"    #Convert string to array

    for j in "${PAIRS[@]}"; do
      TRADE_PARIS_DEPLOYMENT=$(echo $j | cut -f1 -d ",")

    # Generate docker-compose
    cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

  ${ENVIRONMENT_EXCHANGE_NAME}-server-${i}-$TRADE_PARIS_DEPLOYMENT:
    image: $ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION
    restart: unless-stopped
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    environment:
      - PAIR=${TRADE_PARIS_DEPLOYMENT}
    entrypoint:
      - /app/engine-binary
    deploy:
      resources:
        limits:
          # CPU LIMIT
          $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_API_CPU_LIMITS:-0.1}\""; fi) 
          $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_STREAM_CPU_LIMITS:-0.1}\""; fi) 
          $(if [[ "${i}" == "job" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_JOB_CPU_LIMITS:-0.1}\""; fi) 
          $(if [[ "${i}" == "engine" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_ENGINE_CPU_LIMITS:-0.1}\""; fi) 
          # MEMORY LIMIT
          $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_API_MEMORY_LIMITS:-512M}" | sed 's/i//g' ; fi) 
          $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_STREAM_MEMORY_LIMITS:-256M}" | sed 's/i//g' ; fi) 
          $(if [[ "${i}" == "job" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_JOB_MEMORY_LIMITS:-256M}" | sed 's/i//g' ; fi) 
          $(if [[ "${i}" == "engine" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_ENGINE_MEMORY_LIMITS:-256M}" | sed 's/i//g' ; fi) 
        reservations:
          # CPU REQUEST
          $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_API_CPU_REQUESTS:-0.05}\""; fi) 
          $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_STREAM_CPU_REQUESTS:-0.05}\""; fi) 
          $(if [[ "${i}" == "job" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_JOB_CPU_REQUESTS:-0.05}\""; fi) 
          $(if [[ "${i}" == "engine" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "cpus: \"${ENVIRONMENT_ENGINE_CPU_REQUESTS:-0.05}\""; fi) 
          # MEMORY REQUEST
          $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_API_MEMORY_REQUESTS:-512M}" | sed 's/i//g' ; fi) 
          $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_STREAM_MEMORY_REQUESTS:-256M}" | sed 's/i//g' ; fi) 
          $(if [[ "${i}" == "job" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_JOB_MEMORY_REQUESTS:-256M}" | sed 's/i//g' ; fi) 
          $(if [[ "${i}" == "engine" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo memory: "${ENVIRONMENT_ENGINE_MEMORY_REQUESTS:-256M}" | sed 's/i//g' ; fi) 
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" ]] || [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" ]] || [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" ]]; then echo "depends_on:"; fi)
      $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-influxdb"; fi)
      $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-redis"; fi)
      $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-db"; fi)
        
EOL

    done

  fi

  if [[ "$i" == "api" ]]; then
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

  ${ENVIRONMENT_EXCHANGE_NAME}-nginx:
    image: ${ENVIRONMENT_DOCKER_IMAGE_LOCAL_NGINX_REGISTRY:-bitholla/nginx-with-certbot}:${ENVIRONMENT_DOCKER_IMAGE_LOCAL_NGINX_VERSION:-1.15.8}
    restart: unless-stopped
    volumes:
      - ./nginx:/etc/nginx
      - ./logs/nginx:/var/log/nginx
      - ./nginx/static/:/usr/share/nginx/html
      - ./letsencrypt:/etc/letsencrypt
    ports:
      $(if [[ "$HOLLAEX_NETWORK_LOCALHOST_MODE" == true ]]; then echo "- 8081:80"; else echo "- ${ENVIRONMENT_LOCAL_NGINX_HTTP_PORT:-80}:80"; fi)
      $(if [[ ! "$HOLLAEX_NETWORK_LOCALHOST_MODE" == true ]]; then echo "- ${ENVIRONMENT_LOCAL_NGINX_HTTPS_PORT:-443}:443"; fi)

    environment:
      - NGINX_PORT=80
    entrypoint: 
      - /bin/sh
      - -c 
      - ip -4 route list match 0/0 | awk '{print \$\$3 " host.access"}' >> /etc/hosts && nginx -g "daemon off;"
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-server-${i}
      $(if [[ "$ENVIRONMENT_WEB_ENABLE" == true ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-web"; fi)
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
      
EOL

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

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose-web.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-web:
    image: ${ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY}:${ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION}
    build:
      context: ${HOLLAEX_CLI_INIT_PATH}/web/
      dockerfile: ${HOLLAEX_CLI_INIT_PATH}/web/docker/Dockerfile
    restart: always
    deploy:
      resources:
        limits:
          cpus: "${ENVIRONMENT_WEB_CPU_LIMITS:-0.05}"
          $(echo memory: "${ENVIRONMENT_WEB_MEMORY_LIMITS:-128M}" | sed 's/i//g')
        reservations:
          cpus: "${ENVIRONMENT_WEB_CPU_LIMITS:-0.01}"
          $(echo memory: "${ENVIRONMENT_WEB_MEMORY_REQUESTS:-128M}" | sed 's/i//g')
    $(if [[ ! "$WEB_CLIENT_SCALE" ]]; then echo "ports:"; fi) 
      $(if [[ ! "$WEB_CLIENT_SCALE" ]]; then echo "- 8080:80"; fi) 
    networks:
      - $(if [[ "$HOLLAEX_NETWORK_LOCALHOST_MODE" ]]; then echo "local_hollaex-network-network"; else echo "local_${ENVIRONMENT_EXCHANGE_NAME}-network"; fi)

networks:
  $(if [[ "$HOLLAEX_NETWORK_LOCALHOST_MODE" ]]; then echo "local_hollaex-network-network:"; else echo "local_${ENVIRONMENT_EXCHANGE_NAME}-network:"; fi)
    external: true

EOL

}

function generate_hollaex_network_kubernetes_env_coins() {

# Generate Kubernetes Configmap
cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-env-coins.yaml <<EOL
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-env-coins
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
data:
  CURRENCIES: ${HOLLAEX_CONFIGMAP_CURRENCIES}
EOL

}

function generate_hollaex_network_kubernetes_env_pairs() {

# Generate Kubernetes Configmap
cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-env-pairs.yaml <<EOL
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-env-pairs
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
data:
  PAIRS: ${HOLLAEX_CONFIGMAP_PAIRS}
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

function ingress_tls_snippets() {

/bin/cat << EOF 

  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-tls-cert
    hosts:
    - $(echo $1 | cut -f3 -d "/")

EOF
  
}

function ingress_web_tls_snippets() {

/bin/cat << EOF 

  tls:
  - secretName: ${ENVIRONMENT_EXCHANGE_NAME}-web-tls-cert
    hosts:
    - $(echo $1 | cut -f3 -d "/")

EOF
  
}

function generate_kubernetes_ingress() {

if [[ -z "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" ]]; then 

  ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER=true

fi 

# Generate Kubernetes Secret
cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-ingress.yaml <<EOL
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "6m"
    #nginx.ingress.kubernetes.io/whitelist-source-range: ""
    nginx.ingress.kubernetes.io/server-snippet: |
        location @maintenance_503 {
          internal;
          return 503;
        }
    nginx.ingress.kubernetes.io/configuration-snippet: |
      limit_req zone=api burst=10 nodelay;
      limit_req_log_level notice;
      limit_req_status 429;

      #error_page 403 @maintenance_503;

spec:
  rules:
  - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
            port:
              number: 10010
  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-plugins
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    #nginx.ingress.kubernetes.io/whitelist-source-range: ""
    nginx.ingress.kubernetes.io/server-snippet: |
        location @maintenance_503 {
          internal;
          return 503;
        }
    nginx.ingress.kubernetes.io/proxy-body-size: "6m"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      #error_page 403 @maintenance_503;

spec:
  rules:
  - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
    http:
      paths:
      - pathType: Prefix
        path: /plugins
        backend:
          service:
            name: ${ENVIRONMENT_EXCHANGE_NAME}-server-plugins
            port:
              number: 10011
    
  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-plugins-sms-verify
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    #nginx.ingress.kubernetes.io/whitelist-source-range: ""
    nginx.ingress.kubernetes.io/server-snippet: |
        location @maintenance_503 {
          internal;
          return 503;
        }
    nginx.ingress.kubernetes.io/proxy-body-size: "6m"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      #error_page 403 @maintenance_503;
      limit_req zone=sms burst=10 nodelay;
      limit_req_log_level notice;
      limit_req_status 429;

spec:
  rules:
  - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
    http:
      paths:
      - pathType: Prefix
        path: /plugins/sms/verify
        backend:
          service:
            name: ${ENVIRONMENT_EXCHANGE_NAME}-server-plugins
            port:
              number: 10011
    
  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-stream
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    #nginx.ingress.kubernetes.io/whitelist-source-range: ""
    nginx.ingress.kubernetes.io/server-snippet: |
        location @maintenance_503 {
          internal;
          return 503;
        }
    nginx.ingress.kubernetes.io/proxy-body-size: "6m"
    nginx.org/websocket-services: "${ENVIRONMENT_EXCHANGE_NAME}-server-stream"
    nginx.ingress.kubernetes.io/upstream-hash-by: "\$binary_remote_addr"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      #error_page 403 @maintenance_503;
spec:
  rules:
  - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
    http:
      paths:
      - pathType: Prefix
        path: /stream
        backend:
          service:
            name: ${ENVIRONMENT_EXCHANGE_NAME}-server-stream
            port:
              number: 10080
  
  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)
EOL

}

function generate_kubernetes_ingress_for_web() { 

if [[ -z "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB" ]] || [[ ! "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB" == false ]]; then 

  ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB=true

fi

  # Generate Kubernetes Secret
cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-ingress-web.yaml <<EOL
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-web
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    #nginx.ingress.kubernetes.io/whitelist-source-range: ""
    nginx.ingress.kubernetes.io/configuration-snippet: |
      #error_page 403 @maintenance_503;
    nginx.ingress.kubernetes.io/server-snippet: |
        location @maintenance_503 {
          internal;
          return 503;
        }
    nginx.ingress.kubernetes.io/proxy-body-size: "6m"
spec:
  rules:
  - host: $(echo ${HOLLAEX_CONFIGMAP_DOMAIN} | cut -f3 -d "/")
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: ${ENVIRONMENT_EXCHANGE_NAME}-web
            port:
              number: 80
  
  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB" == true ]];then ingress_web_tls_snippets $HOLLAEX_CONFIGMAP_DOMAIN; fi)
EOL

}

# function generate_kubernetes_ingress() {

# if [[ -z "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" ]]; then 

#   ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER=true

# fi 

# # Generate Kubernetes Secret
# cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-ingress.yaml <<EOL
# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api
#   namespace: ${ENVIRONMENT_EXCHANGE_NAME}
#   annotations:
#     kubernetes.io/ingress.class: "nginx"
#     $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
#     $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
#     nginx.ingress.kubernetes.io/proxy-body-size: "6m"
#     nginx.ingress.kubernetes.io/configuration-snippet: |
#       limit_req zone=api burst=10 nodelay;
#       limit_req_log_level notice;
#       limit_req_status 429;
# spec:
#   rules:
#   - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
#     http:
#       paths:
#       - pathType: Prefix
#         path: /v2
#         backend:
#           service:
#             name: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
#             port:
#               number: 10010

#   $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)

# ---
# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api-order
#   namespace: ${ENVIRONMENT_EXCHANGE_NAME}
#   annotations:
#     kubernetes.io/ingress.class: "nginx"
#     $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
#     $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
#     nginx.ingress.kubernetes.io/proxy-body-size: "6m"
#     nginx.ingress.kubernetes.io/configuration-snippet: |
#       limit_req zone=api burst=10 nodelay;
#       limit_req_log_level notice;
#       limit_req_status 429;
# spec:
#   rules:
#   - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
#     http:
#       paths:
#       - pathType: Prefix
#         path: /v2/order
#         backend:
#           service:
#             name: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
#             port: 
#               number: 10010
  
#   $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)

# ---
# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api-admin
#   namespace: ${ENVIRONMENT_EXCHANGE_NAME}
#   annotations:
#     kubernetes.io/ingress.class: "nginx"
#     $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
#     $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
#     nginx.ingress.kubernetes.io/proxy-body-size: "6m"
# spec:
#   rules:
#   - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
#     http:
#       paths:
#       - pathType: Prefix
#         path: /v2/admin
#         backend:
#           service:
#             name: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
#             port:
#               number: 10010

#   $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)

    
# ---

# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-plugins
#   namespace: ${ENVIRONMENT_EXCHANGE_NAME}
#   annotations:
#     kubernetes.io/ingress.class: "nginx"
#     $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
#     $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
#     nginx.ingress.kubernetes.io/proxy-body-size: "6m"
# spec:
#   rules:
#   - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
#     http:
#       paths:
#       - pathType: Prefix
#         path: /plugins
#         backend:
#           service:
#             name: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
#             port: 
#               number: 10010
    
#   $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)

# ---
# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-stream
#   namespace: ${ENVIRONMENT_EXCHANGE_NAME}
#   annotations:
#     kubernetes.io/ingress.class: "nginx"
#     $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
#     $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
#     nginx.ingress.kubernetes.io/proxy-body-size: "6m"
#     nginx.org/websocket-services: "${ENVIRONMENT_EXCHANGE_NAME}-server-stream"
#     nginx.ingress.kubernetes.io/upstream-hash-by: "\$binary_remote_addr"
# spec:
#   rules:
#   - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
#     http:
#       paths:
#       - pathType: Prefix
#         path: /stream
#         backend:
#           service:
#             name: ${ENVIRONMENT_EXCHANGE_NAME}-server-stream
#             port: 
#               number: 10080
  
#   $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)

# EOL

# }

# function generate_kubernetes_ingress_for_web() { 

# if [[ -z "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB" ]] || [[ ! "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB" == false ]]; then 

#   ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB=true

# fi

#   # Generate Kubernetes Secret
# cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-ingress-web.yaml <<EOL

# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-web
#   namespace: ${ENVIRONMENT_EXCHANGE_NAME}
#   annotations:
#     kubernetes.io/ingress.class: "nginx"
#     $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
#     $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
#     nginx.ingress.kubernetes.io/proxy-body-size: "6m"

# spec:
#   rules:
#   - host: $(echo ${HOLLAEX_CONFIGMAP_DOMAIN} | cut -f3 -d "/")
#     http:
#       paths:
#       - pathType: Prefix
#         path: /
#         backend:
#           service:
#             name: ${ENVIRONMENT_EXCHANGE_NAME}-web
#             port:
#               number: 80
  
#   $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB" == true ]];then ingress_web_tls_snippets $HOLLAEX_CONFIGMAP_DOMAIN; fi)

# EOL

# }

function generate_random_values() {

  # Runs random.js through docker with latest compatible HollaEx Server (minimum 1.23.0)
  docker run --rm --entrypoint node $ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION tools/general/random.js
  
}

function update_random_values_to_config() {

GENERATE_VALUES_LIST=( "HOLLAEX_SECRET_SUPERVISOR_PASSWORD" "HOLLAEX_SECRET_SUPPORT_PASSWORD" "HOLLAEX_SECRET_KYC_PASSWORD" "HOLLAEX_SECRET_QUICK_TRADE_SECRET" "HOLLAEX_SECRET_SECRET" )

for j in ${CONFIG_FILE_PATH[@]}; do

  if command grep -q "HOLLAEX_SECRET" $j > /dev/null ; then

    SECRET_CONFIG_FILE_PATH=$j
    echo "Generating random secrets..."

    for k in ${GENERATE_VALUES_LIST[@]}; do

      grep -v $k $SECRET_CONFIG_FILE_PATH > temp && mv temp $SECRET_CONFIG_FILE_PATH
      #echo $SECRET_CONFIG_FILE_PATH

      # Using special form to generate both API_KEYS keys and secret
      if [[ "$k" == "HOLLAEX_SECRET_SECRET" ]]; then

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
    unset HOLLAEX_CONFIGMAP_VARIABLES
    unset HOLLAEX_SECRET_VARIABLES
    unset HOLLAEX_SECRET_VARIABLES_BASE64
    unset HOLLAEX_SECRET_VARIABLES_YAML
    unset HOLLAEX_CONFIGMAP_VARIABLES_YAML

    for i in ${CONFIG_FILE_PATH[@]}; do
          source $i
    done;

      #   load_config_variables;
    
    
    
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
      helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-server-engine-$TRADE_PARIS_DEPLOYMENT_NAME \
                   --namespace $ENVIRONMENT_EXCHANGE_NAME \
                   --set DEPLOYMENT_MODE="engine" \
                   --set PAIR="$TRADE_PARIS_DEPLOYMENT" \
                   --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                   --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                   --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                   --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                   --set resources.limits.cpu="${ENVIRONMENT_KUBERNETES_ENGINE_CPU_LIMITS:-500m}" \
                   --set resources.limits.memory="${ENVIRONMENT_KUBERNETES_ENGINE_MEMORY_LIMITS:-1024Mi}" \
                   --set resources.requests.cpu="${ENVIRONMENT_KUBERNETES_ENGINE_CPU_REQUESTS:-10m}" \
                   --set resources.requests.memory="${ENVIRONMENT_KUBERNETES_ENGINE_MEMORY_REQUESTS:-128Mi}" \
                   --set podRestart_webhook_url="$ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL" \
                   -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                   -f $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server/values.yaml $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server

    elif [[ "$1" == "scaleup" ]]; then
      
      #Scaling down queue deployments on Kubernetes
      kubectl scale deployment/$ENVIRONMENT_EXCHANGE_NAME-server-engine-$TRADE_PARIS_DEPLOYMENT_NAME --replicas=1 --namespace $ENVIRONMENT_EXCHANGE_NAME

    elif [[ "$1" == "scaledown" ]]; then
      
      #Scaling down queue deployments on Kubernetes
      kubectl scale deployment/$ENVIRONMENT_EXCHANGE_NAME-server-engine-$TRADE_PARIS_DEPLOYMENT_NAME --replicas=0 --namespace $ENVIRONMENT_EXCHANGE_NAME

    elif [[ "$1" == "terminate" ]]; then

      #Terminating
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-server-engine-$TRADE_PARIS_DEPLOYMENT_NAME

    fi

  done

}

function override_user_hollaex_core() {

  for i in ${CONFIG_FILE_PATH[@]}; do

    local ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY_OVERRIDE_PARSED=${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY_OVERRIDE//\//\\\/}

    if command grep -q "ENVIRONMENT_USER_HOLLAEX_CORE_" $i > /dev/null ; then
      CONFIGMAP_FILE_PATH=$i
      sed -i.bak "s/ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY=.*/ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY=$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY_OVERRIDE_PARSED/" $CONFIGMAP_FILE_PATH
      sed -i.bak "s/ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION=.*/ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION=$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION_OVERRIDE/" $CONFIGMAP_FILE_PATH
    fi
    
  done

  rm $CONFIGMAP_FILE_PATH.bak

}

function override_user_hollaex_web() {

  for i in ${CONFIG_FILE_PATH[@]}; do

    local ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY_OVERRIDE_PARSED=${ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY_OVERRIDE//\//\\\/}

    if command grep -q "ENVIRONMENT_USER_HOLLAEX_WEB_" $i > /dev/null ; then
      CONFIGMAP_FILE_PATH=$i
      sed -i.bak "s/ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY=.*/ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY=$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY_OVERRIDE_PARSED/" $CONFIGMAP_FILE_PATH
      sed -i.bak "s/ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION=.*/ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION=$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION_OVERRIDE/" $CONFIGMAP_FILE_PATH
    fi
    
  done

  rm $CONFIGMAP_FILE_PATH.bak

}

function override_docker_image_version() {

  for i in ${CONFIG_FILE_PATH[@]}; do

    if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
      CONFIGMAP_FILE_PATH=$i
      sed -i.bak "s/ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION=.*/ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION=$ENVIRONMENT_DOCKER_IMAGE_VERSION_OVERRIDE/" $CONFIGMAP_FILE_PATH
    fi
    
  done

  rm $CONFIGMAP_FILE_PATH.bak

}

function override_user_docker_tag() {

  for i in ${CONFIG_FILE_PATH[@]}; do

    if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
      CONFIGMAP_FILE_PATH=$i
      sed -i.bak "s/ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION=.*/ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION=$HOLLAEX_CORE_USER_APPLY_TAG/" $CONFIGMAP_FILE_PATH
    fi
    
  done

  rm $CONFIGMAP_FILE_PATH.bak

}

function override_user_docker_registry() {

  for i in ${CONFIG_FILE_PATH[@]}; do

    local ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY_PARSED=${ENVIRONMENT_USER_REGISTRY_OVERRIDE//\//\\\/}

    if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
      CONFIGMAP_FILE_PATH=$i
      sed -i.bak "s/ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY=.*/ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY=$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY_PARSED/" $CONFIGMAP_FILE_PATH 

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

function generate_hollaex_web_local_env() {

cat > $HOLLAEX_CLI_INIT_PATH/web/.env <<EOL

NODE_ENV=${HOLLAEX_CONFIGMAP_NODE_ENV}

REACT_APP_PUBLIC_URL=${HOLLAEX_CONFIGMAP_DOMAIN}
REACT_APP_SERVER_ENDPOINT=${HOLLAEX_CONFIGMAP_API_HOST}
REACT_APP_NETWORK=${HOLLAEX_CONFIGMAP_NETWORK}

REACT_APP_DEVELOPMENT_ENDPOINT=${HOLLAEX_CONFIGMAP_API_HOST}

REACT_APP_EXCHANGE_NAME=${ENVIRONMENT_EXCHANGE_NAME}

REACT_APP_CAPTCHA_SITE_KEY=${HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY:-$ENVIRONMENT_WEB_CAPTCHA_SITE_KEY}

REACT_APP_DEFAULT_LANGUAGE=${ENVIRONMENT_WEB_DEFAULT_LANGUAGE}
REACT_APP_DEFAULT_COUNTRY=${ENVIRONMENT_WEB_DEFAULT_COUNTRY}

REACT_APP_LOGO_PATH=${HOLLAEX_CONFIGMAP_LOGO_PATH}
REACT_APP_LOGO_BLACK_PATH=${HOLLAEX_CONFIGMAP_LOGO_BLACK_PATH}

REACT_APP_EXCHANGE_NAME='${HOLLAEX_CONFIGMAP_API_NAME}'

EOL
}

function generate_hollaex_web_local_nginx_conf() {

cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/web.conf <<EOL
server {
    listen 80;
    server_name hollaex.exchange; #Client domain
    access_log   /var/log/nginx/web.access.log;
        
    location / {
    proxy_pass      http://web;
    }

}

EOL
}


function generate_hollaex_web_configmap() {

cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-web-configmap.yaml <<EOL
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-web-env
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
data:
  PUBLIC_URL: ${HOLLAEX_CONFIGMAP_DOMAIN}
  REACT_APP_PUBLIC_URL: ${HOLLAEX_CONFIGMAP_API_HOST}
  REACT_APP_SERVER_ENDPOINT: ${HOLLAEX_CONFIGMAP_API_HOST}

  REACT_APP_NETWORK: ${HOLLAEX_CONFIGMAP_NETWORK}

  REACT_APP_CAPTCHA_SITE_KEY: ${HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY:-$ENVIRONMENT_WEB_CAPTCHA_SITE_KEY}

  REACT_APP_DEFAULT_LANGUAGE: ${ENVIRONMENT_WEB_DEFAULT_LANGUAGE}
  REACT_APP_DEFAULT_COUNTRY: ${ENVIRONMENT_WEB_DEFAULT_COUNTRY}

  REACT_APP_BASE_CURRENCY: usdt
  
EOL
}

function hollaex_ascii_exchange_is_up() {

  /bin/cat << EOF


                                      ,t:
                                    ,L@@@f.
                                  ,L@@@8f:
                                ,L@@@@f,
                              ,L@@@8f,
                            ,L@@@8f,
          :i              ,L@@@8f,
        .L@@Gi          ,L@@@8f,
        .10@@@Gi      ,L@@@8f,
          iG@@@Gi  ,L@@@8f,
            iG@@@GL@@@8f,
              iG@@@@8f,
                iG8f,
                  ,

            Your Exchange is up!
    Try to reach ${HOLLAEX_CONFIGMAP_API_HOST}/v2/health

    You can easily check the exchange status with 'hollaex status'.

    It could take a minute for the server to get fully ready.

    $(if [[ "$USE_KUBERNETES" ]]; then 
      if ! command helm ls --namespace $ENVIRONMENT_EXCHANGE_NAME | grep $ENVIRONMENT_EXCHANGE_NAME-web > /dev/null 2>&1; then 
        echo "You can proceed to setup the web server with 'hollaex web --setup --kube'." 
      fi 
    elif [[ ! "$USE_KUBERNETES" ]]; then 
      if ! command docker ps | grep $ENVIRONMENT_EXCHANGE_NAME-web > /dev/null 2>&1; then 
        echo "You can proceed to setup the web server with 'hollaex web --setup'." 
      fi 
    fi)

EOF

}

function hollaex_ascii_network_is_up() {

  /bin/cat << EOF


                                      ,t:
                                    ,L@@@f.
                                  ,L@@@8f:
                                ,L@@@@f,
                              ,L@@@8f,
                            ,L@@@8f,
          :i              ,L@@@8f,
        .L@@Gi          ,L@@@8f,
        .10@@@Gi      ,L@@@8f,
          iG@@@Gi  ,L@@@8f,
            iG@@@GL@@@8f,
              iG@@@@8f,
                iG8f,
                  ,

            Your Network is up!
    Try to reach ${HOLLAEX_CONFIGMAP_API_HOST}/v2/health

    You can easily check the network status with 'hollaex network --status'.

EOF

}

function hollaex_ascii_exchange_has_been_setup() {

  /bin/cat << EOF

                                  ,t:
                                ,L@@@f.
                              ,L@@@8f:
                            ,L@@@@f,
                          ,L@@@8f,
                        ,L@@@8f,
      :i              ,L@@@8f,
    .L@@Gi          ,L@@@8f,
    .10@@@Gi      ,L@@@8f,
      iG@@@Gi  ,L@@@8f,
        iG@@@GL@@@8f,
          iG@@@@8f,
            iG8f,
              ,

      Your Exchange has been setup!
                 
EOF

}

function hollaex_ascii_network_has_been_setup() {

  /bin/cat << EOF

                                  ,t:
                                ,L@@@f.
                              ,L@@@8f:
                            ,L@@@@f,
                          ,L@@@8f,
                        ,L@@@8f,
      :i              ,L@@@8f,
    .L@@Gi          ,L@@@8f,
    .10@@@Gi      ,L@@@8f,
      iG@@@Gi  ,L@@@8f,
        iG@@@GL@@@8f,
          iG@@@@8f,
            iG8f,
              ,

      Your Network has been setup!
                 
EOF

}

function hollaex_network_prod_complete() {

  /bin/cat << EOF

                      ......
                .;1LG088@@880GL1;.
            ,tC8@@@@@@@@@@@@@@@@8Ct,
          ;C@@@@GtL@@@8;;8@@@Lf0@@@@C;
        ,C@@@0t: ,8@@8:  :8@@0, :t8@@@L,
        i@@@0i   .8@@8,    :8@@0    18@@8;
      1@@@8t;;iiL@@@C;iiii;C@@@fii;;t@@@@i
      :@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@,
      C@@@LfffffG@@@GffffffffG@@@CfffffL@@@L
    .8@@G      f@@@;        ;@@@t      0@@0.
    ,@@@L .  . L@@@: .    . ;@@@L .  . C@@@,
    .8@@G      f@@@:        ;@@@t      G@@8.
      C@@@LfffffG@@@GffffffffG@@@CfffffL@@@L
      :@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@,
      1@@@81;;iiL@@@L;iiii;C@@@Lii;;t8@@@i
        i@@@0i   .8@@8,    ,8@@0    10@@8i
        :C@@@0t, ,8@@8:  :8@@8, :t0@@@C,
          iC@@@@GtL@@@8:;8@@@LtG@@@@C;
            :tG@@@@@@@@@@@@@@@@@@Gt,
                ,itLG088@@880GLt;.
                      ..,,..

    Your Network has been setup for production!

    Please run 'hollaex network --restart$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)'
    to apply the changes you made.

    Have fun <3!

EOF

}

function hollaex_network_prod_complete() {

  /bin/cat << EOF

                      ......
                .;1LG088@@880GL1;.
            ,tC8@@@@@@@@@@@@@@@@8Ct,
          ;C@@@@GtL@@@8;;8@@@Lf0@@@@C;
        ,C@@@0t: ,8@@8:  :8@@0, :t8@@@L,
        i@@@0i   .8@@8,    :8@@0    18@@8;
      1@@@8t;;iiL@@@C;iiii;C@@@fii;;t@@@@i
      :@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@,
      C@@@LfffffG@@@GffffffffG@@@CfffffL@@@L
    .8@@G      f@@@;        ;@@@t      0@@0.
    ,@@@L .  . L@@@: .    . ;@@@L .  . C@@@,
    .8@@G      f@@@:        ;@@@t      G@@8.
      C@@@LfffffG@@@GffffffffG@@@CfffffL@@@L
      :@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@,
      1@@@81;;iiL@@@L;iiii;C@@@Lii;;t8@@@i
        i@@@0i   .8@@8,    ,8@@0    10@@8i
        :C@@@0t, ,8@@8:  :8@@8, :t0@@@C,
          iC@@@@GtL@@@8:;8@@@LtG@@@@C;
            :tG@@@@@@@@@@@@@@@@@@Gt,
                ,itLG088@@880GLt;.
                      ..,,..

    Your Network has been setup for production!

    Please run 'hollaex network --restart$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)'
    to apply the changes you made.

    Have fun <3!

EOF

}


function hollaex_prod_complete() {

  /bin/cat << EOF

                      ......
                .;1LG088@@880GL1;.
            ,tC8@@@@@@@@@@@@@@@@8Ct,
          ;C@@@@GtL@@@8;;8@@@Lf0@@@@C;
        ,C@@@0t: ,8@@8:  :8@@0, :t8@@@L,
        i@@@0i   .8@@8,    :8@@0    18@@8;
      1@@@8t;;iiL@@@C;iiii;C@@@fii;;t@@@@i
      :@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@,
      C@@@LfffffG@@@GffffffffG@@@CfffffL@@@L
    .8@@G      f@@@;        ;@@@t      0@@0.
    ,@@@L .  . L@@@: .    . ;@@@L .  . C@@@,
    .8@@G      f@@@:        ;@@@t      G@@8.
      C@@@LfffffG@@@GffffffffG@@@CfffffL@@@L
      :@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@,
      1@@@81;;iiL@@@L;iiii;C@@@Lii;;t8@@@i
        i@@@0i   .8@@8,    ,8@@0    10@@8i
        :C@@@0t, ,8@@8:  :8@@8, :t0@@@C,
          iC@@@@GtL@@@8:;8@@@LtG@@@@C;
            :tG@@@@@@@@@@@@@@@@@@Gt,
                ,itLG088@@880GLt;.
                      ..,,..

    Your Exchange has been setup for production!

    Please run 'hollaex server --restart$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)' and 'hollaex web --build' with 'hollaex web --apply --tag <YOUR_TAG>'
    to apply the changes you made.

    For the web, You should rebuild the Docker image to apply the changes.

    Have fun <3!

EOF

}

function hollaex_ascii_exchange_has_been_stopped() {

  /bin/cat << EOF

                    ,,,,
                    8@@8
                    8@@8
          10C;       8@@8      .;C0i
        :G@@@G,      8@@8      ,G@@@G,
      ;@@@8i        8@@8        i8@@8;
      :@@@0,         8@@8         :8@@8,
      G@@@:          8@@8          ;@@@C
    ,@@@C           0@@0           G@@@,
    ;@@@f           @@@@           L@@@:
    ,@@@C           1111           G@@8.
      C@@@:                        ;@@@C
      :@@@0,                      :8@@8,
      ;@@@8i                    i8@@8;
        :G@@@Ci.              .iG@@@G:
          10@@@0Li:.      .:iL0@@@01
          .iC8@@@@@00GG08@@@@@8L;
              .;tLG8@@@@@@8GLt;.
                  ..,,,...

        Your Exchange has been stopped
  $(if [[ "$IS_HOLLAEX_SETUP" ]]; then echo "Now It's time to bring up the exchange online."; fi)
    Run 'hollaex server --start$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)' to start the exchange.
          
EOF

}

function hollaex_ascii_network_has_been_stopped() {

  /bin/cat << EOF

                    ,,,,
                    8@@8
                    8@@8
          10C;       8@@8      .;C0i
        :G@@@G,      8@@8      ,G@@@G,
      ;@@@8i        8@@8        i8@@8;
      :@@@0,         8@@8         :8@@8,
      G@@@:          8@@8          ;@@@C
    ,@@@C           0@@0           G@@@,
    ;@@@f           @@@@           L@@@:
    ,@@@C           1111           G@@8.
      C@@@:                        ;@@@C
      :@@@0,                      :8@@8,
      ;@@@8i                    i8@@8;
        :G@@@Ci.              .iG@@@G:
          10@@@0Li:.      .:iL0@@@01
          .iC8@@@@@00GG08@@@@@8L;
              .;tLG8@@@@@@8GLt;.
                  ..,,,...

        Your Network has been stopped
  $(if [[ "$IS_HOLLAEX_SETUP" ]]; then echo "Now It's time to bring up the exchange online."; fi)
    Run 'hollaex network --start$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)' to start the exchange.
          
EOF

}


function hollaex_ascii_network_has_been_terminated() {

  /bin/cat << EOF

            .           .,,,,.
          100t.    ,1LG8@@@@@@0Cfi,
        .t8@@8t.  ,L@@@8GGG08@@@@8Ci
          .10@@8t.  ,;,      ,;f0@@@G;
            .;C@@@0t.            .i0@@@1
        ,1C8@@@@@@@@0t.            .G@@@i
      ,L@@@@0CLffff0@@0t.           .8@@8i:,
    1@@@8t:       .10@@0t.          L@@@@@@0L;
    ;@@@G,           .10@@8t.        :tttfC8@@@G:
    0@@8,              .10@@0t.            .18@@8:
    @@@0                 .10@@0t.            :@@@G
    G@@@:                  .10@@0t.           0@@@
    :@@@0:                   .10@@8t.        i@@@C
    ;8@@@L;.                   10@@8t.    :C@@@0.
      .f8@@@@0GGGGGGGGGGGGGGGGGCCG@@@@8t.  ,L@@f.
        .ifG8@@@@@@@@@@@@@@@@@@@@@@@@@@@0t.  ,,
            .,,,,,,,,,,,,,,,,,,,,:::::10@@8t.
                                      .10Gi
                                        .  .

            Your Network has been terminated.
    Run 'hollaex network --setup$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)' to setup the exchange from a scratch.
                 

EOF

}

function hollaex_ascii_exchange_has_been_terminated() {

  /bin/cat << EOF

            .           .,,,,.
          100t.    ,1LG8@@@@@@0Cfi,
        .t8@@8t.  ,L@@@8GGG08@@@@8Ci
          .10@@8t.  ,;,      ,;f0@@@G;
            .;C@@@0t.            .i0@@@1
        ,1C8@@@@@@@@0t.            .G@@@i
      ,L@@@@0CLffff0@@0t.           .8@@8i:,
    1@@@8t:       .10@@0t.          L@@@@@@0L;
    ;@@@G,           .10@@8t.        :tttfC8@@@G:
    0@@8,              .10@@0t.            .18@@8:
    @@@0                 .10@@0t.            :@@@G
    G@@@:                  .10@@0t.           0@@@
    :@@@0:                   .10@@8t.        i@@@C
    ;8@@@L;.                   10@@8t.    :C@@@0.
      .f8@@@@0GGGGGGGGGGGGGGGGGCCG@@@@8t.  ,L@@f.
        .ifG8@@@@@@@@@@@@@@@@@@@@@@@@@@@0t.  ,,
            .,,,,,,,,,,,,,,,,,,,,:::::10@@8t.
                                      .10Gi
                                        .  .

            Your Exchange has been terminated.
    Run 'hollaex server --setup$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)' to setup the exchange from a scratch.
                 

EOF

}

function hollaex_ascii_network_has_been_upgraded() {
 /bin/cat << EOF

              .,:::,.
          ,1L08@@@@@@@80Li,
        .10@@0fi:,..,:;1L0@@G1.
      .t@@Gi.  ,1tL:      .10@81
    :0@G;     1@@@8:.   .;  i8@G,
    :@@f      ;C@@@@@8GfC8@8i .C@8,
  .8@L  fLftG@@@8GG0@@@@@@0i   G@0.
  t@8, i@@@@@@0i.   .1G0GC     ,GG:
  C@G  .;f8@@@:        .i;;;, ,;;;;  :;;;:
  C@G     t@@@;       : t@@@8;.C@@@G.:8@@@f
  1@@,    ;@@@81,. .:f@C.i8@@@i t@@@0, C@@@C.
  .0@C  .f@@@@@@@808@@@@1 :0@@@t 1@@@@; f@@@0,
    ,8@C. i0@0ftC0@@@@@t,   ,8@@@t 1@@@@; L@@@8.
    ,G@8i  ,     ,8@@@:   ,G@@@L ;0@@@1 t@@@8;
      10@8t,      :ti;.  :0@@@t i@@@8; f@@@G,
        iC@@8Cf1;;::;i: 1@@@@i L@@@0:,0@@@C.
          .;tC08@@@@@f..1111: ,1111. ;111i
                .....

    The new image has been successfully applied on the network server!
    Try to reach $HOLLAEX_CONFIGMAP_API_HOST.

EOF
}

function hollaex_ascii_exchange_has_been_upgraded() {
 /bin/cat << EOF

              .,:::,.
          ,1L08@@@@@@@80Li,
        .10@@0fi:,..,:;1L0@@G1.
      .t@@Gi.  ,1tL:      .10@81
    :0@G;     1@@@8:.   .;  i8@G,
    :@@f      ;C@@@@@8GfC8@8i .C@8,
  .8@L  fLftG@@@8GG0@@@@@@0i   G@0.
  t@8, i@@@@@@0i.   .1G0GC     ,GG:
  C@G  .;f8@@@:        .i;;;, ,;;;;  :;;;:
  C@G     t@@@;       : t@@@8;.C@@@G.:8@@@f
  1@@,    ;@@@81,. .:f@C.i8@@@i t@@@0, C@@@C.
  .0@C  .f@@@@@@@808@@@@1 :0@@@t 1@@@@; f@@@0,
    ,8@C. i0@0ftC0@@@@@t,   ,8@@@t 1@@@@; L@@@8.
    ,G@8i  ,     ,8@@@:   ,G@@@L ;0@@@1 t@@@8;
      10@8t,      :ti;.  :0@@@t i@@@8; f@@@G,
        iC@@8Cf1;;::;i: 1@@@@i L@@@0:,0@@@C.
          .;tC08@@@@@f..1111: ,1111. ;111i
                .....

    The new image has been successfully applied on the exchange!
    Try to reach $HOLLAEX_CONFIGMAP_API_HOST.

EOF
}

function kubernetes_set_backend_image_target() {

    # $1 DOCKER REGISTRY
    # $2 DOCKER TAG
    # $3 NODEPORT ENABLE
    # $4 NODEPORT PORT NUMBER

    # $1 is_influxdb
    # $2 image.repo
    # $3 image.tag

  
    
        if [[ "$1" ]] && [[ "$2" ]]; then
            echo "--set imageRegistry=$1 --set dockerTag=$2"
        fi

    

}

function set_nodeport_access() {

    if [[ "$1" == true ]] && [[ "$2" ]]; then
        echo "--set NodePort.enable='true' --set NodePort.port=$4"
    fi

}

function hollaex_network_setup_finalization() {

  echo "*********************************************"
  printf "\n"
  echo "Your exchange is all set!"
  # echo "You can proceed to add your own currencies, trading pairs right away from now on."

  # echo "Attempting to add user custom currencies automatically..."

  # if [[ "$USE_KUBERNETES" ]]; then

  #     if [[ "$HOLLAEX_DEV_FOR_CORE" ]]; then

  #       hollaex network --add_coin --kube --is_hollaex_setup

  #     else

  #       hollaex network --add_coin --kube --is_hollaex_setup 

  #     fi
  
  # elif [[ ! "$USE_KUBERNETES" ]]; then

  #      if [[ "$HOLLAEX_DEV_FOR_CORE" ]]; then

  #       hollaex network --add_coin --is_hollaex_setup

  #     else

  #       hollaex network --add_coin --is_hollaex_setup 

  #     fi

  # fi

  # echo "Attempting to add user custom trading pairs automatically..."

  # if [[ "$USE_KUBERNETES" ]]; then

  #     if [[ "$HOLLAEX_DEV_FOR_CORE" ]]; then

  #       hollaex network --add_trading_pair --kube --is_hollaex_setup

  #     else 

  #       hollaex network --add_trading_pair --kube --is_hollaex_setup

  #     fi

  # elif [[ ! "$USE_KUBERNETES" ]]; then

  #     if [[ "$HOLLAEX_DEV_FOR_CORE" ]]; then

  #       hollaex network --add_trading_pair --is_hollaex_setup

  #     else 

  #       hollaex network --add_trading_pair --is_hollaex_setup

  #     fi

  # fi

  if [[ ! "$HOLLAEX_DEV_SETUP" ]]; then

    printf "\033[93m\nFinishing the setup process...\033[39m\n"
    printf "\033[93mShutting down the network...\033[39m\n"
    printf "\033[93mTo start the network, Please use 'hollaex network --start$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)' command\033[39m\n\n"
    if [[ "$USE_KUBERNETES" ]]; then
        hollaex network --stop --kube --skip --is_hollaex_setup
    elif [[ ! "$USE_KUBERNETES" ]]; then
        hollaex network --stop --skip --is_hollaex_setup
    fi
  
  fi

}


function hollaex_setup_finalization() { 


  echo "*********************************************"
  printf "\n"
  echo "Your exchange is all set!"

  if [[ ! "$HOLLAEX_DEV_SETUP" ]]; then

    printf "\033[93m\nFinishing the setup process...\033[39m\n"
    printf "\033[93mShutting down the exchange...\033[39m\n"
    printf "\033[93mTo start the exchange, Please use 'hollaex start$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)' command\033[39m\n\n"
    if [[ "$USE_KUBERNETES" ]]; then
        hollaex stop --kube --skip --is_hollaex_setup
    elif [[ ! "$USE_KUBERNETES" ]]; then
        hollaex stop --skip --is_hollaex_setup
    fi
  
  fi

}

function build_user_hollaex_core() {

  # Preparing HollaEx Server image with custom mail configurations
  echo "Building the user HollaEx Server image with user custom Kit setups."

  if command docker build -t $ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION -f $HOLLAEX_CLI_INIT_PATH/Dockerfile $HOLLAEX_CLI_INIT_PATH; then

      echo "Your custom HollaEx Server image has been successfully built."

      if [[ "$USE_KUBERNETES" ]]; then

        echo "Info: Deployment to Kubernetes mandatorily requires image to gets pushed on your Docker registry."

      fi

      if [[ "$RUN_WITH_VERIFY" == true ]]; then
        
          echo "Please type in your new image name. ($ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION)"
          echo "Press enter to proceed with the previous name."
          read tag

          export ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY_OVERRIDE=$(echo ${tag:-$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY} | cut -f1 -d ":")
          export ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION_OVERRIDE=$(echo ${tag:-$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION} | cut -f2 -d ":")

          echo "Do you want to proceed with this image name? ($ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY_OVERRIDE:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION_OVERRIDE) (Y/n)"
          read answer

          while true;
          do if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
            echo "Please type in your new image name. ($ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION)"
            echo "Press enter to proceed with the previous name."
            read tag
            export ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY_OVERRIDE=$(echo ${tag:-$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY} | cut -f1 -d ":")
            export ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION_OVERRIDE=$(echo ${tag:-$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION} | cut -f2 -d ":")
            echo "Do you want to proceed with this image name? ($ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY_OVERRIDE:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION_OVERRIDE) (Y/n)"
            read answer
          else
            break;
          fi
        done
        
      else 

        export ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY_OVERRIDE=$(echo ${tag:-$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY} | cut -f1 -d ":")
        export ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION_OVERRIDE=$(echo ${tag:-$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION} | cut -f2 -d ":")

      fi 

      if [[ "$IS_HOLLAEX_SETUP" ]]; then

        override_user_hollaex_core;
      
      fi

      docker tag $ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION $ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY_OVERRIDE:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION_OVERRIDE

      export ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY=$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY_OVERRIDE
      export ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION=$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION_OVERRIDE

      echo "Your new image name is: ($ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION)."
      
      if [[ "$RUN_WITH_VERIFY" == true ]] && [[ ! "$USE_KUBERNETES" ]]; then 

          echo "Do you want to push this image to your Docker Registry? (y/N) (Optional)"
          read pushAnswer
          
          if [[ "$pushAnswer" = "${pushAnswer#[Yy]}" ]] ;then

            echo "Skipping..."
            echo "Your image name: $ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION."
            echo "You can later tag and push it by using 'docker tag' and 'docker push' command manually."

          else 

            push_user_hollaex_core;        
            
          fi

      else 

        echo "Pushing the built image to the Docker Registry..."

        push_user_hollaex_core;
      
      fi

  else 

      printf "\033[91mFailed to build the image.\033[39m\n"
      echo "Please confirm your configurations and try again."
      echo "If you are not on a latest HollaEx Kit, Please update it first to latest."
      
      exit 1;
  
  fi  
  
}

function push_user_hollaex_core() {

  echo "Pushing the image to docker registry..."

  if command docker push $ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION; then 

      printf "\033[92mSuccessfully pushed the image to docker registry.\033[39m\n"
  
  else 

      printf "\033[91mFailed to push the image to docker registry.\033[39m\n"

      if [[ ! "$USE_KUBERNETES" ]]; then

          echo "Proceeding setup processes without pushing the image at Docker Registry."
          echo "You can push it later by using 'docker push' command manually."
  
      else

          printf "\033[93mHollaEx Kit deployment for Kubernetes requires user's HollaEx Server image pushed at Docker Registry.\033[39m\n"
          echo "Plesae try again after you confirm the image name is correct, and got proper Docker Registry access."
          exit 1;

      fi
  
  fi

}

function build_user_hollaex_web() {

  # Preparing HollaEx Server image with custom mail configurations
  echo "Building the user HollaEx Web image."

  if [[ ! "$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY" ]] || [[ ! "$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION" ]]; then

    echo "Error: Your 'ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY' or 'ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION' is missing!"
    echo "Please make sure you got latest HollaEx Kit first, and check your Configmap file at HollaEx Kit directory."
    exit 1;
  
  fi

  echo "Generating .env for Web Client"
  generate_hollaex_web_local_env

  if command docker build -t $ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION -f $HOLLAEX_CLI_INIT_PATH/web/docker/Dockerfile $HOLLAEX_CLI_INIT_PATH/web; then

      echo "Your custom HollaEx Web image has been successfully built."

      if [[ "$RUN_WITH_VERIFY" == true ]]; then 

        echo "Please type in your new image name. ($ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION)"
        echo "Press enter to proceed with the previous name."
        read tag

        export ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY_OVERRIDE=$(echo ${tag:-$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY} | cut -f1 -d ":")
        export ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION_OVERRIDE=$(echo ${tag:-$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION} | cut -f2 -d ":")

        echo "Do you want to proceed with this image name? ($ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY_OVERRIDE:$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION_OVERRIDE) (Y/n)"
        read answer

        while true;
        do if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
          echo "Please type in your new image name. ($ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION)"
          echo "Press enter to proceed with the previous name."
          read tag
          export ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY_OVERRIDE=$(echo ${tag:-$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY} | cut -f1 -d ":")
          export ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION_OVERRIDE=$(echo ${tag:-$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION} | cut -f2 -d ":")
          echo "Do you want to proceed with this image name? ($ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY_OVERRIDE:$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION_OVERRIDE) (Y/n)"
          read answer
        else
          break;
        fi
      done


    
      else 

        export ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY_OVERRIDE=$(echo ${tag:-$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION} | cut -f1 -d ":")
        export ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION_OVERRIDE=$(echo ${tag:-$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION} | cut -f2 -d ":")

      fi 

      if [[ "$OVERRIDE_THE_WEB_IMAGE_TAG" ]]; then 

        override_user_hollaex_web;
      
      fi

      docker tag ${ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY}:${ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION} ${ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY_OVERRIDE}:${ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION_OVERRIDE}

      export ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY=$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY_OVERRIDE
      export ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION=$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION_OVERRIDE

      echo "Your new image name is: $ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION."

      if [[ "$RUN_WITH_VERIFY" == true ]] && [[ ! "$USE_KUBERNETES" ]]; then 
        
        echo "Do you want to push this image to your Docker Registry? (y/N)"

        read answer
      
        if [[ "$answer" = "${answer#[Yy]}" ]] ;then

          echo "Skipping..."
          echo "Your current image name: $ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION."
          echo "You can later tag and push it by using 'docker tag' and 'docker push' command manually."
        
        else

          echo "Pushing the built image to the Docker Registry..."
          push_user_hollaex_web;
        
        fi
        
      else 

        echo "Pushing the built image to the Docker Registry..." 
        push_user_hollaex_web;
      
      fi

  else 

      echo "Failed to build the image."
      echo "Please confirm your configurations and try again."
      echo "If you are not on a latest HollaEx Kit, Please update it first to latest."
      
      exit 1;
  
  fi  

}

function push_user_hollaex_web() {

  echo "Pushing the image to docker registry..."

  if command docker push $ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION; then 

      echo "Successfully pushed the image to docker registry."
  
  else 

      echo "Failed to push the image to docker registry."

      if [[ ! $USE_KUBERNETES ]]; then

          echo "Proceeding setup processes without pushing the image at Docker Registry."
          echo "You can push it later by using 'docker push' command manually."
  
      else

          echo "HollaEx Kit deployment for Kubernetes requires user's HollaEx Server image pushed at Docker Registry."
          echo "Plesae try again after you confirm the image name is correct, and got proper Docker Registry access."
          exit 1;

      fi
  
  fi
  
}

function hollaex_ascii_web_server_is_up() {

      /bin/cat << EOF

                                      ,t:
                                    ,L@@@f.
                                  ,L@@@8f:
                                ,L@@@@f,
                              ,L@@@8f,
                            ,L@@@8f,
          :i              ,L@@@8f,
        .L@@Gi          ,L@@@8f,
        .10@@@Gi      ,L@@@8f,
          iG@@@Gi  ,L@@@8f,
            iG@@@GL@@@8f,
              iG@@@@8f,
                iG8f,
                  ,

  Web Client for your exchange is ready!
  Try to reach $(if [[ ! "$HOLLAEX_CONFIGMAP_DOMAIN" == *"example.com" ]]; then echo "$HOLLAEX_CONFIGMAP_DOMAIN"; fi) $(if [[ ! "$HOLLAEX_CONFIGMAP_DOMAIN" == *"example.com" ]] && [[ ! "$USE_KUBERNETES" ]]; then echo "or"; fi) $(if [[ ! "$USE_KUBERNETES" ]]; then echo "localhost:8080"; fi)

EOF

}

function hollaex_ascii_web_server_has_been_setup() {

      /bin/cat << EOF

                                        ,t:
                                      ,L@@@f.
                                    ,L@@@8f:
                                  ,L@@@@f,
                                ,L@@@8f,
                              ,L@@@8f,
            :i              ,L@@@8f,
          .L@@Gi          ,L@@@8f,
          .10@@@Gi      ,L@@@8f,
            iG@@@Gi  ,L@@@8f,
              iG@@@GL@@@8f,
                iG@@@@8f,
                  iG8f,
                    ,

  Web Server for your exchange has been setup and prepared.
  Please run 'hollaex web --start $(if [[ "$USE_KUBERNETES" ]]; then echo "--kube"; fi)' to bring the web server up!

EOF

}

function docker_registry_login() {

  if [[ ! "$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME" ]] || [[ ! "$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD" ]] || [[ ! "$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL" ]] || [[ "$MANUAL_DOCKER_REGISTRY_SECRET_UPDATE" ]] ; then

    echo "[1/4] Docker registry host ($ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_HOST):"
    read host

    ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_HOST_OVERRIDE=${host:-$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_HOST}

    echo "[2/4] Docker registry username ($ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME):"
    read username
        
    ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME_OVERRIDE=${username:-$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME}


    echo "[3/4] Docker registry password ($ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD):"
    read -s password
    printf "\n"

    ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD_OVERRIDE=${password:-$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD}

    echo "[4/4] Docker registry email ($ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL):"
    read email

    ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL_OVERRIDE=${email:-$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL}

    echo "***************************************************************"
    echo "Registry Host: $ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_HOST_OVERRIDE"
    echo "Username: $ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME_OVERRIDE"
    echo "Password: $(echo ${ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD_OVERRIDE//?/◼︎}$(echo $ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD_OVERRIDE | grep -o '....$'))"
    echo "Email: $ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL_OVERRIDE"
    echo "***************************************************************"

    echo "Are you sure you want to proceed with this credentials? (Y/n)"
    read answer

    # if [[ ! "$answer" = "${answer#[Nn]}" ]] ;then
    #     echo "HollaEx requires docker registry secret for running."
    #     echo "Please try it again."
    #     docker_registry_login;
    # fi

    while true;
      do if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
        echo "HollaEx requires docker registry secret for running."
        echo "Please try it again."
        docker_registry_login
      else
        break;
      fi
    done

    export ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_HOST=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_HOST_OVERRIDE
    export ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME_OVERRIDE
    export ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD_OVERRIDE
    export ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL_OVERRIDE

    override_kubernetes_docker_registry_secret;
  
  fi

}

function create_kubernetes_docker_registry_secret() {

  docker_registry_login

  echo "Creating Docker registry secret on $ENVIRONMENT_EXCHANGE_NAME namespace."
  kubectl create secret docker-registry docker-registry-secret \
                        --namespace $ENVIRONMENT_EXCHANGE_NAME \
                        --docker-server=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_HOST \
                        --docker-username=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME \
                        --docker-password=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD \
                        --docker-email=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL

}

function override_kubernetes_docker_registry_secret() {

  for i in ${CONFIG_FILE_PATH[@]}; do

    local ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_HOST_OVERRIDE_PARSED=${ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_HOST_OVERRIDE//\//\\\/}
    local ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME_OVERRIDE_PARSED=${ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME_OVERRIDE//\//\\\/}
    local ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD_OVERRIDE_PARSED=${ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD_OVERRIDE//\//\\\/}
    local ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL_OVERRIDE_PARSED=${ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL_OVERRIDE//\//\\\/}

    if command grep -q "ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_" $i > /dev/null ; then
      SECRET_FILE_PATH=$i
      sed -i.bak "s/ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_HOST=.*/ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_HOST=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_HOST_OVERRIDE_PARSED/" $SECRET_FILE_PATH
      sed -i.bak "s/ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME=.*/ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME_OVERRIDE_PARSED/" $SECRET_FILE_PATH
      sed -i.bak "s/ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD=.*/ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD_OVERRIDE_PARSED/" $SECRET_FILE_PATH
      sed -i.bak "s/ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL=.*/ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL_OVERRIDE_PARSED/" $SECRET_FILE_PATH
    fi
    
  done

  rm $SECRET_FILE_PATH.bak

}

function hollaex_ascii_coin_has_been_added() {

  /bin/cat << EOF

                                  
           f888888G              .,:;ii;,
           C@L,,i@8.         :tC08@88888@8Ci
           L@f  :@0        L8@0L1:,.   .,iG@Gi
    ,::::::C@L  ;@8::::::,.i1,             t@@0i
   :@@88888881  ,0888888@@t                 0@8@0i
   ;@0                  f@f                 0@i:0@f
   ;@@ttttt11,  .i1tttttG@L                :@@@f;8@;
   ,LCCGGGG8@f  ;@@GGGGGCL;                C@f1@@8@f
           f@f  ;@0                       f@@t  1@@t
           f@t  :@0.                     f@GL@@1;@@,
           L@0LLG@8                    ,G@8, ,L@@@f
           :ffffffi                  .t@@L@@t  G@C
              i1                   .18@G. ,L@00@L
             .@@;                ,t8@C0@L:  t@@1
              1@0,            :t0@@0, .10@LG@C:
               18@Li,,.,,:ifG8@0tiC@01  i@@0i
                .t@@@808@@@GfC@0;  :C@08@Gi
                  .t8@C;;C8L, ,L@01t0@8f:
                    .t8@Cf0@@GfC@@@Gf:
                      .;tLCCCCLfi:.

          Coin $COIN_CODE has been successfully added (activated).
          Please run 'hollaex network --restart$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)' to activate it.

EOF

}

function hollaex_ascii_pair_has_been_added() {

   /bin/cat << EOF
  
                .::::,.                 .:;;;:.
            .,;i1111111i:.           ,;1tffffff1;,.
          .:i1t111tttt111tt1;.    .:i1tfftt111tfffft1:.
      ,;1tttttttffffffft1;,.  ,;ittfttt11111111ttffLLft;,
    :tfftttttffft1ii11;,   ,;1ttttttt1111i;;;i1111ttffLLLt:
    :ffttttttt1i:.      .:i1ttttttt1111i:.     .,;11111tffff,
    ;ftftttt1,      .,;1ttttttttttt1;,   .:i11;,   :1111tfff;
    ;ffft111.    .:i11t11ttttttt1;,   ,;1ttttttt1;  ,111tfff;
    ;fff111i  .;i111111tttttti:.  .,i1tttttt111111.  i11tfff;
    ;fff111i  .1111tttttt1i,   .:i1ttttt111111i:,   .111tfff;
    ;fff1111;  .:1tfft1;,   ,;i1tttttttttt1i:.     .;t11tfff;
    ;Lfft1111i:.   ,,.   ,;11tttttttttt1;,       ,;1tttttttf:
    .1LLfftt1111i;,..,:i1111ttttttt1i:.  .,,,,:i1tfttttttffi
      :1fLLfftt11111111111tttttt1;,.  .;1ffffffffttttttt1i:
        .:itfLfftt11111ttfffti:,   .;1tttttffftt11tt1i;,
            ,;1tfffftffft1i:.       .:;i1111111111;:.
              .:i1tt11;,               ,:ii1ii;,

      Trading Pair ${PAIR_CODE} has been successfully added (activated).
      Please run 'hollaex network --restart$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)' to activate it.

EOF
}

function hollaex_ascii_think_emoji() {

   /bin/cat << EOF
                  ..,,,,..
            .:itttt1111tttti:.
          ;tf1;,.        .,;1ft;
        1L1:                  :1L1
      :Ct.   .ii:               .tC:
     iG:  . ,8@@@t      .1CCt. .  :Gi
    ;0. .   .C880i      ;@@@@t . . .0;
   .0: .      ,,.       .1LCt.    . :0.
   1C .          .....             . C1
 . Lt    .i:  ,tttttttt1:          . tL .
 . Lt .  G1G; ,,.     .:fi         . tL .
   iC . LL C1   .,:;;:.  .         . Ci
    0; fC ,8t1tt11ii1GL .         . ;0.
    :GLL  .;:,. ,i111;.          . ,0:
     ;@  .      Cf..              ;G;
    . Ct        ;G              ,fC,
      .Lf;,....,fL           .:tLi
        :i1tLGGfi.      .,:itft:
             ,;i1ttttttttt1i:.
                  ......
EOF
}

function update_hollaex_cli_to_latest() { 
  
  echo "Checking for a newer version of HollaEx CLI is available..."
  LATEST_HOLLAEX_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/bitholla/hollaex-cli/master/version)

  local LATEST_HOLLAEX_CLI_VERSION_PARSED=${LATEST_HOLLAEX_CLI_VERSION//./}
  
  local CURRENT_HOLLAEX_CLI_VERSION=$(cat $SCRIPTPATH/version)
  local CURRENT_HOLLAEX_CLI_VERSION_PARSED=${CURRENT_HOLLAEX_CLI_VERSION//./}

  local CURRENT_HOLLAEX_CLI_MAJOR_VERSION=$(echo $CURRENT_HOLLAEX_CLI_VERSION_PARSED | head -c 1)
  local LATEST_HOLLAEX_CLI_MAJOR_VERSION=$(echo $LATEST_HOLLAEX_CLI_VERSION_PARSED | head -c 1)

  if (( $LATEST_HOLLAEX_CLI_MAJOR_VERSION >= $CURRENT_HOLLAEX_CLI_MAJOR_VERSION )) && (( $LATEST_HOLLAEX_CLI_VERSION_PARSED > $CURRENT_HOLLAEX_CLI_VERSION_PARSED )); then

      printf "\033[93m\nNewer version of HollaEx CLI has been detected.\033[39m\n"
      printf "\nLatest version of HollaEx CLI : \033[92m$LATEST_HOLLAEX_CLI_VERSION\033[39m"
      printf "\nCurrent installed version of HollaEx CLI : \033[93m$(cat $SCRIPTPATH/version)\033[39m\n\n"
     
      echo "Upgrading HollaEx CLI to latest..."
      curl -L https://raw.githubusercontent.com/bitholla/hollaex-cli/master/install.sh | bash;
      printf "\nPlease run 'hollaex upgrade' again to proceed upgrading your exchange.\n"

      exit 0;

  else 

      printf "\nLatest version of HollaEx CLI : \033[92m$LATEST_HOLLAEX_CLI_VERSION\033[39m"
      printf "\nCurrent installed version of HollaEx CLI : \033[92m$(cat $SCRIPTPATH/version)\033[39m\n"
      printf "\n\033[92mYour HollaEx CLI is already up to date!\033[39m\n\n"
      printf "Proceeding to upgrade...\n"

  fi

}

function update_activation_code_input() {
  # Activation Code
  echo "***************************************************************"
  echo "Activation Code: ($(echo ${HOLLAEX_SECRET_ACTIVATION_CODE//?/◼︎}$(echo $HOLLAEX_SECRET_ACTIVATION_CODE | grep -o '....$')))"
  printf "\033[2m- Go to https://dash.hollaex.com to issue your activation code.\033[22m\n" 
  read answer

  local EXCHANGE_ACTIVATION_CODE_OVERRIDE=${answer:-$HOLLAEX_SECRET_ACTIVATION_CODE}

  local EXCHANGE_ACTIVATION_CODE_MASKED=$(echo ${EXCHANGE_ACTIVATION_CODE_OVERRIDE//?/◼︎}$(echo $EXCHANGE_ACTIVATION_CODE_OVERRIDE | grep -o '....$'))

  printf "\n"
  echo "$EXCHANGE_ACTIVATION_CODE_MASKED ✔"
  printf "\n"

  echo "***************************************************************"
  echo "Activation Code: $EXCHANGE_ACTIVATION_CODE_MASKED"
  echo "***************************************************************"

  echo "Is the value all correct? (Y/n)"
  read answer

  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then

      echo "You picked false. Please confirm the values and run the command again."
      exit 1;
  
  fi

  echo "Provided value would be updated on your settings file(s) automatically."

  for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "HOLLAEX_SECRET_ACTIVATION_CODE" $i > /dev/null ; then
          SECRET_FILE_PATH=$i
          sed -i.bak "s/HOLLAEX_SECRET_ACTIVATION_CODE=$HOLLAEX_SECRET_ACTIVATION_CODE/HOLLAEX_SECRET_ACTIVATION_CODE=$EXCHANGE_ACTIVATION_CODE_OVERRIDE/" $SECRET_FILE_PATH
          rm $SECRET_FILE_PATH.bak
      fi

  done

  export HOLLAEX_SECRET_ACTIVATION_CODE=$EXCHANGE_ACTIVATION_CODE_OVERRIDE
}

function update_activation_code_exec() {

  if [[ "$USE_KUBERNETES" ]]; then 

    # Generate Kubernetes Configmap
    cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/set-activation-code.yaml <<EOL
job:
  enable: true
  mode: set_activaion_code
  env:
    activation_code: ${HOLLAEX_SECRET_ACTIVATION_CODE}
EOL

    if command helm install $ENVIRONMENT_EXCHANGE_NAME-set-activation-code \
                            --namespace $ENVIRONMENT_EXCHANGE_NAME \
                            --set job.enable="true" \
                            --set job.mode="set_activation_code" \
                            --set DEPLOYMENT_MODE="api" \
                            --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                            --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                            --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                            --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                            -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/set-activation-code.yaml \
                            $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server; then

      echo "Kubernetes Job has been created for updating activation code."

      echo "Waiting until Job get completely run..."
      sleep 60;

    else 

      printf "\033[91mFailed to create Kubernetes Job for updating activation code, Please confirm your input values and try again.\033[39m\n"
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-set-activation-code --namespace $ENVIRONMENT_EXCHANGE_NAME

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-set-activation-code --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Your activation code has been successfully updated on your exchange!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-set-activation-code

      echo "Removing created Kubernetes Job for updating the activation code..."
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-set-activation-code --namespace $$ENVIRONMENT_EXCHANGE_NAME

    else 

      printf "\033[91mFailed to update the activation code! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-set-activation-code
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-set-activation-code --namespace $$ENVIRONMENT_EXCHANGE_NAME

      exit 1;

    fi


  elif [[ ! "$USE_KUBERNETES" ]]; then

    IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"
          
    # Overriding container prefix for develop server
    # if [[ "$IS_DEVELOP" ]]; then
      
    #   CONTAINER_PREFIX=

    # fi

    echo "Setting up the exchange with provided activation code"
    docker exec --env "ACTIVATION_CODE=${HOLLAEX_SECRET_ACTIVATION_CODE}" ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/setActivationCode.js
          
  fi

}

function check_constants_exec() {

  if [[ "$USE_KUBERNETES" ]]; then 

    # Generate Kubernetes Configmap
    cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/check_constants.yaml <<EOL
job:
  enable: true
  mode: check_constants
EOL

    if command helm install $ENVIRONMENT_EXCHANGE_NAME-check-constants \
                            --namespace $ENVIRONMENT_EXCHANGE_NAME \
                            --set job.enable="true" \
                            --set job.mode="check_constants" \
                            --set DEPLOYMENT_MODE="api" \
                            --wait \
                            --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                            --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                            --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                            --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                            -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/check_constants.yaml \
                            $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server; then

      echo "Kubernetes Job has been created for setting up the config."

      echo "Waiting until Job get completely run..."
      sleep 30;

    else 

      printf "\033[91mFailed to create Kubernetes Job for checkConstants, Please confirm the logs and try again.\033[39m\n"
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-check-constants --namespace $ENVIRONMENT_EXCHANGE_NAME

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-check-constants --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Your missing database constants has been successfully updated!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-check-constants

      echo "Removing created Kubernetes Job for setting up the config..."
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-check-constants --namespace $ENVIRONMENT_EXCHANGE_NAME

      echo "Successfully updated the missing database constants with your local configmap values."
      echo "Make sure to run 'hollaex restart --kube' to fully apply it."

    else 

      printf "\033[91mFailed to update the database constants! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-check-constants
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-check-constants --namespace $ENVIRONMENT_EXCHANGE_NAME

      exit 1;

    fi


  elif [[ ! "$USE_KUBERNETES" ]]; then

    IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"
        
    echo "Updating constants..."
    if command docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/checkConstants.js; then

        echo "Successfully updated the missing database constants with your local configmap values."
        echo "Make sure to run 'hollaex restart' to fully apply it."

    else 

        echo "Error: Failed to update the missing database constants with your local configmap values."
        echo "Please check the logs and try again."

    fi
          
  fi

}

function set_config_exec() {

  if [[ "$USE_KUBERNETES" ]]; then 

    # Generate Kubernetes Configmap
    cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/set_config.yaml <<EOL
job:
  enable: true
  mode: set_config
EOL

    if command helm install $ENVIRONMENT_EXCHANGE_NAME-set-config \
                            --namespace $ENVIRONMENT_EXCHANGE_NAME \
                            --set job.enable="true" \
                            --set job.mode="set_config" \
                            --set DEPLOYMENT_MODE="api" \
                            --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                            --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                            --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                            --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                            -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/set_config.yaml \
                            $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server; then

      echo "Kubernetes Job has been created for setting up the config."

      echo "Waiting until Job get completely run..."
      sleep 30;

    else 

      printf "\033[91mFailed to create Kubernetes Job for setting up the config, Please confirm the logs and try again.\033[39m\n"
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-set-config --namespace $ENVIRONMENT_EXCHANGE_NAME

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-set-config --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Your database constants has been successfully updated!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-set-config

      echo "Removing created Kubernetes Job for setting up the config..."
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-set-config --namespace $ENVIRONMENT_EXCHANGE_NAME

      echo "Successfully updated database constants with your local configmap values."
      echo "Make sure to run 'hollaex restart --kube' to fully apply it."

    else 

      printf "\033[91mFailed to update the database constants! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-set-config
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-set-config --namespace $ENVIRONMENT_EXCHANGE_NAME

      exit 1;

    fi


  elif [[ ! "$USE_KUBERNETES" ]]; then

    IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"
          
    # Overriding container prefix for develop server
    # if [[ "$IS_DEVELOP" ]]; then
      
    #   CONTAINER_PREFIX=

    # fi

    echo "Updating constants..."
    if command docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/setConfig.js; then

        echo "Successfully updated database constants with your local configmap values."
        echo "Make sure to run 'hollaex restart' to fully apply it."

    else 

        echo "Error: Failed to update database constants with your local configmap values."
        echo "Please check the logs and try again."

    fi
          
  fi

}

function set_security_input() {

  /bin/cat << EOF
  
Please fill up the interaction form to re-set the exchange secrets.

EOF

  # Whitelist IPs
  echo "***************************************************************"
  echo "[1/4] Admin Whitelist IPs: ($HOLLAEX_CONFIGMAP_ADMIN_WHITELIST_IP)"
  printf "\033[2m- IPs to add on admin whitelist. Comman separated.\033[22m\n"
  read answer

  local HOLLAEX_CONFIGMAP_ADMIN_WHITELIST_IP_OVERRIDE="${answer:-$HOLLAEX_CONFIGMAP_ADMIN_WHITELIST_IP}"

  printf "\n"
  echo "${HOLLAEX_CONFIGMAP_ADMIN_WHITELIST_IP_OVERRIDE} ✔"
  printf "\n"

  # Allowed Domains
  echo "***************************************************************"
  echo "[2/4] Allowed Domains: ($HOLLAEX_CONFIGMAP_ALLOWED_DOMAINS)"
  printf "\033[2m- Domains to allow to access exchange server (CORS). Comma separated.\033[22m\n"
  read answer

  local HOLLAEX_CONFIGMAP_ALLOWED_DOMAINS_OVERRIDE="${answer:-$HOLLAEX_CONFIGMAP_ALLOWED_DOMAINS}"

  while true;
    do if [[ "$HOLLAEX_CONFIGMAP_ALLOWED_DOMAINS_OVERRIDE" == *"http"* ]]; then
      printf "\nValue should not have 'http' or 'https'.\n"
      echo  "Allowed Domains: "
      read answer
      local HOLLAEX_CONFIGMAP_ALLOWED_DOMAINS_OVERRIDE="${answer}"
    else
      break;
    fi
  done

  printf "\n"
  echo "${HOLLAEX_CONFIGMAP_ALLOWED_DOMAINS_OVERRIDE} ✔"
  printf "\n"

  # WEB CAPTCHA SITE KEY
  echo "***************************************************************"
  echo "[3/4] Exchange Web Google reCaptcha Sitekey: ($HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY)"
  printf "\n"
  read answer

  local HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY_OVERRIDE="${answer:-$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY}"

  printf "\n"
  echo "${HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY_OVERRIDE} ✔"
  printf "\n"

  # WEB CAPTCHA Secret KEY
  echo "***************************************************************"
  echo "[4/4] Exchange Web Google reCaptcha Secretkey: ($(echo ${HOLLAEX_SECRET_CAPTCHA_SECRET_KEY//?/◼︎}$(echo $HOLLAEX_SECRET_CAPTCHA_SECRET_KEY | grep -o '....$')))"
  printf "\033[2m- Enter your API Server Google reCaptcha Secretkey. \033[22m\n"
  read answer

  local HOLLAEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE="${answer:-$HOLLAEX_SECRET_CAPTCHA_SECRET_KEY}"

  local HOLLAEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE_MASKED=$(echo ${HOLLAEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE//?/◼︎}$(echo $HOLLAEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE | grep -o '....$'))

  printf "\n"
  echo "$HOLLAEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE_MASKED ✔"
  printf "\n"

  /bin/cat << EOF
  
*********************************************
Admin Whitelist IPs: $HOLLAEX_CONFIGMAP_ADMIN_WHITELIST_IP

Allowed Domains: $HOLLAEX_CONFIGMAP_ALLOWED_DOMAINS_OVERRIDE

Google reCaptcha Sitekey: $HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY_OVERRIDE

Google reCaptcha Secretkey: $HOLLAEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE_MASKED
*********************************************

EOF

  echo "Do you want to continue? (Y/n)"
  read answer

  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    echo "You picked false. Please confirm the values and run the command again."
    exit 1;
  
  fi

  echo "Provided values would be updated on your settings files automatically."

  for i in ${CONFIG_FILE_PATH[@]}; do

    # Update exchange name
    if command grep -q "ENVIRONMENT_EXCHANGE_NAME" $i > /dev/null ; then
    CONFIGMAP_FILE_PATH=$i
    sed -i.bak "s/HOLLAEX_CONFIGMAP_ADMIN_WHITELIST_IP=.*/HOLLAEX_CONFIGMAP_ADMIN_WHITELIST_IP=$HOLLAEX_CONFIGMAP_ADMIN_WHITELIST_IP_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_ALLOWED_DOMAINS=.*/HOLLAEX_CONFIGMAP_ALLOWED_DOMAINS=$HOLLAEX_CONFIGMAP_ALLOWED_DOMAINS_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/ENVIRONMENT_WEB_CAPTCHA_SITE_KEY=.*/ENVIRONMENT_WEB_CAPTCHA_SITE_KEY=$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_SECRET_CAPTCHA_SECRET_KEY=.*/HOLLAEX_SECRET_CAPTCHA_SECRET_KEY=$HOLLAEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE/" $CONFIGMAP_FILE_PATH
    rm $CONFIGMAP_FILE_PATH.bak
    fi
      
  done

  export HOLLAEX_CONFIGMAP_ADMIN_WHITELIST_IP=$HOLLAEX_CONFIGMAP_ADMIN_WHITELIST_IP_OVERRIDE

  export HOLLAEX_CONFIGMAP_ALLOWED_DOMAINS=$HOLLAEX_CONFIGMAP_ALLOWED_DOMAINS_OVERRIDE

  export HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY=$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY_OVERRIDE
  
  export HOLLAEX_SECRET_CAPTCHA_SECRET_KEY=$HOLLAEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE

}

function set_security_exec() {

  if [[ "$USE_KUBERNETES" ]]; then 

    # Generate Kubernetes Configmap
    cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/set_security.yaml <<EOL
job:
  enable: true
  mode: set_security
EOL

    if command helm install $ENVIRONMENT_EXCHANGE_NAME-set-security \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set job.enable="true" \
                --set job.mode="set_config" \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/set_security.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server; then

      echo "Kubernetes Job has been created for setting up security values."

      echo "Waiting until Job get completely run..."
      sleep 30;

    else 

      printf "\033[91mFailed to create Kubernetes Job for setting up security values. Please confirm the logs and try again.\033[39m\n"
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-set-security --namespace $ENVIRONMENT_EXCHANGE_NAME

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-set-security --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Your database constants has been successfully updated!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-set-security

      echo "Removing created Kubernetes Job for setting up security values..."
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-set-security --namespace $ENVIRONMENT_EXCHANGE_NAME

      echo "Successfully updated security values with your local configmap values."
      echo "Make sure to run 'hollaex restart --kube' to fully apply it."

    else 

      printf "\033[91mFailed to update the database constants! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-set-security
      helm uninstall $ENVIRONMENT_EXCHANGE_NAME-set-security --namespace $ENVIRONMENT_EXCHANGE_NAME

      exit 1;

    fi


  elif [[ ! "$USE_KUBERNETES" ]]; then

    IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"
          
    # Overriding container prefix for develop server
    # if [[ "$IS_DEVELOP" ]]; then
      
    #   CONTAINER_PREFIX=

    # fi

    echo "Updating security values..."
    if command docker exec --env ADMIN_WHITELIST_IP=$HOLLAEX_CONFIGMAP_ADMIN_WHITELIST_IP \
                --env ALLOWED_DOMAINS=$HOLLAEX_CONFIGMAP_ALLOWED_DOMAINS \
                --env CAPTCHA_SITE_KEY=$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY \
                --env CAPTCHA_SECRET_KEY=$HOLLAEX_SECRET_CAPTCHA_SECRET_KEY \
                ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                node tools/dbs/setSecurity.js; then

        echo "Successfully updated exchange security values with the new ones."
        echo "Make sure to run 'hollaex restart' to fully apply it."

    else 

        echo "Error: Failed to update security values with your local configmap values."
        echo "Please check the logs and try again."

    fi
          
  fi

}

function check_docker_compose_dependencies() {

  # Checking docker-compose is installed on this machine.
  if command docker-compose version > /dev/null 2>&1; then

      echo "*********************************************"
      echo "docker-compose detected"  
      echo "version: $(docker-compose version)"
      echo "*********************************************"

  else

      echo "HollaEx CLI failed to detect docker-compose installed on this machine. Please install it before running HollaEx CLI."
      exit 1;

  fi

}

function hollaex_pull_and_apply_exchange_data() {  

  local HOLLAEX_CONFIGMAP_API_NAME_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].name";)

  local ENVIRONMENT_EXCHANGE_NAME_OVERRIDE=$(echo $HOLLAEX_CONFIGMAP_API_NAME_OVERRIDE | tr -dc '[:alnum:]\n\r' | tr '[:upper:]' '[:lower:]' | tr -d ' ')

  #LOGO PATH ESCAPING
  local ORIGINAL_CHARACTER_FOR_LOGO_IMAGE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.LOGO_IMAGE";)
  local HOLLAEX_CONFIGMAP_LOGO_IMAGE_OVERRIDE="${ORIGINAL_CHARACTER_FOR_LOGO_IMAGE//\//\\/}"

  # Set the default HollaEx Server version as the maximum compatible version of the current release of CLI.
  local ENVIRONMENT_DOCKER_IMAGE_VERSION_OVERRIDE="$(cat $HOLLAEX_CLI_INIT_PATH/server/package.json | jq -r '.version')"

  # CONFIGMAP 
  sed -i.bak "s/ENVIRONMENT_EXCHANGE_NAME=.*/ENVIRONMENT_EXCHANGE_NAME=$ENVIRONMENT_EXCHANGE_NAME_OVERRIDE/" $CONFIGMAP_FILE_PATH

  sed -i.bak "s/HOLLAEX_CONFIGMAP_API_NAME=.*/HOLLAEX_CONFIGMAP_API_NAME=$HOLLAEX_CONFIGMAP_API_NAME_OVERRIDE/" $CONFIGMAP_FILE_PATH

  sed -i.bak "s/HOLLAEX_CONFIGMAP_LOGO_IMAGE=.*/HOLLAEX_CONFIGMAP_LOGO_IMAGE=$HOLLAEX_CONFIGMAP_LOGO_IMAGE_OVERRIDE/" $CONFIGMAP_FILE_PATH

  sed -i.bak "s/ENVIRONMENT_DOCKER_IMAGE_VERSION=.*/ENVIRONMENT_DOCKER_IMAGE_VERSION=$ENVIRONMENT_DOCKER_IMAGE_VERSION_OVERRIDE/" $CONFIGMAP_FILE_PATH
 
  rm $CONFIGMAP_FILE_PATH.bak

}

function check_docker_compose_is_installed() {

  # Checking docker-compose is installed on this machine.
  if command docker-compose version > /dev/null 2>&1; then
      
      echo "*********************************************"
      echo "docker-compose detected"
      echo "version: $(docker-compose version)"
      echo "*********************************************"

  else

      echo "HollaEx CLI failed to detect docker-compose installed on this machine. Please install it before running HollaEx CLI."
      exit 1;

  fi
  
}


function check_kit_version_compatibility_range() {

  CURRENT_HOLLAEX_KIT_VERSION=$(cat $HOLLAEX_CLI_INIT_PATH/version)

  CURRENT_HOLLAEX_KIT_MAJOR_VERSION=$(cat $HOLLAEX_CLI_INIT_PATH/version | cut -f1 -d ".")
  CURRENT_HOLLAEX_KIT_MINOR_VERSION=$(cat $HOLLAEX_CLI_INIT_PATH/version | cut -f2 -d ".")

  HOLLAEX_KIT_MINIMUM_COMPATIBLE_MAJOR_VERSION=$(echo $HOLLAEX_KIT_MINIMUM_COMPATIBLE | cut -f1 -d ".")
  HOLLAEX_KIT_MINIMUM_COMPATIBLE_MINOR_VERSION=$(echo $HOLLAEX_KIT_MINIMUM_COMPATIBLE | cut -f2 -d ".")

  HOLLAEX_KIT_MAXIMUM_COMPATIBLE_MAJOR_VERSION=$(echo $HOLLAEX_KIT_MAXIMUM_COMPATIBLE | cut -f1 -d ".")
  HOLLAEX_KIT_MAXIMUM_COMPATIBLE_MINOR_VERSION=$(echo $HOLLAEX_KIT_MAXIMUM_COMPATIBLE | cut -f2 -d ".")

  if [[ "$CURRENT_HOLLAEX_KIT_MAJOR_VERSION" < "$HOLLAEX_KIT_MINIMUM_COMPATIBLE_MAJOR_VERSION" ]] || [[ "$CURRENT_HOLLAEX_KIT_MAJOR_VERSION" > "$HOLLAEX_KIT_MAXIMUM_COMPATIBLE_MAJOR_VERSION" ]]; then

    printf "\n\033[91mError: The HollaEx Kit version that you are trying to run is not compatible with the installed CLI.\033[39m\n"
    printf "Your HollaEx Kit version: \033[1m$CURRENT_HOLLAEX_KIT_VERSION\033[0m\n"
    printf "Supported HollaEx Kit version range: \033[1m$HOLLAEX_KIT_MINIMUM_COMPATIBLE ~ $HOLLAEX_KIT_MAXIMUM_COMPATIBLE.\033[0m\n\n"

    exit 1;

  fi 

  if [[ "$CURRENT_HOLLAEX_KIT_MINOR_VERSION" < "$HOLLAEX_KIT_MINIMUM_COMPATIBLE_MINOR_VERSION" ]] || [[ "$CURRENT_HOLLAEX_KIT_MINOR_VERSION" > "$HOLLAEX_KIT_MAXIMUM_COMPATIBLE_MINOR_VERSION" ]]; then

    printf "\n\033[91mError: The HollaEx Kit version that you are trying to run is not compatible with the installed CLI.\033[39m\n"
    printf "Your HollaEx Kit version: \033[1m$CURRENT_HOLLAEX_KIT_VERSION\033[0m\n"
    printf "Supported HollaEx Kit version range: \033[1m$HOLLAEX_KIT_MINIMUM_COMPATIBLE ~ $HOLLAEX_KIT_MAXIMUM_COMPATIBLE.\033[0m\n"

    if [[ "$CURRENT_HOLLAEX_KIT_MINOR_VERSION" > "$HOLLAEX_KIT_MAXIMUM_COMPATIBLE_MINOR_VERSION" ]]; then

      printf "\nYour Kit version is \033[1mhigher than the maximum compatible version\033[0m of your CLI.\n"
      printf "You can \033[1mreinstall the HollaEx CLI\033[0m to higher version.\n\n"
      printf "To reinstall the HollaEx CLI to a compatible version, Please run '\033[1mhollaex toolbox --install_cli <VERSION_NUMBER>\033[0m.\n"

    elif [[ "$CURRENT_HOLLAEX_KIT_MINOR_VERSION" < "$HOLLAEX_KIT_MINIMUM_COMPATIBLE_MINOR_VERSION" ]]; then

      printf "\nYour Kit version is \033[1mlower than the minimum compatible version\033[0m of your CLI.\n"
      printf "\nYou can either \033[1mreinstall the HollaEx CLI, or upgrade your HollaEx Kit\033[0m.\n\n"
      printf "To reinstall the HollaEx CLI to a compatible version, Please run '\033[1mhollaex toolbox --install_cli <VERSION_NUMBER>\033[0m.\n"
      printf "To see how to upgrade your HollaEx Kit, Please \033[1mcheck our official upgrade docs (docs.bitholla.com/hollaex-kit/upgrade)\033[0m.\n"

    fi

    printf "\nYou can see the version compatibility range of between CLI and Kit at our \033[1mofficial docs (docs.bitholla.com/hollaex-kit/upgrade/version-compatibility)\033[0m.\n\n"

    exit 1;

  fi

}

function generate_backend_passwords() {

  echo "Generating random passwords for backends..."

  export HOLLAEX_SECRET_REDIS_PASSWORD=$(generate_random_values)
  export HOLLAEX_SECRET_DB_PASSWORD=$(generate_random_values)

  for i in ${CONFIG_FILE_PATH[@]}; do

    if command grep -q "HOLLAEX_SECRET_REDIS_PASSWORD" $i > /dev/null ; then

      SECRET_FILE_PATH=$i

    fi 

  done

  sed -i.bak "s/HOLLAEX_SECRET_REDIS_PASSWORD=.*/HOLLAEX_SECRET_REDIS_PASSWORD=$HOLLAEX_SECRET_REDIS_PASSWORD/" $SECRET_FILE_PATH
  sed -i.bak "s/HOLLAEX_SECRET_PUBSUB_PASSWORD=.*/HOLLAEX_SECRET_PUBSUB_PASSWORD=$HOLLAEX_SECRET_REDIS_PASSWORD/" $SECRET_FILE_PATH

  sed -i.bak "s/HOLLAEX_SECRET_DB_PASSWORD=.*/HOLLAEX_SECRET_DB_PASSWORD=$HOLLAEX_SECRET_DB_PASSWORD/" $SECRET_FILE_PATH

  rm $SECRET_FILE_PATH.bak

  for i in ${CONFIG_FILE_PATH[@]}; do
      source $i
  done;


}

function system_dependencies_check() {

  echo "Checking system dependencies..."

  ### Common dependencies ###
  if command docker -v > /dev/null 2>&1; then

    IS_DOCKER_INSTALLED=true
    
  fi

  if command jq --version > /dev/null 2>&1; then

    IS_JQ_INSTALLED=true
    
  fi

  if command nslookup -version > /dev/null 2>&1; then

    IS_NSLOOKUP_INSTALLED=true
  
  fi

  ### Checking for environment specific dependencies ###

  # Kubernetes deployment dependencies
  if [[ "$USE_KUBERNETES" ]]; then

    if command kubectl version > /dev/null 2>&1; then

      IS_KUBECTL_INSTALLED=true
    
    fi

    if command helm version > /dev/null 2>&1; then

      IS_HELM_INSTALLED=true
    
    fi

  # Local deployment dependencies
  else  

    if command docker-compose -v > /dev/null 2>&1; then

      IS_DOCKER_COMPOSE_INSTALLED=true
    
    fi

  fi

  ### Printing error if dependencies are missing ###
  if [[ ! "$IS_DOCKER_INSTALLED" ]] || [[ ! "$IS_JQ_INSTALLED" ]] || [[ ! "$IS_NSLOOKUP_INSTALLED" ]]; then

    printf "\033[91mError: Some of the common dependencies are missing on your system.\033[39m\n"

    # Docker installation status chekc
    if [[ "$IS_DOCKER_INSTALLED" ]]; then

        printf "\033[92mDocker: Installed\033[39m\n"

    else 

        printf "\033[91mDocker: Not Installed\033[39m\n"
    
    fi  

    # Docker-compose installation status check
    if [[ "$IS_DOCKER_COMPOSE_INSTALLED" ]]; then

        printf "\033[92mDocker-Compose: Installed\033[39m\n"

    else

        printf "\033[91mDocker-Compose: Not Installed\033[39m\n"

    fi

    # jq installation status check
    if [[ "$IS_JQ_INSTALLED" ]]; then

        printf "\033[92mjq: Installed\033[39m\n"

    else 

        printf "\033[91mjq: Not Installed\033[39m\n"

    fi

    # nslookup installation status check
    if [[ "$IS_NSLOOKUP_INSTALLED" ]]; then

        printf "\033[92mnslookup: Installed\033[39m\n"

    else 

        printf "\033[91mnslookup: Not Installed\033[39m\n"

    fi

    echo "Please install the missing dependencies and try again."
    exit 1;

  fi

  if [[ "$USE_KUBERNETES" ]]; then

    if [[ ! "$IS_KUBECTL_INSTALLED" ]] || [[ ! "$IS_HELM_INSTALLED" ]]; then

      printf "\033[91mError: Some of the Kubernetes dependencies are missing on your system.\033[39m\n"

      if [[ "$IS_KUBECTL_INSTALLED" ]]; then

          printf "\033[92mKubectl: Installed\033[39m\n"

      else 

          printf "\033[91mKubectl: Not Installed\033[39m\n"

      fi

      if [[ "$IS_HELM_INSTALLED" ]]; then

          printf "\033[92mHelm v3: Installed\033[39m\n"

      else 

          printf "\033[91mHelm v3: Not Installed\033[39m\n"

      fi

      echo "Please install the missing dependencies and try again."
      exit 1;

    fi

  else

    if [[ ! "$IS_DOCKER_COMPOSE_INSTALLED" ]]; then

      printf "\033[91mError: Some of the Kubernetes dependencies are missing on your system.\033[39m\n"

      # Docker installation status chekc
      if [[ "$IS_DOCKER_COMPOSE_INSTALLED" ]]; then

          printf "\033[92mDocker-Compose: Installed\033[39m\n"

      else 

          printf "\033[91mDocker-Compose: Not Installed\033[39m\n"
      
      fi

      echo "Please install the missing dependencies and try again."
      exit 1;

    fi

  fi

  echo "You are good to go!"
    
}

function generate_db_s3_backup_cronjob_config() {

  # Generate Kubernetes Configmap
  cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/db-s3-backup-cronjob.yaml <<EOL

  secretName: $ENVIRONMENT_EXCHANGE_NAME-secret

  cronRule: "$ENVIRONMENT_KUBERNETES_S3_BACKUP_CRONJOB_RULE" 

  timeZone: "$ENVIRONMENT_KUBERNETES_S3_BACKUP_CRONJOB_TIMEZONE"

  awsRegion: $ENVIRONMENT_KUBERNETES_S3_BACKUP_CRONJOB_REGION
  awsBucket: $ENVIRONMENT_KUBERNETES_S3_BACKUP_CRONJOB_BUCKET
  awsAccessKey: "$ENVIRONMENT_KUBERNETES_S3_BACKUP_CRONJOB_ACCESSKEY"
  awsSecretKey: "$ENVIRONMENT_KUBERNETES_S3_BACKUP_CRONJOB_SECRETKEY"

EOL

}

function check_docker_daemon_status() {

  if ! command docker ps > /dev/null 2>&1; then

    printf "\n\033[91mError: Docker Daemon is not running!\033[39m\n"
    echo "Please check the Docker status of your system and try again."
    exit 1;

  fi

}

function issue_new_hmac_token() {

  BITHOLLA_HMAC_TOKEN_ISSUE_POST=$(curl -s -H "Content-Type: application/json" -H "Authorization: Bearer $BITHOLLA_ACCOUNT_TOKEN" -w "=%{http_code}" \
        --request POST \
        -d '{"name": "kit"}' \
        $hollaexAPIURL/v2/dash/user/token/main)

  BITHOLLA_HMAC_TOKEN_ISSUE_POST_RESPOND=$(echo $BITHOLLA_HMAC_TOKEN_ISSUE_POST | cut -f1 -d "=")
  BITHOLLA_HMAC_TOKEN_ISSUE_POST_HTTP_CODE=$(echo $BITHOLLA_HMAC_TOKEN_ISSUE_POST | cut -f2 -d "=")

  if [[ ! "$BITHOLLA_HMAC_TOKEN_ISSUE_POST_HTTP_CODE" == "200" ]]; then

    echo -e "\n\033[91m$(echo $BITHOLLA_HMAC_TOKEN_ISSUE_POST_RESPOND | jq -r '.message')\033[39m\n"
    
    echo -e "Failed to issue a security token!"

    echo -e "\nPlease check your internet connectivity, and try it again."
    echo -e "You could also check the HollaEx service status at https://status.bitholla.com."

    exit 1;

  fi 
  
  HOLLAEX_SECRET_API_KEY=$(echo $BITHOLLA_HMAC_TOKEN_ISSUE_POST_RESPOND | jq -r '.apiKey')
  HOLLAEX_SECRET_API_SECRET=$(echo $BITHOLLA_HMAC_TOKEN_ISSUE_POST_RESPOND | jq -r '.secret')

  echo -e "\n# # # # # Your API Key and Secret # # # # #"
  echo -e "\033[1mYour API Key: $HOLLAEX_SECRET_API_KEY\033[0m"
  echo -e "\033[1mYour Secret Key: $HOLLAEX_SECRET_API_SECRET\033[0m"
  echo -e "# # # # # # # # # # # # # # # #\n"

  if command sed -i.bak "s/HOLLAEX_SECRET_API_KEY=.*/HOLLAEX_SECRET_API_KEY=$HOLLAEX_SECRET_API_KEY/" $SECRET_FILE_PATH && command sed -i.bak "s/HOLLAEX_SECRET_API_SECRET=.*/HOLLAEX_SECRET_API_SECRET=$HOLLAEX_SECRET_API_SECRET/" $SECRET_FILE_PATH; then

    echo -e "\033[92mSuccessfully stored the issued API Key and Secret to the settings file.\033[39m\n"

  else 

    echo -e "\n\033[91mFailed to store the issued API Key and Secret to the settings file.\033[39m\n"
    echo "Please make sure to manually save the issued API Key and Secret displayed above, and try it again."
    
    exit 1;

  fi 

  rm -f $SECRET_FILE_PATH.bak

}

function get_hmac_token() {

  echo "Issuing an API Key for the HollaEx Network communication..."

  BITHOLLA_HMAC_TOKEN_GET_DATA=$(curl -s -H "Content-Type: application/json" -H "Authorization: Bearer $BITHOLLA_ACCOUNT_TOKEN"\
            --request GET \
            $hollaexAPIURL/v2/dash/user/token?active=true)
  
  BITHOLLA_HMAC_TOKEN_GET_COUNT=$(echo $BITHOLLA_HMAC_TOKEN_GET_DATA | jq '.count')

  # BITHOLLA_HMAC_TOKEN_TYPE=$(echo $BITHOLLA_HMAC_TOKEN_GET_DATA | jq '.data.type')
    
  if [[ ! $BITHOLLA_HMAC_TOKEN_GET_COUNT == 0 ]]; then 

    BITHOLLA_HMAC_TOKEN_GET_COUNT=$((BITHOLLA_HMAC_TOKEN_GET_COUNT-1))

    for ((i=0;i<=BITHOLLA_HMAC_TOKEN_GET_COUNT;i++)); do 

      if [[ $(echo $BITHOLLA_HMAC_TOKEN_GET_DATA | jq -r ".data[$i].type") == "main" ]]; then

          # echo $BITHOLLA_HMAC_TOKEN_GET_DATA | jq -r ".data[$i].type"
          export BITHOLLA_HMAC_MAIN_TOKEN_ORDER=$i
          # echo "Main token order: $BITHOLLA_HMAC_MAIN_TOKEN_ORDER"
      
      fi

    done;

    BITHOLLA_HMAC_TOKEN_EXISTING_APIKEY=$(echo $BITHOLLA_HMAC_TOKEN_GET_DATA | jq -r ".data[$BITHOLLA_HMAC_MAIN_TOKEN_ORDER].apiKey")
    
    BITHOLLA_HMAC_TOKEN_EXISTING_TOKEN_ID=$(echo $BITHOLLA_HMAC_TOKEN_GET_DATA | jq -r ".data[$BITHOLLA_HMAC_MAIN_TOKEN_ORDER].id")

    printf "\n\033[1mYou already have an active main API key! (API Key: $BITHOLLA_HMAC_TOKEN_EXISTING_APIKEY)\033[0m\n\n"

    # echo -e "You could \033[1mprovide the existing token manually\033[0m on the further menu."
    # echo -e "If you dont have an existing token, \033[1myou could also revoke the token at the https://dash.hollaex.com.\033[0m\n"

    if [[ ! "$RESET_HMAC_TOKEN" ]]; then 

      echo -e "\033[1mDo you have the API secret for this API key? (Y/n)\033[0m"

      read tokenAnswer

    else 

      local tokenAnswer="n"

    fi  

    if [[ "$tokenAnswer" = "${tokenAnswer#[Yy]}" ]]; then

      if [[ ! "$RUN_WITH_VERIFY" ]]; then 

        echo -e "\033[1mYou need to revoke the existing main API key at HollaEx Dashboard (https://dash.hollaex.com/mypage/apikey).\033[0m"

        echo -e "Revoking the API key can't be undone and would result in disconnecting the existing exchange."
        echo -e "Please make sure that you are not running the exchange already."

        if [[ "$OSTYPE" == *"darwin"* ]]; then 

              open https://dash.hollaex.com/mypage/apikey
          
          else 

              if ! command xdg-open https://dash.hollaex.com/mypage/apikey > /dev/null 2>&1; then 

                  echo "Error: Your system does not support xdg-open compatible browser."
                  echo "Please open HollaEx Dashboard (https://dash.hollaex.com/mypage/apikey) by yourself, and continue to sign-up."

              fi 

        fi

          echo -e "\nOnce you fully revoked the API Key, please press C to continue."
          read answer

          while true;

              do if [[ "$answer" = "${answer#[Cc]}" ]]; then
              
                  echo -e "\nOnce you fully revoked the API key, please press C to continue."
                  read answer

              else

                  break;

              fi
          
          done
      

      fi

      # if [[ ! "$RESET_HMAC_TOKEN" ]]; then
       
      #   echo -e "\nDo you want to \033[1mproceed to revoke\033[0m the existing token? (API Key: $BITHOLLA_HMAC_TOKEN_EXISTING_APIKEY) (y/N)"

      #   read answer

      # else 

      #   local answer="y"

      # fi 

      # if [[ "$answer" = "${answer#[Yy]}" ]] ;then

      #   echo -e "\n\033[91mThe security token is must required to setup an HollaEx Exchange.\033[39m"
      #   echo -e "\nPlease \033[1mrun this command again once you becomes ready.\033[0m"
      #   echo -e "You could also revoke the token through the https://dash.hollaex.com."

      #   echo -e "\nSee you in a bit!\n"

      #   exit 1;

      # fi
      
      if [[ "$HOLLAEX_LOGIN_KEY" ]]; then 

        echo -e "Revoking the exisitng token ($BITHOLLA_HMAC_TOKEN_EXISTING_APIKEY)..."

        # Revoking the security token through the HollaEx API.
        BITHOLLA_HMAC_TOKEN_REVOKE_CALL=$(curl -s -H "Content-Type: application/json" -H "Authorization: Bearer $BITHOLLA_ACCOUNT_TOKEN" -w " HTTP_CODE=%{http_code}" \
            --request DELETE \
            -d "{\"key\": \"$HOLLAEX_LOGIN_KEY\", \"token_id\": $BITHOLLA_HMAC_TOKEN_EXISTING_TOKEN_ID}" \
            $hollaexAPIURL/v2/dash/user/token/main)
        
        BITHOLLA_HMAC_TOKEN_REVOKE_CALL_RESPOND=$(echo $BITHOLLA_HMAC_TOKEN_REVOKE_CALL | cut -f1 -d "=")
        BITHOLLA_HMAC_TOKEN_REVOKE_CALL_HTTP_CODE=$(echo $BITHOLLA_HMAC_TOKEN_REVOKE_CALL | cut -f2 -d "=")

        # echo $BITHOLLA_HMAC_TOKEN_REVOKE_CALL

        if [[ ! "$BITHOLLA_HMAC_TOKEN_REVOKE_CALL_HTTP_CODE" == "200" ]]; then 

          echo -e "\033[91mFailed to revoke the security token!\033[39m"
          echo -e "\nPlease check the error logs and try it again."
          echo -e "You could also revoke the token through the https://dash.hollaex.com.\n"

          exit 1;

        fi 

        echo -e "\n\033[92mSuccessfully revoked the security token!\033[39m"
      
      fi

      echo -e "\n\033[1mProceeding to reissue it...\033[0m"
      issue_new_hmac_token;

    else

      function existing_token_form() {
        
        if [[ "$BITHOLLA_HMAC_TOKEN_EXISTING_APIKEY" ]]; then 

          echo "Your existing API Key: $BITHOLLA_HMAC_TOKEN_EXISTING_APIKEY"
          HOLLAEX_SECRET_API_KEY=$BITHOLLA_HMAC_TOKEN_EXISTING_APIKEY

        else 

          echo -e "\033[1mYour existing API Key: \033[0m"
          read answer 
          HOLLAEX_SECRET_API_KEY=$answer

        fi 

        echo -e "\033[1mYour existing Secret Key: \033[0m"
        read answer
        HOLLAEX_SECRET_API_SECRET=$answer

        echo -e "\n\033[1mAPI Key: $HOLLAEX_SECRET_API_KEY\033[0m"
        echo -e "\033[1mSecret Key: $HOLLAEX_SECRET_API_SECRET\033[0m\n"
        
        echo "Do you want to proceed with these values? (Y/n)"
        read answer

        if [[ ! "$answer" = "${answer#[Nn]}" ]] ;then

            existing_token_form;

        fi

        if command sed -i.bak "s/HOLLAEX_SECRET_API_KEY=.*/HOLLAEX_SECRET_API_KEY=$HOLLAEX_SECRET_API_KEY/" $SECRET_FILE_PATH && command sed -i.bak "s/HOLLAEX_SECRET_API_SECRET=.*/HOLLAEX_SECRET_API_SECRET=$HOLLAEX_SECRET_API_SECRET/" $SECRET_FILE_PATH; then

          echo -e "\n\033[92mSuccessfully stored the provided API Key to the settings file.\033[39m\n"

        else 

          echo -e "\n\033[91mFailed to store the issued API Key to the settings file.\033[39m\n"
          echo "Please try it again."

          exit 1;

        fi

      }

      existing_token_form;
      rm -f $SECRET_FILE_PATH.bak
  
    fi 

  else

    issue_new_hmac_token;

  fi
  
}

function hollaex_setup_initialization() {

  if [[ "$RUN_WITH_VERIFY" == true ]]; then 

      printf "\n\033[1mWelcome to HollaEx Server Setup!\033[0m\n"

      if ! command hollaex init; then

          exit 1;

      fi     
    
  fi

}

function hollaex_login_form() {

    echo -e "\n\033[1m# # # HOLLAEX DASHBOARD LOGIN # # #\033[0m\n"

    echo -e "\033[1mHollaEx Account Email:\033[0m "
    read email

    echo -e "\033[1mHollaEx Account Password:\033[0m "
    read -s password
    printf "\n"

    echo -e "\033[1mOTP Code\033[0m (Enter if you don't have OTP set for your account): "
    read otp 

    BITHOLLA_ACCOUNT_LOGIN=$(curl -s -H "Content-Type: application/json" \
        --request POST \
        -w ";%{http_code}" \
        --data "{\"email\": \"${email}\", \"password\": \"${password}\", \"otp_code\": \"${otp}\", \"service\": \"cli\"}" \
        $hollaexAPIURL/v2/dash/login)
    
    BITHOLLA_ACCOUNT_LOGIN_MESSAGE=$(echo $BITHOLLA_ACCOUNT_LOGIN | cut -f1 -d ";" | jq -r '.message')
    BITHOLLA_ACCOUNT_LOGIN_HTTP_CODE=$(echo $BITHOLLA_ACCOUNT_LOGIN | cut -f2 -d ";")

    if [[ "$BITHOLLA_ACCOUNT_LOGIN_HTTP_CODE" == "200" ]]; then

      echo -e "\n\033[92mThe login confirmation email has been sent.\033[39m"
      echo -e "Please check your email inbox and type the verification code in."
      read -s verification_code
      printf "\n"

      BITHOLLA_VERIFICATION_CODE_CHECK=$(curl -s -H "Content-Type: application/json" \
        --request POST \
        -w ";%{http_code}" \
        --data "{\"code\": \"${verification_code}\", \"service\": \"cli\"}" \
        $hollaexAPIURL/v2/dash/confirm-login)

      BITHOLLA_VERIFICATION_CODE_CHECK_HTTP_CODE=$(echo $BITHOLLA_VERIFICATION_CODE_CHECK | cut -f2 -d ";")

      if [[ "$BITHOLLA_VERIFICATION_CODE_CHECK_HTTP_CODE" == "201" ]]; then 

        echo "Successfully verified your email verification code."
        BITHOLLA_ACCOUNT_TOKEN=$(echo $BITHOLLA_VERIFICATION_CODE_CHECK | cut -f1 -d ";" | jq -r '.token')

      else 

        printf "\033[91mInvalid email code.\033[39m\n"
        echo "Please try it again."
        exit 1;

      fi 

    else 

      echo -e "\n\033[91m$BITHOLLA_ACCOUNT_LOGIN_MESSAGE\033[39m"
      printf "\nFailed to authenticate on HollaEx Server with your passed credentials.\n"
      echo "Please try it again."
      exit 1;

    fi 

    if [[ ! "$BITHOLLA_ACCOUNT_TOKEN" ]] || [[ "$BITHOLLA_ACCOUNT_TOKEN" == "null" ]]; then

        echo -e "\n\033[91m$BITHOLLA_ACCOUNT_LOGIN_MESSAGE\033[39m"
        printf "\nFailed to authenticate on HollaEx Server with your passed credentials.\n"
        echo "Please try it again."
        exit 1;

    else 

        printf "\033[92mSuccessfully authenticated on HollaEx Server.\033[39m\n"
        # echo "Info: Your authentication will be only available for 24 hours."

        echo $BITHOLLA_ACCOUNT_TOKEN > $HOLLAEX_CLI_INIT_PATH/.token

        if [[ "$HOLLAEX_LOGIN_RENEW" ]]; then 

            exit 0;

        fi 

    fi

}

function hollaex_login_token_validate_and_issue() {

  if [[ -f "$HOLLAEX_CLI_INIT_PATH/.token" ]]; then

      echo "Validating the existing access token..."
      BITHOLLA_ACCOUNT_TOKEN=$(cat $HOLLAEX_CLI_INIT_PATH/.token)

      BITHOLLA_USER_TOKEN_EXPIRY_CHECK=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $BITHOLLA_ACCOUNT_TOKEN"\
          --request GET \
          $hollaexAPIURL/v2/exchange)

      BITHOLLA_USER_EXCHANGE_LIST=$(curl -s -H "Content-Type: application/json" -H "Authorization: Bearer $BITHOLLA_ACCOUNT_TOKEN"\
          --request GET \
          $hollaexAPIURL/v2/exchange \
          | jq '.')

      if [[ ! "$BITHOLLA_USER_TOKEN_EXPIRY_CHECK" ]] || [[ ! "$BITHOLLA_USER_TOKEN_EXPIRY_CHECK" == "200" ]]; then

          printf "\033[91mError: Your access token has been expired!\033[39m\n"
          printf "Please login again with your HollaEx account to issue a new access token.\n\n"
          hollaex_login_form;

      else

          echo -e "\033[92mYour existing access token is valid!\033[39m"
          echo "Info: Delete the ‘.token’ file in your HollaEx Kit to remove the existing token."

      fi

  else 

      hollaex_login_form;

  fi

}

function run_and_upgrade_hollaex_on_kubernetes() {

  #Creating kubernetes_config directory for generating config for Kubernetes.
  if [[ ! -d "$TEMPLATE_GENERATE_PATH/kubernetes/config" ]]; then
      mkdir $TEMPLATE_GENERATE_PATH/kubernetes;
      mkdir $TEMPLATE_GENERATE_PATH/kubernetes/config;
  fi

  if [[ "$ENVIRONMENT_KUBERNETES_GENERATE_CONFIGMAP_ENABLE" == true ]]; then

      echo "Generating Kubernetes Configmap"
      generate_kubernetes_configmap;

  fi

  if [[ "$ENVIRONMENT_KUBERNETES_GENERATE_SECRET_ENABLE" == true ]]; then

      echo "Generating Kubernetes Secret"
      generate_kubernetes_secret;

  fi


  if [[ "$ENVIRONMENT_KUBERNETES_GENERATE_INGRESS_ENABLE" == true ]]; then

      echo "Generating Kubernetes Ingress"
      generate_kubernetes_ingress;

  fi

  if [[ ! "$IGNORE_SETTINGS" ]]; then 

      echo "Applying latest configmap env on the cluster."
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml

      echo "Applying latest secret on the cluster"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-secret.yaml

  fi

  # Running & Upgrading Databases
  if [[ "$ENVIRONMENT_KUBERNETES_RUN_REDIS" == true ]]; then

      generate_nodeselector_values $ENVIRONMENT_KUBERNETES_REDIS_NODESELECTOR redis

      helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-redis \
                  --namespace $ENVIRONMENT_EXCHANGE_NAME \
                  --set setAuth.secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                  --set resources.limits.cpu="${ENVIRONMENT_REDIS_CPU_LIMITS:-100m}" \
                  --set resources.limits.memory="${ENVIRONMENT_REDIS_MEMORY_LIMITS:-200Mi}" \
                  --set resources.requests.cpu="${ENVIRONMENT_REDIS_CPU_REQUESTS:-10m}" \
                  --set resources.requests.memory="${ENVIRONMENT_REDIS_MEMORY_REQUESTS:-100Mi}" \
                  -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-redis/values.yaml \
                  -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-redis.yaml \
                  $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-redis $(kubernetes_set_backend_image_target $ENVIRONMENT_DOCKER_IMAGE_REDIS_REGISTRY $ENVIRONMENT_DOCKER_IMAGE_REDIS_VERSION) $(set_nodeport_access $ENVIRONMENT_KUBERNETES_ALLOW_EXTERNAL_REDIS_ACCESS $ENVIRONMENT_KUBERNETES_EXTERNAL_REDIS_ACCESS_PORT)
  
  fi

  if [[ "$ENVIRONMENT_KUBERNETES_RUN_POSTGRESQL_DB" == true ]]; then

      generate_nodeselector_values $ENVIRONMENT_KUBERNETES_POSTGRESQL_DB_NODESELECTOR postgresql

      helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-db \
                  --namespace $ENVIRONMENT_EXCHANGE_NAME \
                  --wait \
                  --set pvc.create=true \
                  --set pvc.name="$ENVIRONMENT_EXCHANGE_NAME-postgres-volume" \
                  --set pvc.size="$ENVIRONMENT_KUBERNETES_POSTGRESQL_DB_VOLUMESIZE" \
                  --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                  --set resources.limits.cpu="${ENVIRONMENT_POSTGRESQL_CPU_LIMITS:-100m}" \
                  --set resources.limits.memory="${ENVIRONMENT_POSTGRESQL_MEMORY_LIMITS:-200Mi}" \
                  --set resources.requests.cpu="${ENVIRONMENT_POSTGRESQL_CPU_REQUESTS:-10m}" \
                  --set resources.requests.memory="${ENVIRONMENT_POSTGRESQL_MEMORY_REQUESTS:-100Mi}" \
                  -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-postgres/values.yaml \
                  -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-postgresql.yaml \
                  $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-postgres $(kubernetes_set_backend_image_target $ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_REGISTRY $ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_VERSION) $(set_nodeport_access $ENVIRONMENT_KUBERNETES_ALLOW_EXTERNAL_POSTGRESQL_DB_ACCESS $ENVIRONMENT_KUBERNETES_EXTERNAL_POSTGRESQL_DB_ACCESS_PORT)

                  echo "Waiting until the database to be fully initialized"
                  sleep 60

  fi
        
  # FOR GENERATING NODESELECTOR VALUES
  generate_nodeselector_values ${ENVIRONMENT_KUBERNETES_EXCHANGE_STATEFUL_NODESELECTOR:-$ENVIRONMENT_KUBERNETES_EXCHANGE_NODESELECTOR} hollaex-stateful
  generate_nodeselector_values ${ENVIRONMENT_KUBERNETES_EXCHANGE_STATELESS_NODESELECTOR:-$ENVIRONMENT_KUBERNETES_EXCHANGE_NODESELECTOR} hollaex-stateless

  helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-server-api \
                    --namespace $ENVIRONMENT_EXCHANGE_NAME \
                    --set DEPLOYMENT_MODE="api" \
                    --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                    --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                    --set stable.replicaCount="${ENVIRONMENT_KUBERNETES_API_SERVER_REPLICAS:-1}" \
                    --set autoScaling.hpa.enable="${ENVIRONMENT_KUBERNETES_API_HPA_ENABLE:-false}" \
                    --set autoScaling.hpa.avgMemory="${ENVIRONMENT_KUBERNETES_API_HPA_AVGMEMORY:-1300000000}" \
                    --set autoScaling.hpa.maxReplicas="${ENVIRONMENT_KUBERNETES_API_HPA_MAXREPLICAS:-4}" \
                    --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                    --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                    --set resources.limits.cpu="${ENVIRONMENT_API_CPU_LIMITS:-1000m}" \
                    --set resources.limits.memory="${ENVIRONMENT_API_MEMORY_LIMITS:-1536Mi}" \
                    --set resources.requests.cpu="${ENVIRONMENT_API_CPU_REQUESTS:-10m}" \
                    --set resources.requests.memory="${ENVIRONMENT_API_MEMORY_REQUESTS:-1536Mi}" \
                    --set podRestart_webhook_url="$ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL" \
                    -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateless.yaml \
                    -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml \
                    $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server

  helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-server-stream \
              --namespace $ENVIRONMENT_EXCHANGE_NAME \
              --set DEPLOYMENT_MODE="stream" \
              --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
              --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
              --set stable.replicaCount="${ENVIRONMENT_KUBERNETES_STREAM_SERVER_REPLICAS:-1}" \
              --set autoScaling.hpa.enable="${ENVIRONMENT_KUBERNETES_STREAM_HPA_ENABLE:-false}" \
              --set autoScaling.hpa.avgMemory="${ENVIRONMENT_KUBERNETES_STREAM_HPA_AVGMEMORY:-300000000}" \
              --set autoScaling.hpa.maxReplicas="${ENVIRONMENT_KUBERNETES_STREAM_HPA_MAXREPLICAS:-4}" \
              --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
              --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
              --set resources.limits.cpu="${ENVIRONMENT_STREAM_CPU_LIMITS:-1000m}" \
              --set resources.limits.memory="${ENVIRONMENT_STREAM_MEMORY_LIMITS:-1536Mi}" \
              --set resources.requests.cpu="${ENVIRONMENT_STREAM_CPU_REQUESTS:-10m}" \
              --set resources.requests.memory="${ENVIRONMENT_STREAM_MEMORY_REQUESTS:-1536Mi}" \
              --set podRestart_webhook_url="$ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL" \
              -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateless.yaml \
              -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml \
              $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server

  helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-server-plugins \
                     --namespace $ENVIRONMENT_EXCHANGE_NAME \
                     --set DEPLOYMENT_MODE="plugins" \
                     --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                     --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                     --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                     --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                     --set resources.limits.cpu="${ENVIRONMENT_PLUGINS_CPU_LIMITS:-500m}" \
                     --set resources.limits.memory="${ENVIRONMENT_PLUGINS_MEMORY_LIMITS:-512Mi}" \
                     --set resources.requests.cpu="${ENVIRONMENT_PLUGINS_CPU_REQUESTS:-10m}" \
                     --set resources.requests.memory="${ENVIRONMENT_PLUGINS_MEMORY_REQUESTS:-128Mi}" \
                     --set podRestart_webhook_url="$ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL" \
                     -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                     -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server

  if [[ "$HOLLAEX_IS_SETUP" == true ]]; then 

    # Running database job for Kubernetes
    kubernetes_database_init launch;

  else 

    # Running database job for Kubernetes
    kubernetes_database_init upgrade;

  fi

  echo "Flushing Redis..."
  kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/flushRedis.js

  echo "Restarting all containers to apply latest database changes..."
  kubectl delete pods --namespace $ENVIRONMENT_EXCHANGE_NAME -l role=$ENVIRONMENT_EXCHANGE_NAME

  echo "Waiting for the containers get fully ready..."
  sleep 15;

  echo "Applying $HOLLAEX_CONFIGMAP_API_NAME ingress rule on the cluster."
  kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

}

function run_and_upgrade_hollaex_network_on_kubernetes() {

  #Creating kubernetes_config directory for generating config for Kubernetes.
  if [[ ! -d "$TEMPLATE_GENERATE_PATH/kubernetes/config" ]]; then
      mkdir $TEMPLATE_GENERATE_PATH/kubernetes;
      mkdir $TEMPLATE_GENERATE_PATH/kubernetes/config;
  fi

  if [[ "$ENVIRONMENT_KUBERNETES_GENERATE_CONFIGMAP_ENABLE" == true ]]; then

      echo "Generating Kubernetes Configmap"
      generate_kubernetes_configmap;

  fi

  if [[ "$ENVIRONMENT_KUBERNETES_GENERATE_SECRET_ENABLE" == true ]]; then

      echo "Generating Kubernetes Secret"
      generate_kubernetes_secret;

  fi


  if [[ "$ENVIRONMENT_KUBERNETES_GENERATE_INGRESS_ENABLE" == true ]]; then

      echo "Generating Kubernetes Ingress"
      generate_kubernetes_ingress;

  fi

  if [[ ! "$IGNORE_SETTINGS" ]]; then 

      echo "Applying latest configmap env on the cluster."
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml

      echo "Applying latest secret on the cluster"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-secret.yaml

  fi

  # Running & Upgrading Databases
  if [[ "$ENVIRONMENT_KUBERNETES_RUN_REDIS" == true ]]; then

      generate_nodeselector_values $ENVIRONMENT_KUBERNETES_REDIS_NODESELECTOR redis

      helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-redis \
                  --namespace $ENVIRONMENT_EXCHANGE_NAME \
                  --set setAuth.secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                  --set resources.limits.cpu="${ENVIRONMENT_REDIS_CPU_LIMITS:-100m}" \
                  --set resources.limits.memory="${ENVIRONMENT_REDIS_MEMORY_LIMITS:-200Mi}" \
                  --set resources.requests.cpu="${ENVIRONMENT_REDIS_CPU_REQUESTS:-10m}" \
                  --set resources.requests.memory="${ENVIRONMENT_REDIS_MEMORY_REQUESTS:-100Mi}" \
                  -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-redis/values.yaml \
                  -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-redis.yaml \
                  $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-redis $(kubernetes_set_backend_image_target $ENVIRONMENT_DOCKER_IMAGE_REDIS_REGISTRY $ENVIRONMENT_DOCKER_IMAGE_REDIS_VERSION) $(set_nodeport_access $ENVIRONMENT_KUBERNETES_ALLOW_EXTERNAL_REDIS_ACCESS $ENVIRONMENT_KUBERNETES_EXTERNAL_REDIS_ACCESS_PORT)
  
  fi

  if [[ "$ENVIRONMENT_KUBERNETES_RUN_POSTGRESQL_DB" == true ]]; then

      generate_nodeselector_values $ENVIRONMENT_KUBERNETES_POSTGRESQL_DB_NODESELECTOR postgresql

      helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-db \
                  --namespace $ENVIRONMENT_EXCHANGE_NAME \
                  --wait \
                  --set pvc.create=true \
                  --set pvc.name="$ENVIRONMENT_EXCHANGE_NAME-postgres-volume" \
                  --set pvc.size="$ENVIRONMENT_KUBERNETES_POSTGRESQL_DB_VOLUMESIZE" \
                  --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                  --set resources.limits.cpu="${ENVIRONMENT_POSTGRESQL_CPU_LIMITS:-100m}" \
                  --set resources.limits.memory="${ENVIRONMENT_POSTGRESQL_MEMORY_LIMITS:-200Mi}" \
                  --set resources.requests.cpu="${ENVIRONMENT_POSTGRESQL_CPU_REQUESTS:-10m}" \
                  --set resources.requests.memory="${ENVIRONMENT_POSTGRESQL_MEMORY_REQUESTS:-100Mi}" \
                  -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-postgres/values.yaml \
                  -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-postgresql.yaml \
                  $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-postgres $(kubernetes_set_backend_image_target $ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_REGISTRY $ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_VERSION) $(set_nodeport_access $ENVIRONMENT_KUBERNETES_ALLOW_EXTERNAL_POSTGRESQL_DB_ACCESS $ENVIRONMENT_KUBERNETES_EXTERNAL_POSTGRESQL_DB_ACCESS_PORT)

                  echo "Waiting until the database to be fully initialized"
                  sleep 60

  fi

  if [[ "$ENVIRONMENT_KUBERNETES_RUN_INFLUXDB" == true ]]; then

      generate_nodeselector_values $ENVIRONMENT_KUBERNETES_INFLUXDB_NODESELECTOR influxdb

      helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-influxdb \
                  --namespace $ENVIRONMENT_EXCHANGE_NAME \
                  --wait \
                  --set pvc.create=true \
                  --set pvc.name="$ENVIRONMENT_EXCHANGE_NAME-influxdb-volume" \
                  --set pvc.size="${ENVIRONMENT_KUBERNETES_INFLUXDB_VOLUMESIZE:-30Gi}" \
                  --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                  --set resources.limits.cpu="${ENVIRONMENT_INFLUXDB_CPU_LIMITS:-100m}" \
                  --set resources.limits.memory="${ENVIRONMENT_INFLUXDB_MEMORY_LIMITS:-200Mi}" \
                  --set resources.requests.cpu="${ENVIRONMENT_INFLUXDB_CPU_REQUESTS:-10m}" \
                  --set resources.requests.memory="${ENVIRONMENT_INFLUXDB_MEMORY_REQUESTS:-100Mi}" \
                  -f $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-influxdb/values.yaml \
                  -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-influxdb.yaml \
                  $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-influxdb $(kubernetes_set_backend_image_target $ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_REGISTRY $ENVIRONMENT_DOCKER_IMAGE_INFLUXDB_VERSION) $(set_nodeport_access $ENVIRONMENT_KUBERNETES_ALLOW_EXTERNAL_INFLUXDB_DB_ACCESS $ENVIRONMENT_KUBERNETES_EXTERNAL_INFLUXDB_DB_ACCESS_PORT)

                  echo "Waiting until the database to be fully initialized"
                  sleep 60

  fi

  if [[ "$ENVIRONMENT_KUBERNETES_RUN_MONGODB" == true ]]; then

      generate_nodeselector_values $ENVIRONMENT_KUBERNETES_MONGODB_NODESELECTOR mongodb

      helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-mongodb \
                  --namespace $ENVIRONMENT_EXCHANGE_NAME \
                  --wait \
                  --set pvc.create=true \
                  --set pvc.size="${ENVIRONMENT_KUBERNETES_MONGODB_VOLUMESIZE:-20Gi}" \
                  --set setAuth.secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                  --set resources.limits.cpu="${ENVIRONMENT_MONGODB_CPU_LIMITS:-100m}" \
                  --set resources.limits.memory="${ENVIRONMENT_MONGODB_MEMORY_LIMITS:-200Mi}" \
                  --set resources.requests.cpu="${ENVIRONMENT_MONGODB_CPU_REQUESTS:-10m}" \
                  --set resources.requests.memory="${ENVIRONMENT_MONGODB_MEMORY_REQUESTS:-100Mi}" \
                  -f $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-mongodb/values.yaml \
                  -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-mongodb.yaml \
                  $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-mongodb $(kubernetes_set_backend_image_target $ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_REGISTRY $ENVIRONMENT_DOCKER_IMAGE_MONGODB_VERSION) $(set_nodeport_access $ENVIRONMENT_KUBERNETES_ALLOW_EXTERNAL_MONGODB_DB_ACCESS $ENVIRONMENT_KUBERNETES_EXTERNAL_MONGODB_DB_ACCESS_PORT)

                  echo "Waiting until the database to be fully initialized"
                  sleep 30

  fi
        
  # FOR GENERATING NODESELECTOR VALUES
  generate_nodeselector_values ${ENVIRONMENT_KUBERNETES_EXCHANGE_STATEFUL_NODESELECTOR:-$ENVIRONMENT_KUBERNETES_EXCHANGE_NODESELECTOR} hollaex-stateful
  generate_nodeselector_values ${ENVIRONMENT_KUBERNETES_EXCHANGE_STATELESS_NODESELECTOR:-$ENVIRONMENT_KUBERNETES_EXCHANGE_NODESELECTOR} hollaex-stateless

  helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-server-api \
                    --namespace $ENVIRONMENT_EXCHANGE_NAME \
                    --set DEPLOYMENT_MODE="api" \
                    --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                    --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                    --set stable.replicaCount="${ENVIRONMENT_KUBERNETES_API_SERVER_REPLICAS:-1}" \
                    --set autoScaling.hpa.enable="${ENVIRONMENT_KUBERNETES_API_HPA_ENABLE:-false}" \
                    --set autoScaling.hpa.avgMemory="${ENVIRONMENT_KUBERNETES_API_HPA_AVGMEMORY:-1300000000}" \
                    --set autoScaling.hpa.maxReplicas="${ENVIRONMENT_KUBERNETES_API_HPA_MAXREPLICAS:-4}" \
                    --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                    --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                    --set resources.limits.cpu="${ENVIRONMENT_API_CPU_LIMITS:-1000m}" \
                    --set resources.limits.memory="${ENVIRONMENT_API_MEMORY_LIMITS:-1536Mi}" \
                    --set resources.requests.cpu="${ENVIRONMENT_API_CPU_REQUESTS:-10m}" \
                    --set resources.requests.memory="${ENVIRONMENT_API_MEMORY_REQUESTS:-1536Mi}" \
                    --set podRestart_webhook_url="$ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL" \
                    -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateless.yaml \
                    -f $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server/values.yaml \
                    $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server

  helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-server-stream \
              --namespace $ENVIRONMENT_EXCHANGE_NAME \
              --set DEPLOYMENT_MODE="stream" \
              --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
              --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
              --set stable.replicaCount="${ENVIRONMENT_KUBERNETES_STREAM_SERVER_REPLICAS:-1}" \
              --set autoScaling.hpa.enable="${ENVIRONMENT_KUBERNETES_STREAM_HPA_ENABLE:-false}" \
              --set autoScaling.hpa.avgMemory="${ENVIRONMENT_KUBERNETES_STREAM_HPA_AVGMEMORY:-300000000}" \
              --set autoScaling.hpa.maxReplicas="${ENVIRONMENT_KUBERNETES_STREAM_HPA_MAXREPLICAS:-4}" \
              --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
              --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
              --set resources.limits.cpu="${ENVIRONMENT_STREAM_CPU_LIMITS:-1000m}" \
              --set resources.limits.memory="${ENVIRONMENT_STREAM_MEMORY_LIMITS:-1536Mi}" \
              --set resources.requests.cpu="${ENVIRONMENT_STREAM_CPU_REQUESTS:-10m}" \
              --set resources.requests.memory="${ENVIRONMENT_STREAM_MEMORY_REQUESTS:-1536Mi}" \
              --set podRestart_webhook_url="$ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL" \
              -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateless.yaml \
              -f $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server/values.yaml \
              $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server

  helm upgrade --install $ENVIRONMENT_EXCHANGE_NAME-server-job \
                     --namespace $ENVIRONMENT_EXCHANGE_NAME \
                     --set DEPLOYMENT_MODE="job" \
                     --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                     --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                     --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                     --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                     --set resources.limits.cpu="${ENVIRONMENT_JOB_CPU_LIMITS:-500m}" \
                     --set resources.limits.memory="${ENVIRONMENT_JOB_MEMORY_LIMITS:-512Mi}" \
                     --set resources.requests.cpu="${ENVIRONMENT_JOB_CPU_REQUESTS:-10m}" \
                     --set resources.requests.memory="${ENVIRONMENT_JOB_MEMORY_REQUESTS:-128Mi}" \
                     --set podRestart_webhook_url="$ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL" \
                     -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                     -f $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server/values.yaml $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server
                     
  helm_dynamic_trading_paris run;

  if [[ "$HOLLAEX_NETWORK_SETUP" == true ]]; then 

    # Running database job for Kubernetes
    kubernetes_hollaex_network_database_init launch;

  else 

    # Running database job for Kubernetes
    kubernetes_hollaex_network_database_init upgrade;

  fi

  echo "Flushing Redis..."
  kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/flushRedis.js

  echo "Restarting all containers to apply latest database changes..."
  kubectl delete pods --namespace $ENVIRONMENT_EXCHANGE_NAME -l role=$ENVIRONMENT_EXCHANGE_NAME

  echo "Waiting for the containers get fully ready..."
  sleep 15;

  echo "Applying $HOLLAEX_CONFIGMAP_API_NAME ingress rule on the cluster."
  kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

}

function hollaex_network_setup_initial_envs() {

    echo "Settings up the initial envs on your HollaEx Network home's settings directory."

    # Generate local nginx conf
    cat > $(pwd)/settings/configmap <<EOL

ENVIRONMENT_EXCHANGE_NAME=hollaex-network

HOLLAEX_CONFIGMAP_API_NAME=hollaex-network

HOLLAEX_CONFIGMAP_DB_DIALECT=postgres
HOLLAEX_CONFIGMAP_DB_SSL=false

HOLLAEX_CONFIGMAP_API_HOST=localhost

HOLLAEX_CONFIGMAP_CURRENCIES=xht,usdt
HOLLAEX_CONFIGMAP_PAIRS=xht-usdt

INDEPENDENT=true

####################################################

HOLLAEX_CONFIGMAP_NODE_ENV=production
HOLLAEX_CONFIGMAP_PORT=10010
HOLLAEX_CONFIGMAP_WEBSOCKET_PORT=10080

HOLLAEX_CONFIGMAP_SEND_EMAIL_TO_SUPPORT=true

HOLLAEX_CONFIGMAP_VAULT_NAME=

HOLLAEX_CONFIGMAP_DB_SSL=false

HOLLAEX_CONFIGMAP_LOG_LEVEL=verbose

ENVIRONMENT_EXCHANGE_RUN_MODE=api,stream,job,engine

ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB=true
ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS=true
ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB=true
ENVIRONMENT_DOCKER_COMPOSE_RUN_MONGODB=true

ENVIRONMENT_KUBERNETES_RUN_POSTGRESQL_DB=true
ENVIRONMENT_KUBERNETES_POSTGRESQL_DB_VOLUMESIZE=25Gi

ENVIRONMENT_KUBERNETES_RUN_REDIS=true

ENVIRONMENT_KUBERNETES_POSTGRESQL_DB_NODESELECTOR="{}"
ENVIRONMENT_KUBERNETES_REDIS_NODESELECTOR="{}"
ENVIRONMENT_KUBERNETES_INFLUXDB_NODESELECTOR="{}"
ENVIRONMENT_KUBERNETES_MONGODB_NODESELECTOR="{}"
ENVIRONMENT_KUBERNETES_EXCHANGE_STATEFUL_NODESELECTOR="{}"
ENVIRONMENT_KUBERNETES_EXCHANGE_STATELESS_NODESELECTOR="{}"

ENVIRONMENT_KUBERNETES_RUN_INFLUXDB=true
ENVIRONMENT_KUBERNETES_INFLUXDB_DB_VOLUMESIZE=20Gi

ENVIRONMENT_KUBERNETES_RUN_MONGODB=true
ENVIRONMENT_KUBERNETES_MONGODB_DB_VOLUMESIZE=20Gi

HOLLAEX_CONFIGMAP_CURRENCIES=xht,usdt
HOLLAEX_CONFIGMAP_PAIRS='xht-usdt'

ENVIRONMENT_DOCKER_IMAGE_VERSION=2.2.4

ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_REGISTRY=postgres
ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_VERSION=10.9-alpine

ENVIRONMENT_DOCKER_IMAGE_REDIS_REGISTRY=redis
ENVIRONMENT_DOCKER_IMAGE_REDIS_VERSION=6.0.9-alpine

ENVIRONMENT_DOCKER_IMAGE_INFLUXDB_REGISTRY=influxdb
ENVIRONMENT_DOCKER_IMAGE_INFLUXDB_VERSION=1.8.3

ENVIRONMENT_DOCKER_IMAGE_MONGODB_REGISTRY=mongo
ENVIRONMENT_DOCKER_IMAGE_MONGODB_VERSION=4.4.6-bionic

ENVIRONMENT_DOCKER_IMAGE_LOCAL_NGINX_REGISTRY=bitholla/nginx-with-certbot
ENVIRONMENT_DOCKER_IMAGE_LOCAL_NGINX_VERSION=1.15.8

ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY=bitholla/hollaex-network-standalone
ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION=

ENVIRONMENT_LOCAL_NGINX_HTTP_PORT=8081
ENVIRONMENT_LOCAL_NGINX_HTTPS_PORT=8082

ENVIRONMENT_KUBERNETES_API_SERVER_REPLICAS=1

ENVIRONMENT_DOCKER_COMPOSE_GENERATE_ENV_ENABLE=true
ENVIRONMENT_DOCKER_COMPOSE_GENERATE_YAML_ENABLE=true
ENVIRONMENT_DOCKER_COMPOSE_GENERATE_NGINX_UPSTREAM=true

ENVIRONMENT_KUBERNETES_GENERATE_CONFIGMAP_ENABLE=true
ENVIRONMENT_KUBERNETES_GENERATE_SECRET_ENABLE=true
ENVIRONMENT_KUBERNETES_GENERATE_INGRESS_ENABLE=true

ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER=

ENVIRONMENT_KUBERNETES_ALLOW_EXTERNAL_POSTGRESQL_DB_ACCESS=false
ENVIRONMENT_KUBERNETES_EXTERNAL_POSTGRESQL_DB_ACCESS_PORT=40000

ENVIRONMENT_KUBERNETES_ALLOW_EXTERNAL_REDIS_ACCESS=false
ENVIRONMENT_KUBERNETES_EXTERNAL_REDIS_ACCESS_PORT=40001

ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL=

ENVIRONMENT_API_CPU_LIMITS=0.1
ENVIRONMENT_API_MEMORY_LIMITS=512Mi
ENVIRONMENT_API_CPU_REQUESTS=0.05
ENVIRONMENT_API_MEMORY_REQUESTS=512Mi

ENVIRONMENT_STREAM_CPU_LIMITS=0.1
ENVIRONMENT_STREAM_MEMORY_LIMITS=256Mi
ENVIRONMENT_STREAM_CPU_REQUESTS=0.05
ENVIRONMENT_STREAM_MEMORY_REQUESTS=256Mi

ENVIRONMENT_JOB_CPU_LIMITS=0.1
ENVIRONMENT_JOB_MEMORY_LIMITS=512Mi
ENVIRONMENT_JOB_CPU_REQUESTS=0.05
ENVIRONMENT_JOB_MEMORY_REQUESTS=256Mi

ENVIRONMENT_ENGINE_CPU_LIMITS=0.1
ENVIRONMENT_ENGINE_MEMORY_LIMITS=512Mi
ENVIRONMENT_ENGINE_CPU_REQUESTS=0.05
ENVIRONMENT_ENGINE_MEMORY_REQUESTS=256Mi

ENVIRONMENT_POSTGRESQL_CPU_LIMITS=0.1
ENVIRONMENT_POSTGRESQL_MEMORY_LIMITS=100Mi
ENVIRONMENT_POSTGRESQL_CPU_REQUESTS=0.1
ENVIRONMENT_POSTGRESQL_MEMORY_REQUESTS=100Mi

ENVIRONMENT_REDIS_CPU_LIMITS=0.1
ENVIRONMENT_REDIS_MEMORY_LIMITS=100Mi
ENVIRONMENT_REDIS_CPU_REQUESTS=0.1
ENVIRONMENT_REDIS_MEMORY_REQUESTS=100Mi

ENVIRONMENT_INFLUXDB_CPU_LIMITS=0.1
ENVIRONMENT_INFLUXDB_MEMORY_LIMITS=100Mi
ENVIRONMENT_INFLUXDB_CPU_REQUESTS=0.1
ENVIRONMENT_INFLUXDB_MEMORY_REQUESTS=100Mi

ENVIRONMENT_KUBERNETES_S3_BACKUP_CRONJOB_RULE='0 1 * * *'
ENVIRONMENT_KUBERNETES_S3_BACKUP_CRONJOB_REGION=
ENVIRONMENT_KUBERNETES_S3_BACKUP_CRONJOB_BUCKET=
ENVIRONMENT_KUBERNETES_S3_BACKUP_CRONJOB_TIMEZONE=UTC

ENVIRONMENT_KUBERNETES_STREAM_SERVER_REPLICAS=1

ENVIRONMENT_KUBERNETES_API_HPA_ENABLE=false
ENVIRONMENT_KUBERNETES_STREAM_HPA_ENABLE=false
ENVIRONMENT_KUBERNETES_API_HPA_AVGMEMORY=1300000000
ENVIRONMENT_KUBERNETES_STREAM_HPA_AVGMEMORY=300000000

ENVIRONMENT_KUBERNETES_API_HPA_MAXREPLICAS=4
ENVIRONMENT_KUBERNETES_STREAM_HPA_MAXREPLICAS=4

EOL

# Generate local nginx conf
    cat > $(pwd)/settings/secret <<EOL

HOLLAEX_SECRET_PUBSUB_HOST=hollaex-network-redis
HOLLAEX_SECRET_PUBSUB_PORT=6379
HOLLAEX_SECRET_PUBSUB_PASSWORD=

HOLLAEX_SECRET_REDIS_HOST=hollaex-network-redis
HOLLAEX_SECRET_REDIS_PORT=6379
HOLLAEX_SECRET_REDIS_PASSWORD=

HOLLAEX_SECRET_DB_HOST=hollaex-network-db
HOLLAEX_SECRET_DB_NAME=network
HOLLAEX_SECRET_DB_PASSWORD=
HOLLAEX_SECRET_DB_PORT=5432
HOLLAEX_SECRET_DB_USERNAME=network

HOLLAEX_SECRET_INFLUX_DB=network
HOLLAEX_SECRET_INFLUX_HOST=hollaex-network-influxdb
HOLLAEX_SECRET_INFLUX_PASSWORD=network
HOLLAEX_SECRET_INFLUX_PORT=8086
HOLLAEX_SECRET_INFLUX_USER=network

HOLLAEX_SECRET_MONGO_DB=network
HOLLAEX_SECRET_MONGO_URL=hollaex-network-mongodb
HOLLAEX_SECRET_MONGO_PORT=27017
HOLLAEX_SECRET_MONGO_USERNAME=network
HOLLAEX_SECRET_MONGO_PASSWORD=network

ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_HOST=docker.io
ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME=
ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD=
ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL=

ENVIRONMENT_KUBERNETES_S3_BACKUP_CRONJOB_ACCESSKEY=
ENVIRONMENT_KUBERNETES_S3_BACKUP_CRONJOB_SECRETKEY=

EOL


}

function add_coin_input() {

  echo "***************************************************************"
  echo "[1/11] Coin Symbol: (eth)"
  printf "\033[2m- This trading symbol is a short hand for this coin.\033[22m\n" 
  read answer

  COIN_CODE=${answer:-eth}

  printf "\n"
  echo "${answer:-eth} ✔"
  printf "\n"

  for i in ${CONFIG_FILE_PATH[@]}; do

    if command grep -q "ENVIRONMENT_ADD_COIN_$(echo $COIN_CODE | tr a-z A-Z)_" $i > /dev/null ; then

      printf "\033[92mDetected configurations for coin $COIN_CODE in your settings file.\033[39m\n"
      echo "Do you want to proceed with these values? (Y/n)"
      read answer

      if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
          
        echo "You picked false. Please confirm the values and run the command again."
        #exit 1;
      
      else 

        echo "Proceeding with stored configurations..."
        export VALUE_IMPORTED_FROM_CONFIGMAP=true

        add_coin_exec;
      
      fi
    
    fi


  done

  echo "***************************************************************"
  echo "[2/11] Full Name of Coin: (Ethereum)"
  printf "\033[2m- The full name of the coin.\033[22m\n" 
  printf "\n"
  read answer

  COIN_FULLNAME=${answer:-Ethereum}

  printf "\n"
  echo "${answer:-Ethereum} ✔"
  printf "\n"

  echo "***************************************************************"
  echo "[3/11] Allow deposit: (Y/n)"
  printf "\033[2m- Allow deposits for this coin. Amount is dependents on user level and what you set later on. \033[22m\n" 
  read answer
  
  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    COIN_ALLOW_DEPOSIT='false'
  
  else

    COIN_ALLOW_DEPOSIT='true'

  fi

  printf "\n"
  echo "${answer:-$COIN_ALLOW_DEPOSIT} ✔"
  printf "\n"

  echo "***************************************************************"
  echo "[4/11] Allow Withdrawal: (Y/n)"
  printf "\033[2m- Allow withdrawals for this coin. Amount is dependents on user level and what you set later on. \033[22m\n"
  read answer
  
  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    COIN_ALLOW_WITHDRAWAL='false'
  
  else

    COIN_ALLOW_WITHDRAWAL='true'

  fi

  printf "\n"
  echo "${answer:-$COIN_ALLOW_WITHDRAWAL} ✔"
  printf "\n"

  echo "***************************************************************"
  echo "[5/11] Fee for Withdrawal: (0.001)"
  printf "\033[2m- Enter the fee amount for when this coin is withdrawn from your exchange. \033[22m\n"
  read answer

  COIN_WITHDRAWAL_FEE=${answer:-0.001}

  printf "\n"
  echo "${answer:-0.001} ✔"
  printf "\n"

  echo "***************************************************************"
  echo "[6/11] Minimum Withdrawal Amount: (0.001)"
  printf "\033[2m- Set the minimum withdrawal for this coin. \033[22m\n"
  read answer

  COIN_MIN=${answer:-0.001}

  printf "\n"
  echo "${answer:-0.001} ✔"
  printf "\n"

  echo "***************************************************************"
  echo "[7/11] Maximum Withdrawal Amount: (10000)"
  printf "\033[2m- Set the maximum withdrawal for this coin. \033[22m\n"
  read answer
  
  COIN_MAX=${answer:-10000}

  printf "\n"
  echo "${answer:-10000} ✔"
  printf "\n"

  echo "***************************************************************"
  echo "[8/11] Increment Amount: (0.001)"
  printf "\033[2m- Set the increment amount that can be adjusted up and down for this coin. \033[22m\n"
  read answer

  COIN_INCREMENT_UNIT=${answer:-0.001}

  printf "\n"
  echo "${answer:-0.001} ✔"
  printf "\n"

  echo "***************************************************************"
  echo "[9/11] Activate Coin: (Y/n)"
  printf "\033[2m- Activate your coin. \033[22m\n"
  read answer
  
  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    COIN_ACTIVE='false'
  
  else

    COIN_ACTIVE='true'

  fi

  printf "\n"
  echo "${answer:-$COIN_ACTIVE} ✔"
  printf "\n"

  function print_coin_add_deposit_level(){ 

    for i in $(set -o posix ; set | grep "DEPOSIT_LIMITS_LEVEL_");

      do printf "$i"

    done;

  }

  function print_coin_add_withdrawal_level(){ 

    for i in $(set -o posix ; set | grep "WITHDRAWAL_LIMITS_LEVEL_");

      do printf "$i"

    done;

  }
  
  echo "*********************************************"
  echo "Symbol: $COIN_CODE"
  echo "Full name: $COIN_FULLNAME"
  echo "Allow deposit: $COIN_ALLOW_DEPOSIT"
  echo "Allow withdrawal: $COIN_ALLOW_WITHDRAWAL"
  echo "Withdrawal Fee: $COIN_WITHDRAWAL_FEE"
  echo "Minimum Withdrawal Amount: $COIN_MIN"
  echo "Maximum Withdrawal Amount: $COIN_MAX"
  echo "Increment size: $COIN_INCREMENT_UNIT"
  echo "Active: $COIN_ACTIVE"
  echo "*********************************************"

  echo "Are the values are all correct? (y/N)"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "You picked false. Please confirm the values and run the command again."
    exit 1;
  
  fi

  save_add_coin_input_at_settings;

}

function save_add_coin_input_at_settings() {

  for i in ${CONFIG_FILE_PATH[@]}; do

    if command grep -q "ENVIRONMENT_USER_HOLLAEX_CORE_" $i > /dev/null ; then
        echo $CONFIGMAP_FILE_PATH
        local CONFIGMAP_FILE_PATH=$i
    fi

  done

  local COIN_PREFIX=$(echo $COIN_CODE | tr a-z A-Z)

  # REMOVE STORED VALUES AT CONFIGMAP FOR COIN 
  if [[ ! "$VALUE_IMPORTED_FROM_CONFIGMAP" ]]; then 
  
    remove_existing_coin_configs_from_settings;

  fi

  # Quoting Coin Fullname to handle space(s).
  local COIN_FULLNAME=\'${COIN_FULLNAME}\'

  save_coin_configs;

}

function save_coin_configs() {

  cat >> $CONFIGMAP_FILE_PATH << EOL

ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_CODE=$COIN_CODE
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_FULLNAME=$COIN_FULLNAME
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_ALLOW_DEPOSIT=$COIN_ALLOW_DEPOSIT
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_ALLOW_WITHDRAWAL=$COIN_ALLOW_WITHDRAWAL
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_WITHDRAWAL_FEE=$COIN_WITHDRAWAL_FEE
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_MIN=$COIN_MIN
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_MAX=$COIN_MAX
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_INCREMENT_UNIT=$COIN_INCREMENT_UNIT
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_ACTIVE=$COIN_ACTIVE

EOL
}

function save_pairs_configs() {

  cat >> $CONFIGMAP_FILE_PATH << EOL

ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_PAIR_CODE=$PAIR_CODE
ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_PAIR_BASE=$PAIR_BASE
ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_PAIR_2=$PAIR_2
ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_TAKER_FEES=$TAKER_FEES_PARSED
ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_MAKER_FEES=$MAKER_FEES_PARSED
ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_MIN_SIZE=$MIN_SIZE
ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_MAX_SIZE=$MAX_SIZE
ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_MIN_PRICE=$MIN_PRICE
ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_MAX_PRICE=$MAX_PRICE
ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_INCREMENT_SIZE=$INCREMENT_SIZE
ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_INCREMENT_PRICE=$INCREMENT_PRICE
ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_PAIR_ACTIVE=$PAIR_ACTIVE

EOL

}

function export_add_coin_configuration_env() {

  COIN_CODE_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_CODE
  COIN_FULLNAME_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_FULLNAME
  COIN_ALLOW_DEPOSIT_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_ALLOW_DEPOSIT
  COIN_ALLOW_WITHDRAWAL_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_ALLOW_WITHDRAWAL
  COIN_WITHDRAWAL_FEE_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_WITHDRAWAL_FEE
  COIN_MIN_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_MIN
  COIN_MAX_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_MAX
  COIN_INCREMENT_UNIT_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_INCREMENT_UNIT
  COIN_ACTIVE_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_ACTIVE

  if [[ "$VALUE_IMPORTED_FROM_CONFIGMAP" ]]; then

    export COIN_CODE_OVERRIDE=$(echo ${COIN_CODE_OVERRIDE})
    export COIN_FULLNAME_OVERRIDE=$(echo ${COIN_FULLNAME_OVERRIDE})
    export COIN_ALLOW_DEPOSIT_OVERRIDE=$(echo ${COIN_ALLOW_DEPOSIT_OVERRIDE})
    export COIN_ALLOW_WITHDRAWAL_OVERRIDE=$(echo ${COIN_ALLOW_WITHDRAWAL_OVERRIDE})
    export COIN_WITHDRAWAL_FEE_OVERRIDE=$(echo ${COIN_WITHDRAWAL_FEE_OVERRIDE})
    export COIN_MIN_OVERRIDE=$(echo ${COIN_MIN_OVERRIDE})
    export COIN_MAX_OVERRIDE=$(echo ${COIN_MAX_OVERRIDE})
    export COIN_INCREMENT_UNIT_OVERRIDE=$(echo ${COIN_INCREMENT_UNIT_OVERRIDE})
    export COIN_ACTIVE_OVERRIDE=$(echo ${COIN_ACTIVE_OVERRIDE})

  else 

    export $(echo $COIN_CODE_OVERRIDE)=$COIN_CODE
    export $(echo $COIN_FULLNAME_OVERRIDE)=$COIN_FULLNAME
    export $(echo $COIN_ALLOW_DEPOSIT_OVERRIDE)=$COIN_ALLOW_DEPOSIT
    export $(echo $COIN_ALLOW_WITHDRAWAL_OVERRIDE)=$COIN_ALLOW_WITHDRAWAL
    export $(echo $COIN_WITHDRAWAL_FEE_OVERRIDE)=$COIN_WITHDRAWAL_FEE
    export $(echo $COIN_MIN_OVERRIDE)=$COIN_MIN
    export $(echo $COIN_MAX_OVERRIDE)=$COIN_MAX
    export $(echo $COIN_INCREMENT_UNIT_OVERRIDE)=$COIN_INCREMENT_UNIT
    export $(echo $COIN_ACTIVE_OVERRIDE)=$COIN_ACTIVE
  
  fi

}

function apply_pairs_config_to_settings_file() {

  # Applying pair (pairs) configs to settings file.
  BITHOLLA_USER_EXCHANGE_PAIRS_COUNT=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS" | jq '.| length ')
  BITHOLLA_USER_EXCHANGE_PAIRS_COUNT=$(($BITHOLLA_USER_EXCHANGE_PAIRS_COUNT-1))

  for ((i=0;i<=BITHOLLA_USER_EXCHANGE_PAIRS_COUNT;i++)); do

      export PAIR_BASE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS[$i].BASE_ASSET")
      export PAIR_2=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS[$i].PRICED_ASSET")
      export TAKER_FEES_PARSED=\'$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS[$i].TAKER_FEE" | tr -d '\n')\'
      export MAKER_FEES_PARSED=\'$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS[$i].MAKER_FEE" | tr -d '\n')\'
      export MIN_SIZE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS[$i].MINIMUM_TRADABLE_AMOUNT")
      export MAX_SIZE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS[$i].MAXIMUM_TRADABLE_AMOUNT")
      export MIN_PRICE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS[$i].MINIMUM_TRADABLE_PRICE")
      export MAX_PRICE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS[$i].MAXIMUM_TRADABLE_PRICE")
      export INCREMENT_SIZE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS[$i].INCREMENT_AMOUNT")
      export INCREMENT_PRICE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS[$i].INCREMENT_PRICE")

      if [[ "$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS[$i].PAIR_ACTIVATE")" == "Y" || "$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS[$i].PAIR_ACTIVATE")" == "true" ]]; then

          export PAIR_ACTIVE_BOOL=true
      
      else 

          export PAIR_ACTIVE_BOOL=false
      
      fi 

      export PAIR_ACTIVE=${PAIR_ACTIVE_BOOL}
      export PAIR_CODE=$(echo "${PAIR_BASE}-${PAIR_2}") 

      export PAIR_PREFIX="$(echo $PAIR_BASE | tr a-z A-Z)_$(echo $PAIR_2 | tr a-z A-Z)"

      remove_existing_pairs_configs_from_settings;

      save_pairs_configs;

  done;

}

function apply_coins_config_to_settings_file() {

  # Applying coin (asset) configs to settings file.

  BITHOLLA_USER_EXCHANGE_ASSETS_COUNT=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ASSETS" | jq '.| length ')
  BITHOLLA_USER_EXCHANGE_ASSETS_COUNT=$(($BITHOLLA_USER_EXCHANGE_ASSETS_COUNT-1))

  for ((i=0;i<=BITHOLLA_USER_EXCHANGE_ASSETS_COUNT;i++)); do

    export COIN_CODE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ASSETS[$i].ASSET_SYMBOL") 
    export COIN_FULLNAME=\'$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ASSETS[$i].ASSET_NAME")\'

    export COIN_ALLOW_DEPOSIT=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ASSETS[$i].ASSET_ALLOW_DEPOSITS")

    if [[ "$COIN_ALLOW_DEPOSIT" == "Y" ]]; then
        export COIN_ALLOW_DEPOSIT="true"
    elif [[ "$COIN_ALLOW_DEPOSIT" == "N" ]]; then
        export COIN_ALLOW_DEPOSIT="false"
    fi

    export COIN_ALLOW_WITHDRAWAL=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ASSETS[$i].ASSET_ALLOW_WITHDRAWAL")
    
    if [[ "$COIN_ALLOW_WITHDRAWAL" == "Y" ]]; then
        export COIN_ALLOW_WITHDRAWAL="true"
    elif [[ "$COIN_ALLOW_WITHDRAWAL" == "N" ]]; then
        export COIN_ALLOW_WITHDRAWAL="false"
    fi

    export COIN_WITHDRAWAL_FEE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ASSETS[$i].ASSET_WITHDRAWAL_FEE")
    export COIN_MIN=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ASSETS[$i].ASSET_MINIMUM_WITHDRAWAL")
    export COIN_MAX=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ASSETS[$i].ASSET_MAXIMUM_WITHDRAWAL")
    export COIN_INCREMENT_UNIT=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ASSETS[$i].ASSET_INCREMENT_AMOUNT")
    export COIN_DEPOSIT_LIMITS_PARSED=\'$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ASSETS[$i].deposit" | tr -d '\n')\'
    export COIN_WITHDRAWAL_LIMITS_PARSED=\'$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ASSETS[$i].deposit" | tr -d '\n')\'

    export COIN_ACTIVE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ASSETS[$i].ASSET_ACTIVATE")

    if [[ "$COIN_ACTIVE" == "Y" ]]; then
        export COIN_ACTIVE="true"
    elif [[ "$COIN_ACTIVE" == "N" ]]; then
        export COIN_ACTIVE="false"
    fi

    export COIN_PREFIX=$(echo ${COIN_CODE} | tr a-z A-Z)

    remove_existing_coin_configs_from_settings;

    save_coin_configs;

  done;


}

function remove_existing_coin_configs_from_settings() {

  if command grep -q "ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN" $CONFIGMAP_FILE_PATH > /dev/null ; then

    grep -v "ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN" $CONFIGMAP_FILE_PATH > temp && mv temp $CONFIGMAP_FILE_PATH

  fi

}

function remove_existing_pairs_configs_from_settings() {

   if command grep -q "ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}" $CONFIGMAP_FILE_PATH > /dev/null ; then

      grep -v "ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}" $CONFIGMAP_FILE_PATH > temp && mv temp $CONFIGMAP_FILE_PATH

    fi
    
}

function add_coin_exec() {

  local COIN_PREFIX=$(echo $COIN_CODE | tr a-z A-Z)

  export_add_coin_configuration_env;

  if [[ "$USE_KUBERNETES" ]]; then

    function generate_kubernetes_add_coin_values() {

    # Generate Kubernetes Configmap
    cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/add-coin.yaml <<EOL
job:
  enable: true
  mode: add_coin
  env:
    coin_code: $(echo ${!COIN_CODE_OVERRIDE})
    coin_fullname: $(echo ${!COIN_FULLNAME_OVERRIDE})
    coin_allow_deposit: $(echo ${!COIN_ALLOW_DEPOSIT_OVERRIDE})
    coin_allow_withdrawal: $(echo ${!COIN_ALLOW_WITHDRAWAL_OVERRIDE})
    coin_withdrawal_fee: $(echo ${!COIN_WITHDRAWAL_FEE_OVERRIDE})
    coin_min: $(echo ${!COIN_MIN_OVERRIDE})
    coin_max: $(echo ${!COIN_MAX_OVERRIDE})
    coin_increment_unit: $(echo ${!COIN_INCREMENT_UNIT_OVERRIDE})
    coin_active: $(echo ${!COIN_ACTIVE_OVERRIDE})
EOL

    }

    generate_kubernetes_add_coin_values;

    # Only tries to attempt remove ingress rules from Kubernetes if it exists.
    # if ! command kubectl get ingress -n $ENVIRONMENT_EXCHANGE_NAME > /dev/null; then
    
    #     echo "Removing $HOLLAEX_CONFIGMAP_API_NAME ingress rule on the cluster."
    #     kubectl delete -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    # fi

    echo "Adding new coin $COIN_CODE on Kubernetes"
    
    if command helm install $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_CODE \
                            --namespace $ENVIRONMENT_EXCHANGE_NAME \
                            --set job.enable="true" \
                            --set job.mode="add_coin" \
                            --set DEPLOYMENT_MODE="api" \
                            --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                            --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                            --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                            --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                            -f $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server/values.yaml \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/add-coin.yaml \
                            $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server; then

      echo "Kubernetes Job has been created for adding new coin $COIN_CODE."

      echo "Waiting until Job get completely run"
      sleep 60;

    else 

      printf "\033[91mFailed to create Kubernetes Job for adding new coin $COIN_CODE, Please confirm your input values and try again.\033[39m\n"
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_CODE

      # echo "Allowing exchange external connections"
      # kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_CODE --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Coin $COIN_CODE has been successfully added on your exchange!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_CODE

      echo "Removing created Kubernetes Job for adding new coin..."
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_CODE

      echo "Updating settings file to add new $COIN_CODE."
      for i in ${CONFIG_FILE_PATH[@]}; do

        if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then

            CONFIGMAP_FILE_PATH=$i
            
            if ! command grep -q "HOLLAEX_CONFIGMAP_CURRENCIES.*${COIN_CODE}.*" $i ; then

              HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE="${HOLLAEX_CONFIGMAP_CURRENCIES},${COIN_CODE}"
              sed -i.bak "s/$HOLLAEX_CONFIGMAP_CURRENCIES/$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
              rm $CONFIGMAP_FILE_PATH.bak

            else

              HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE=$HOLLAEX_CONFIGMAP_CURRENCIES
                
            fi

        fi

      done

      if [[ ! -f "$TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml" ]]; then 

        echo "Generating Kubernetes Configmap."
        generate_kubernetes_configmap;
      
      fi

      # Adding new value directly at generated env / configmap file
      sed -i.bak "s/$HOLLAEX_CONFIGMAP_CURRENCIES/$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml
      rm $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml.bak

      export HOLLAEX_CONFIGMAP_CURRENCIES=$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE
      echo "Current Currencies: ${HOLLAEX_CONFIGMAP_CURRENCIES}"

      echo "Applying configmap on the namespace"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml

      if [[ ! "$IS_HOLLAEX_SETUP" ]]; then
        
        # Running database job for Kubernetes
        echo "Applying changes on database..."
        kubernetes_hollaex_network_database_init upgrade;

      fi

      hollaex_ascii_coin_has_been_added;

    else

      printf "\033[91mFailed to add coin $COIN_CODE! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_CODE
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_CODE

      # echo "Allowing exchange external connections"
      # kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml
      
    fi

    elif [[ ! "$USE_KUBERNETES" ]]; then


      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"
          
      # # Overriding container prefix for develop server
      # if [[ "$IS_DEVELOP" ]]; then
        
      #   CONTAINER_PREFIX=

      # fi

      # echo "Shutting down Nginx to block exchange external access"
      # docker stop $(docker ps | grep $ENVIRONMENT_EXCHANGE_NAME-nginx | cut -f1 -d " ")

      echo "Adding new coin $(echo ${!COIN_CODE_OVERRIDE}) on local exchange"
      if command docker exec --env "COIN_FULLNAME=$(echo ${!COIN_FULLNAME_OVERRIDE})" \
                  --env "COIN_CODE=$(echo ${!COIN_CODE_OVERRIDE})" \
                  --env "COIN_ALLOW_DEPOSIT=$(echo ${!COIN_ALLOW_DEPOSIT_OVERRIDE})" \
                  --env "COIN_ALLOW_WITHDRAWAL=$(echo ${!COIN_ALLOW_WITHDRAWAL_OVERRIDE})" \
                  --env "COIN_WITHDRAWAL_FEE=$(echo ${!COIN_WITHDRAWAL_FEE_OVERRIDE})" \
                  --env "COIN_MIN=$(echo ${!COIN_MIN_OVERRIDE})" \
                  --env "COIN_MAX=$(echo ${!COIN_MAX_OVERRIDE})" \
                  --env "COIN_INCREMENT_UNIT=$(echo ${!COIN_INCREMENT_UNIT_OVERRIDE})" \
                  --env "COIN_ACTIVE=$(echo ${!COIN_ACTIVE_OVERRIDE})"  \
                  ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                  node tools/dbs/addCoin.js; then

         echo "Updating configmap file to add new $COIN_CODE."
         for i in ${CONFIG_FILE_PATH[@]}; do

            if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then

              CONFIGMAP_FILE_PATH=$i
              
              if ! command grep -q "HOLLAEX_CONFIGMAP_CURRENCIES.*${COIN_CODE}.*" $i ; then

                HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE="${HOLLAEX_CONFIGMAP_CURRENCIES},${COIN_CODE}"
                sed -i.bak "s/$HOLLAEX_CONFIGMAP_CURRENCIES/$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
                rm $CONFIGMAP_FILE_PATH.bak

              else

                export HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE=$HOLLAEX_CONFIGMAP_CURRENCIES
                
              fi

            fi

         done

        sed -i.bak "s/$HOLLAEX_CONFIGMAP_CURRENCIES/$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME.env.local
        rm $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME.env.local.bak

        export HOLLAEX_CONFIGMAP_CURRENCIES=$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE
        echo -e "\nCurrent currencies: ${HOLLAEX_CONFIGMAP_CURRENCIES}\n"
        
        if [[ ! "$IS_HOLLAEX_SETUP" ]]; then

          echo "Running database triggers"
          docker exec --env "CURRENCIES=${HOLLAEX_CONFIGMAP_CURRENCIES}" ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js > /dev/null
        
        fi

        hollaex_ascii_coin_has_been_added;

      else

        printf "\033[91mFailed to add new coin $COIN_CODE on local exchange. Please confirm your input values and try again.\033[39m\n"

        # if  [[ "$IS_DEVELOP" ]]; then

        #   # Restarting containers after database init jobs.
        #   echo "Restarting containers to apply database changes."
        #   docker-compose -f $HOLLAEX_CORE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml stop
        #   docker-compose -f $HOLLAEX_CORE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d

        # else

        #   # Restarting containers after database init jobs.
        #   echo "Restarting containers to apply database changes."
        #   docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml stop
        #   docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d

        # fi

        # exit 1;

      fi
      
  fi

  if [[ "$VALUE_IMPORTED_FROM_CONFIGMAP" ]] && ! [[ "$IS_HOLLAEX_SETUP" ]]; then

    exit 0;

  fi

}

function remove_coin_input() {

  printf "\nCurrent coins available: \033[1m$HOLLAEX_CONFIGMAP_CURRENCIES\033[0m"
  printf "\n\033[93mWarning: There always should be at least 2 coins remain.\033[39m\n\n"

  echo "***************************************************************"
  echo "[1/1] Coin Symbol: "
  printf "\n"
  read answer

  export COIN_CODE=$answer

  printf "\n"
  echo "${answer:-$COIN_CODE} ✔"
  printf "\n"

  if [[ -z "$answer" ]]; then

    echo "Your value is empty. Please confirm your input and run the command again."
    exit 1;
  
  fi
  
  echo "*********************************************"
  echo "Symbol: $COIN_CODE"
  echo "*********************************************"

  echo "Are the sure you want to remove this coin from your exchange? (y/N)"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "You picked false. Please confirm the values and run the command again."
    exit 1;
  
  fi

}

function remove_coin_exec() {

  IFS=',' read -ra CURRENT_CURRENCIES <<< "${HOLLAEX_CONFIGMAP_CURRENCIES}"

  if (( "${#CURRENT_CURRENCIES[@]}" <= "2" )); then

    printf "\n\033[91mError: You should have at least 2 currencies on your exchange.\033[39m\n"
    echo "Current Currencies : ${HOLLAEX_CONFIGMAP_CURRENCIES}."
    printf "Exiting...\n\n"

    exit 1;

  fi

  if [[ $(echo ${HOLLAEX_CONFIGMAP_PAIRS} | grep $COIN_CODE) ]]; then

    printf "\n\033[91mError: You can't remove coin $COIN_CODE which already being used by trading pair.\033[39m\n"
    echo "Current Trading Pair(s) : ${HOLLAEX_CONFIGMAP_PAIRS}."
    printf "Exiting...\n\n"

    exit 1;

  fi

  if [[ "$USE_KUBERNETES" ]]; then

  # Only tries to attempt remove ingress rules from Kubernetes if it exists.
  # if ! command kubectl get ingress -n $ENVIRONMENT_EXCHANGE_NAME > /dev/null; then
  
  #     echo "Removing $HOLLAEX_CONFIGMAP_API_NAME ingress rule on the cluster."
  #     kubectl delete -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

  # fi

  echo "Removing existing coin $COIN_CODE on Kubernetes"
    
    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_CODE \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set job.enable="true" \
                --set job.mode="remove_coin" \
                --set job.env.COIN_CODE="$COIN_CODE" \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server; then

      echo "Kubernetes Job has been created for removing existing coin $COIN_CODE."

      echo "Waiting until Job get completely run"
      sleep 30;

    else 

      printf "\033[91mFailed to create Kubernetes Job for removing existing coin $COIN_CODE, Please confirm your input values and try again.\033[39m\n"
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_CODE

      echo "Allowing exchange external connections"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_CODE \
            --namespace $ENVIRONMENT_EXCHANGE_NAME \
            -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Coin $COIN_CODE has been successfully removed on your exchange!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_CODE

      echo "Removing created Kubernetes Job for removing existing coin..."
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_CODE

      echo "Updating settings file to remove $COIN_CODE."
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          if [[ "$COIN_CODE" == "hex" ]]; then
            HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HOLLAEX_CONFIGMAP_CURRENCIES//$COIN_CODE,}")
          else
            HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HOLLAEX_CONFIGMAP_CURRENCIES//,$COIN_CODE}")
          fi
          sed -i.bak "s/$HOLLAEX_CONFIGMAP_CURRENCIES/$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
          rm $CONFIGMAP_FILE_PATH.bak
      fi

      done

      #Removing targeted coin directly at .configmap file for Kubernetes.
      sed -i.bak "s/$HOLLAEX_CONFIGMAP_CURRENCIES/$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml
      rm $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml.bak

      export HOLLAEX_CONFIGMAP_CURRENCIES=$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE
      echo "Current Currencies: ${HOLLAEX_CONFIGMAP_CURRENCIES}"

      # load_config_variables;
      # generate_kubernetes_configmap;

      echo "Applying configmap on the namespace"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml

      # Running database job for Kubernetes
      echo "Applying changes on database..."
      kubernetes_database_init upgrade;

      echo "Coin $COIN_CODE has been successfully removed."
      echo "Please run 'hollaex restart --kube' to apply it."

    else

      printf "\033[91mFailed to remove existing coin $COIN_CODE! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_CODE
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_CODE

    fi

  elif [[ ! "$USE_KUBERNETES" ]]; then

      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

      # # Overriding container prefix for develop server
      # if [[ "$IS_DEVELOP" ]]; then
        
      #   CONTAINER_PREFIX=

      # fi

      # echo "Shutting down Nginx to block exchange external access"
      # docker stop $(docker ps -a | grep $ENVIRONMENT_EXCHANGE_NAME-nginx | cut -f1 -d " ")

    echo "Removing new coin $COIN_CODE on local docker"
    if command docker exec --env "COIN_CODE=${COIN_CODE}" \
                ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                node tools/dbs/removeCoin.js; then

      echo "Updating settings file to remove $COIN_CODE."
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          IFS="," read -ra CURRENCIES_TO_ARRAY <<< "${HOLLAEX_CONFIGMAP_CURRENCIES}"

          local REVOME_SELECTED_CURRENCY=${CURRENCIES_TO_ARRAY[@]/$COIN_CODE}
          local CURRENCIES_ARRAY_TO_STRING=$(echo ${REVOME_SELECTED_CURRENCY[@]} | tr -d '') 
          local CURRENCIES_STRING_TO_COMMNA_SEPARATED=${CURRENCIES_ARRAY_TO_STRING// /,}

          sed -i.bak "s/$HOLLAEX_CONFIGMAP_CURRENCIES/$CURRENCIES_STRING_TO_COMMNA_SEPARATED/" $CONFIGMAP_FILE_PATH

          rm $CONFIGMAP_FILE_PATH.bak
      fi  

      done

      export HOLLAEX_CONFIGMAP_CURRENCIES=$CURRENCIES_STRING_TO_COMMNA_SEPARATED

      # Removing directly from generated env file
      sed -i.bak "s/$HOLLAEX_CONFIGMAP_CURRENCIES/$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME.env.local
      rm $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME.env.local.bak
      
      echo "Current Currencies: ${HOLLAEX_CONFIGMAP_CURRENCIES}"

      #  if  [[ "$IS_DEVELOP" ]]; then

      #   # Restarting containers after database init jobs.
      #   echo "Restarting containers to apply database changes."
      #   docker-compose -f $HOLLAEX_CORE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml stop
      #   docker-compose -f $HOLLAEX_CORE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d


      # else

      #   # Restarting containers after database init jobs.
      #   echo "Restarting containers to apply database changes."
      #   docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml stop
      #   docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d

      # fi

      # Running database triggers
      docker exec --env="CURRENCIES=${HOLLAEX_CONFIGMAP_CURRENCIES}" ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js > /dev/null

      echo "Coin $COIN_CODE has been successfully removed."
      echo "Please run 'hollaex restart' to apply it."

    else

        printf "\033[91mFailed to remove coin $COIN_CODE on local exchange. Please confirm your input values and try again.\033[39m\n"
        # exit 1;

        # if  [[ "$IS_DEVELOP" ]]; then

        #   # Restarting containers after database init jobs.
        #   echo "Restarting containers to apply database changes."
        #   docker-compose -f $HOLLAEX_CORE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml stop
        #   docker-compose -f $HOLLAEX_CORE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d

        # else

        #   # Restarting containers after database init jobs.
        #   echo "Restarting containers to apply database changes."
        #   docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml stop
        #   docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d

        # fi

    fi

  fi

}

function add_pair_input() {

  echo "***************************************************************"
  echo "[1/10] Name of new Trading Pair : (eth-usdt)"
  printf "\033[2m- First enter the base currency (eth) with a dash (-) followed be the second quoted currency (usdt). \033[22m\n"
  read answer

  PAIR_CODE=${answer:-eth-usdt}
  PAIR_BASE=$(echo $PAIR_CODE | cut -f1 -d '-')
  PAIR_2=$(echo $PAIR_CODE | cut -f2 -d '-')

  printf "\n"
  echo "${answer:-eth-usdt} ✔"
  printf "\n"

  for i in ${CONFIG_FILE_PATH[@]}; do

    if command grep -q "ENVIRONMENT_ADD_PAIR_$(echo $PAIR_BASE | tr a-z A-Z)_$(echo $PAIR_2 | tr a-z A-Z)_" $i > /dev/null ; then

      printf "\033[92mDetected configurations for trading pair $PAIR_CODE in your settings file.\033[39m\n"
      echo "Do you want to proceed with these values?? (Y/n)"
      read answer

      if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
          
        echo "You picked false. Please confirm the values and run the command again."
        #exit 1;
      
      else 

        echo "Proceeding with stored configurations..."
        export VALUE_IMPORTED_FROM_CONFIGMAP=true

        add_pair_exec;

      fi

    fi


  done

  echo "***************************************************************"
  echo "[4/10] Minimum Amount: (0.00001)"
  printf "\033[2m- Minimum $PAIR_BASE amount that can be traded for this pair. \033[22m\n"
  read answer
  
  MIN_SIZE=${answer:-0.00001}

  printf "\n"
  echo "${answer:-0.00001} ✔"
  printf "\n"

  echo "***************************************************************"
  echo "[5/10] Maximum Amount: (10000000)"
  printf "\033[2m- Maximum $PAIR_BASE amount that can be traded for this pair. \033[22m\n"
  read answer

  MAX_SIZE=${answer:-10000000}

  printf "\n"
  echo "${answer:-10000000} ✔"
  printf "\n"

  echo "***************************************************************"
  echo "[6/10] Minimum Price: (0.000001)"
  printf "\033[2m- Minimum $PAIR_2 quoated trading price that can be traded for this pair. \033[22m\n"
  read answer

  MIN_PRICE=${answer:-0.000001}

  printf "\n"
  echo "${answer:-0.000001} ✔"
  printf "\n"

  echo "***************************************************************"
  echo "[7/10] Maximum Price: (1000000)"
  printf "\033[2m- Maximum $PAIR_2 quoated trading price that can be traded for this pair. \033[22m\n"
  read answer

  MAX_PRICE=${answer:-1000000}

  printf "\n"
  echo "${answer:-1000000} ✔"
  printf "\n"

  echo "***************************************************************"
  echo "[8/10] Increment Amount: (0.001)"
  printf "\033[2m- The increment $PAIR_BASE amount allowed to be adjusted up and down. \033[22m\n"
  read answer

  INCREMENT_SIZE=${answer:-0.001}

  printf "\n"
  echo "${answer:-0.001} ✔"
  printf "\n"

  echo "***************************************************************"
  echo "[9/10] Increment Price: (0.001)"
  printf "\033[2m- The price $PAIR_2 increment allowed to be adjusted up and down. \033[22m\n"
  read answer

  INCREMENT_PRICE=${answer:-0.001}

  printf "\n"
  echo "${answer:-0.001} ✔"
  printf "\n"

  echo "***************************************************************"
  echo "[10/10] Activate: (Y/n) [Default: y]"
  printf "\033[2m- Activate this trading pair. \033[22m\n"
  read answer
  
  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    PAIR_ACTIVE=false
  
  else

    PAIR_ACTIVE=true

  fi

  printf "\n"
  echo "${answer:-$PAIR_ACTIVE} ✔"
  printf "\n"

  
  echo "*********************************************"
  echo "Full name: $PAIR_CODE"
  echo "First currency: $PAIR_BASE"
  echo "Second currency: $PAIR_2"
  echo "Minimum size: $MIN_SIZE"
  echo "Maximum size: $MAX_SIZE"
  echo "Minimum price: $MIN_PRICE"
  echo "Maximum price: $MAX_PRICE"
  echo "Increment size: $INCREMENT_SIZE"
  echo "Increment price: $INCREMENT_PRICE"
  echo "Active: $PAIR_ACTIVE"
  echo "*********************************************"

  echo "Are the values are all correct? (y/N)"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "You picked false. Please confirm the values and run the command again."
    exit 1;
  
  fi

  save_add_pair_input_at_settings;

}

function save_add_pair_input_at_settings() {

  for i in ${CONFIG_FILE_PATH[@]}; do

    if command grep -q "ENVIRONMENT_USER_HOLLAEX_CORE_" $i > /dev/null ; then
        echo $CONFIGMAP_FILE_PATH
        local CONFIGMAP_FILE_PATH=$i
    fi

  done

  export PAIR_PREFIX="$(echo $PAIR_BASE | tr a-z A-Z)_$(echo $PAIR_2 | tr a-z A-Z)"

   # REMOVE STORED VALUES AT CONFIGMAP FOR COIN 
  if [[ ! "$VALUE_IMPORTED_FROM_CONFIGMAP" ]]; then 
  
    remove_existing_pairs_configs_from_settings;

  fi

  save_pairs_configs;

}


function export_add_pair_configuration_env() {

  PAIR_CODE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_PAIR_CODE
  PAIR_BASE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_PAIR_BASE
  PAIR_2_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_PAIR_2
  MIN_SIZE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_MIN_SIZE
  MAX_SIZE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_MAX_SIZE
  MIN_PRICE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_MIN_PRICE
  MAX_PRICE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_MAX_PRICE
  INCREMENT_SIZE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_INCREMENT_SIZE
  INCREMENT_PRICE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_INCREMENT_PRICE
  PAIR_ACTIVE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_PAIR_ACTIVE


  if [[ "$VALUE_IMPORTED_FROM_CONFIGMAP" ]]; then

    PAIR_CODE_OVERRIDE=$(echo ${PAIR_CODE_OVERRIDE})
    PAIR_BASE_OVERRIDE=$(echo ${PAIR_BASE_OVERRIDE})
    PAIR_2_OVERRIDE=$(echo ${PAIR_2_OVERRIDE})
    MIN_SIZE_OVERRIDE=$(echo ${MIN_SIZE_OVERRIDE})
    MAX_SIZE_OVERRIDE=$(echo ${MAX_SIZE_OVERRIDE})
    MIN_PRICE_OVERRIDE=$(echo ${MIN_PRICE_OVERRIDE})
    MAX_PRICE_OVERRIDE=$(echo ${MAX_PRICE_OVERRIDE})
    INCREMENT_SIZE_OVERRIDE=$(echo ${INCREMENT_SIZE_OVERRIDE})
    INCREMENT_PRICE_OVERRIDE=$(echo ${INCREMENT_PRICE_OVERRIDE})
    PAIR_ACTIVE_OVERRIDE=$(echo ${PAIR_ACTIVE_OVERRIDE})

  else 

    export $(echo $PAIR_CODE_OVERRIDE)=$PAIR_CODE
    export $(echo $PAIR_BASE_OVERRIDE)=$PAIR_BASE
    export $(echo $PAIR_2_OVERRIDE)=$PAIR_2
    export $(echo $MIN_SIZE_OVERRIDE)=$MIN_SIZE
    export $(echo $MAX_SIZE_OVERRIDE)=$MAX_SIZE
    export $(echo $MIN_PRICE_OVERRIDE)=$MIN_PRICE
    export $(echo $MAX_PRICE_OVERRIDE)=$MAX_PRICE
    export $(echo $INCREMENT_SIZE_OVERRIDE)=$INCREMENT_SIZE
    export $(echo $INCREMENT_PRICE_OVERRIDE)=$INCREMENT_PRICE
    export $(echo $PAIR_ACTIVE_OVERRIDE)=$PAIR_ACTIVE
  
  fi

}


function add_pair_exec() {

  export PAIR_PREFIX="$(echo $PAIR_BASE | tr a-z A-Z)_$(echo $PAIR_2 | tr a-z A-Z)"

  export_add_pair_configuration_env;

  if [[ "$USE_KUBERNETES" ]]; then

    function generate_kubernetes_add_pair_values() {

    # Generate Kubernetes Configmap
    cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/add-pair.yaml <<EOL
job:
  enable: true
  mode: add_pair
  env:
    pair_code: $(echo ${!PAIR_CODE_OVERRIDE})
    pair_base: $(echo ${!PAIR_BASE_OVERRIDE})
    pair_2: $(echo ${!PAIR_2_OVERRIDE})
    min_size: $(echo ${!MIN_SIZE_OVERRIDE})
    max_size: $(echo ${!MAX_SIZE_OVERRIDE})
    min_price: $(echo ${!MIN_PRICE_OVERRIDE})
    max_price: $(echo ${!MAX_PRICE_OVERRIDE})
    increment_size: $(echo ${!INCREMENT_SIZE_OVERRIDE})
    increment_price: $(echo ${!INCREMENT_PRICE_OVERRIDE})
    pair_active: $(echo ${!PAIR_ACTIVE_OVERRIDE})
EOL

      }

    generate_kubernetes_add_pair_values;

    # Only tries to attempt remove ingress rules from Kubernetes if it exists.
    # if ! command kubectl get ingress -n $ENVIRONMENT_EXCHANGE_NAME > /dev/null; then
    
    #     echo "Removing $HOLLAEX_CONFIGMAP_API_NAME ingress rule on the cluster."
    #     kubectl delete -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    # fi

    echo "Adding new pair $PAIR_CODE on Kubernetes"
    
    if command helm install $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_CODE \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set job.enable="true" \
                --set job.mode="add_pair" \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server/values.yaml \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/add-pair.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server; then

      echo "Kubernetes Job has been created for adding new pair $PAIR_CODE."

      echo "Waiting until Job get completely run"
      sleep 70;

    else 

      printf "\033[91mFailed to create Kubernetes Job for adding new pair $PAIR_CODE, Please confirm your input values and try again.\033[39m\n"
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_CODE

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_CODE \
            --namespace $ENVIRONMENT_EXCHANGE_NAME \
            -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Pair $PAIR_CODE has been successfully added on your exchange!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_CODE

      echo "Removing created Kubernetes Job for adding new coin..."
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_CODE

      echo "Updating settings file to add new $PAIR_CODE."
      for i in ${CONFIG_FILE_PATH[@]}; do

     if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          
          CONFIGMAP_FILE_PATH=$i

          if ! command grep -q "HOLLAEX_CONFIGMAP_PAIRS=.*${PAIR_CODE}.*" $i ; then

            HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE="${HOLLAEX_CONFIGMAP_PAIRS},${PAIR_CODE}"
            sed -i.bak "s/$HOLLAEX_CONFIGMAP_PAIRS/$HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE/" $CONFIGMAP_FILE_PATH
            rm $CONFIGMAP_FILE_PATH.bak

          else

            HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE=$HOLLAEX_CONFIGMAP_PAIRS
            echo $HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE
          
          fi

      fi

      done

      if [[ ! -f "$TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml" ]]; then 

        echo "Generating Kubernetes Configmap."
        generate_kubernetes_configmap;
      
      fi

      # Adding new value directly at generated env / configmap file
      sed -i.bak "s/$HOLLAEX_CONFIGMAP_PAIRS/$HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE/" $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml
      rm $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml.bak

      export HOLLAEX_CONFIGMAP_PAIRS=$HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE
      echo "Current Trading Pairs: ${HOLLAEX_CONFIGMAP_PAIRS}"

      echo "Applying configmap on the namespace"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml


      if [[ ! "$IS_HOLLAEX_SETUP" ]]; then 

        # Running database job for Kubernetes
        echo "Applying changes on database..."
        kubernetes_hollaex_network_database_init upgrade;
      
      fi

      # Run engine container (helm install) if it doesn't exists on the cluster.
      if ! command helm ls --namespace $ENVIRONMENT_EXCHANGE_NAME | grep $ENVIRONMENT_EXCHANGE_NAME-server-engine-$(echo ${!PAIR_BASE_OVERRIDE})$(echo ${!PAIR_2_OVERRIDE}); then

        echo "Running $(echo ${!PAIR_CODE_OVERRIDE}) on the Kubernetes."
        helm install --namespace $ENVIRONMENT_EXCHANGE_NAME \
                    $ENVIRONMENT_EXCHANGE_NAME-server-engine-$(echo ${!PAIR_BASE_OVERRIDE})$(echo ${!PAIR_2_OVERRIDE}) \
                    --set DEPLOYMENT_MODE="engine" \
                    --set PAIR="$(echo ${!PAIR_CODE_OVERRIDE})" \
                    --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                    --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                    --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                    --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                    --set podRestart_webhook_url="$ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL" \
                    -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                    -f $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server/values.yaml $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server
      
      fi

      hollaex_ascii_pair_has_been_added;

    else

      printf "\033[91mFailed to add new pair $PAIR_CODE! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_CODE
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_CODE

      echo "Allowing exchange external connections"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml
      
    fi

  elif [[ ! "$USE_KUBERNETES" ]]; then

      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"
          
      # Overriding container prefix for develop server
      # if [[ "$IS_DEVELOP" ]]; then
        
      #   CONTAINER_PREFIX=

      # fi

      # echo "Shutting down Nginx to block exchange external access"
      # docker stop $(docker ps | grep $ENVIRONMENT_EXCHANGE_NAME-nginx | cut -f1 -d " ")

      echo "Adding new pair $PAIR_CODE on local exchange"
      if command docker exec --env "PAIR_CODE=$(echo ${!PAIR_CODE_OVERRIDE})" \
                  --env "PAIR_BASE=$(echo ${!PAIR_BASE_OVERRIDE})" \
                  --env "PAIR_2=$(echo ${!PAIR_2_OVERRIDE})" \
                  --env "MIN_SIZE=$(echo ${!MIN_SIZE_OVERRIDE})" \
                  --env "MAX_SIZE=$(echo ${!MAX_SIZE_OVERRIDE})" \
                  --env "MIN_PRICE=$(echo ${!MIN_PRICE_OVERRIDE})" \
                  --env "MAX_PRICE=$(echo ${!MAX_PRICE_OVERRIDE})" \
                  --env "INCREMENT_SIZE=$(echo ${!INCREMENT_SIZE_OVERRIDE})" \
                  --env "INCREMENT_PRICE=$(echo ${!INCREMENT_PRICE_OVERRIDE})"  \
                  --env "PAIR_ACTIVE=$(echo ${!PAIR_ACTIVE_OVERRIDE})" \
                  ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                  node tools/dbs/addPair.js; then

          echo "Updating settings file to add new $PAIR_CODE."
          for i in ${CONFIG_FILE_PATH[@]}; do

            if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          
                CONFIGMAP_FILE_PATH=$i

                if ! command grep -q "HOLLAEX_CONFIGMAP_PAIRS.*${PAIR_CODE}.*" $i ; then

                  HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE="${HOLLAEX_CONFIGMAP_PAIRS},${PAIR_CODE}"
                  sed -i.bak "s/$HOLLAEX_CONFIGMAP_PAIRS/$HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE/" $CONFIGMAP_FILE_PATH
                  rm $CONFIGMAP_FILE_PATH.bak

                else

                  HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE=$HOLLAEX_CONFIGMAP_PAIRS
                  
                fi

            fi

          done

          sed -i.bak "s/$HOLLAEX_CONFIGMAP_PAIRS/$HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE/" $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME.env.local
          rm $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME.env.local.bak

          export HOLLAEX_CONFIGMAP_PAIRS="$HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE"
          echo "Current Trading Pairs: ${HOLLAEX_CONFIGMAP_PAIRS}"
          #Regenerating env based on changes of PAIRs
          generate_local_docker_compose_for_network;

          if [[ ! "$IS_HOLLAEX_SETUP" ]]; then

            # Running database triggers
            docker exec  --env "PAIRS=${HOLLAEX_CONFIGMAP_PAIRS}" ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js > /dev/null

          fi

          hollaex_ascii_pair_has_been_added;

      else

        printf "\033[91mFailed to add new pair $PAIR_CODE on local exchange. Please confirm your input values and try again.\033[39m\n"

        # if  [[ "$IS_DEVELOP" ]]; then

        #   # Restarting containers after database init jobs.
        #   echo "Restarting containers to apply database changes."
        #   docker-compose -f $HOLLAEX_CORE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

        # else

        #   # Restarting containers after database init jobs.
        #   echo "Restarting containers to apply database changes."
        #   docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml restart

        # fi

        # exit 1;

      fi

  fi

  if [[ "$VALUE_IMPORTED_FROM_CONFIGMAP" ]] && ! [[ "$IS_HOLLAEX_SETUP" ]]; then

    exit 0;

  fi

  #exit 0;

}

function remove_pair_input() {

  printf "\nCurrent trading pair(s) available: \033[1m$HOLLAEX_CONFIGMAP_PAIRS\033[0m"
  printf "\n\033[93mWarning: There always should be at least 1 trading pair remain.\033[39m\n\n"

  echo "***************************************************************"
  echo "[1/1] Pair name to remove: "
  read answer

  PAIR_CODE=$answer

  printf "\n"
  echo "${answer} ✔"
  printf "\n"

  if [[ -z "$answer" ]]; then

    echo "Your value is empty. Please confirm your input and run the command again."
    exit 1;
  
  fi
  
  echo "*********************************************"
  echo "Name: $PAIR_CODE"
  echo "*********************************************"

  echo "Are the sure you want to remove this trading pair from your exchange? (y/N)"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "You picked false. Please confirm the values and run the command again."
    exit 1;
  
  fi

}

function remove_pair_exec() {

  IFS=',' read -ra CURRENT_PAIRS <<< "${HOLLAEX_CONFIGMAP_PAIRS}"

  if (( "${#CURRENT_PAIRS[@]}" <= "1" )); then

    printf "\n\033[91mError: You should have at least 1 trading pair on your exchange.\033[39m\n"
    echo "Current Trading Pair(s) : ${HOLLAEX_CONFIGMAP_PAIRS}."
    printf "Exiting...\n\n"

    exit 1;

  fi 

  if [[ "$USE_KUBERNETES" ]]; then

    # # Only tries to attempt remove ingress rules from Kubernetes if it exists.
    # if ! command kubectl get ingress -n $ENVIRONMENT_EXCHANGE_NAME > /dev/null; then
    
    #     echo "Removing $HOLLAEX_CONFIGMAP_API_NAME ingress rule on the cluster."
    #     kubectl delete -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    # fi


    echo "*** Removing existing pair $PAIR_CODE on Kubernetes ***"
      
    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_CODE \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set job.enable="true" \
                --set job.mode="remove_pair" \
                --set job.env.PAIR_CODE="$PAIR_CODE" \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server; then

      echo "*** Kubernetes Job has been created for removing existing pair $PAIR_CODE. ***"

      echo "*** Waiting until Job get completely run ***"
      sleep 60;

    else 

      printf "\033[91mFailed to create Kubernetes Job for removing existing pair $PAIR_CODE, Please confirm your input values and try again.\033[39m\n"
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_CODE

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_CODE \
            --namespace $ENVIRONMENT_EXCHANGE_NAME \
            -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "*** Pair $PAIR_CODE has been successfully removed on your exchange! ***"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_CODE

      echo "*** Removing created Kubernetes Job for removing existing pair... ***"
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_CODE

      echo "*** Removing existing $PAIR_CODE container from Kubernetes ***"
      PAIR_BASE=$(echo $PAIR_CODE | cut -f1 -d '-')
      PAIR_2=$(echo $PAIR_CODE | cut -f2 -d '-')

      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-server-engine-$PAIR_BASE$PAIR_2

      echo "*** Updating settings file to remove existing $PAIR_CODE. ***"
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          if [[ "$PAIR_CODE" == "hex-usdt" ]]; then
              HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HOLLAEX_CONFIGMAP_PAIRS//$PAIR_CODE,}")
            else
              HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HOLLAEX_CONFIGMAP_PAIRS//,$PAIR_CODE}")
          fi
          sed -i.bak "s/$HOLLAEX_CONFIGMAP_PAIRS/$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
          rm $CONFIGMAP_FILE_PATH.bak
      fi

      done

      sed -i.bak "s/$HOLLAEX_CONFIGMAP_PAIRS/$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml
      rm $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml.bak

      export HOLLAEX_CONFIGMAP_PAIRS=$HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE
      echo "Current Trading Pairs: ${HOLLAEX_CONFIGMAP_PAIRS}"

      echo "Applying configmap on the namespace"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml

      # Running database job for Kubernetes
      echo "Applying changes on database..."
      kubernetes_database_init upgrade;

      echo "Trading pair $PAIR_CODE has been successfully removed."
      echo "Please run 'hollaex restart --kube' to fully apply it."

    else

      printf "\033[91mFailed to remove existing pair $PAIR_CODE! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_CODE
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_CODE
      
    fi

  elif [[ ! "$USE_KUBERNETES" ]]; then

      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

      echo "*** Removing new pair $PAIR_CODE on local exchange ***"
      if command docker exec --env "PAIR_CODE=${PAIR_CODE}" ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/removePair.js; then

        echo "*** Updating settings file to remove existing $PAIR_CODE. ***"
        for i in ${CONFIG_FILE_PATH[@]}; do

        if command grep -q "HOLLAEX_CONFIGMAP_PAIRS" $i > /dev/null ; then
            CONFIGMAP_FILE_PATH=$i

            IFS="," read -ra PAIRS_TO_ARRAY <<< "${HOLLAEX_CONFIGMAP_PAIRS}"
            local REVOME_SELECTED_PAIR=${PAIRS_TO_ARRAY[@]/$PAIR_CODE}
            local PAIRS_ARRAY_TO_STRING=$(echo ${REVOME_SELECTED_PAIR[@]} | tr -d '') 
            local PAIRS_STRING_TO_COMMNA_SEPARATED=${PAIRS_ARRAY_TO_STRING// /,}

            sed -i.bak "s/$HOLLAEX_CONFIGMAP_PAIRS/$PAIRS_STRING_TO_COMMNA_SEPARATED/" $CONFIGMAP_FILE_PATH

            rm $CONFIGMAP_FILE_PATH.bak
        fi

        done

        sed -i.bak "s/$HOLLAEX_CONFIGMAP_PAIRS/$PAIRS_STRING_TO_COMMNA_SEPARATED/" $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME.env.local
        rm $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME.env.local.bak

        export HOLLAEX_CONFIGMAP_PAIRS=$PAIRS_STRING_TO_COMMNA_SEPARATED
        echo "Current Trading Pairs: ${HOLLAEX_CONFIGMAP_PAIRS}"

        generate_local_docker_compose;
        
        # Running database triggers
        docker exec --env="PAIRS=${HOLLAEX_CONFIGMAP_PAIRS}" ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js > /dev/null

        echo "Trading pair $PAIR_CODE has been successfully removed."
        echo "Please run 'hollaex restart' to fully apply it."

      else

        printf "\033[91mFailed to remove trading pair $PAIR_CODE on local exchange. Please confirm your input values and try again.\033[39m\n"

      fi

  fi

}

function change_coin_owner_input() {

  echo "***************************************************************"
  echo "[1/2] Coin Symbol: (eth)"
  printf "\033[2m- This trading symbol is a short hand for this coin.\033[22m\n" 
  read answer

  COIN_CODE=${answer:-eth}

  printf "\n"
  echo "${answer:-eth} ✔"
  printf "\n"


  echo "***************************************************************"
  echo "[2/2] Target Coin Owner ID: (2)"
  printf "\033[2m- The target network user ID to transfer the ownership.\033[22m\n" 
  printf "\n"
  read answer

  COIN_OWNER_ID=${answer:-2}

  printf "\n"
  echo "${answer:-2} ✔"
  printf "\n"
  
  echo "*********************************************"
  echo "Symbol: $COIN_CODE"
  echo "Coin Owner ID: $COIN_OWNER_ID"
  echo "*********************************************"

  echo "Are the values are all correct? (y/N)"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "You picked false. Please confirm the values and run the command again."
    exit 1;
  
  fi

}

function change_coin_owner_exec() {

  local COIN_PREFIX=$(echo $COIN_CODE | tr a-z A-Z)

  # export_add_coin_configuration_env;

  if [[ "$USE_KUBERNETES" ]]; then

    function generate_kubernetes_change_coin_owner_values() {

    # Generate Kubernetes Configmap
    cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/change-coin-owner.yaml <<EOL
job:
  enable: true
  mode: change_coin_owner
  env:
    coin_code: $COIN_CODE
    coin_owner_id: "$COIN_OWNER_ID"
EOL

    }

    generate_kubernetes_change_coin_owner_values;

    echo "Changing the ownership of $COIN_CODE on Kubernetes"
    
    if command helm install $ENVIRONMENT_EXCHANGE_NAME-change-coin-owner-$COIN_CODE \
                            --namespace $ENVIRONMENT_EXCHANGE_NAME \
                            --set job.enable="true" \
                            --set job.mode="change_coin_owner" \
                            --set DEPLOYMENT_MODE="api" \
                            --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                            --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                            --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                            --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                            -f $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server/values.yaml \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/change-coin-owner.yaml \
                            $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server; then

      echo "Kubernetes Job has been created for change the coin ownership of $COIN_CODE."

      echo "Waiting until Job get completely run"
      sleep 60;

    else 

      printf "\033[91mFailed to create Kubernetes Job for change coin ownership $COIN_CODE, Please confirm your input values and try again.\033[39m\n"
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-change-coin-owner-$COIN_CODE

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-change-coin-owner-$COIN_CODE --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Coin ownership of $COIN_CODE has been successfully changed!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-change-coin-owner-$COIN_CODE

      echo "Removing created Kubernetes Job..."
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-change-coin-owner-$COIN_CODE

      echo "Please run 'hollaex network --restart --kube' to apply the latest change."

    else

      printf "\033[91mFailed to change coin ownership of $COIN_CODE! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-change-coin-owner-$COIN_CODE
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-change-coin-owner-$COIN_CODE

      
    fi

    elif [[ ! "$USE_KUBERNETES" ]]; then


      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"
          

      echo "Changing coin ownership of $COIN_CODE on HollaEx Network."
      if command docker exec \
                  --env "COIN_CODE=$COIN_CODE" \
                  --env "COIN_OWNER_ID=$COIN_OWNER_ID" \
                  ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                  node tools/dbs/changeCoinOwner.js; then

         
        echo "Successfully changed the ownership of $COIN_CODE!"

        echo -e "\nPlease run 'hollaex network --restart' to apply the latest change.\n"


      else

        printf "\033[91mFailed to change the ownership of $COIN_CODE. Please confirm your input values and try again.\033[39m\n"

        exit 1;

      fi
      
  fi


}

function activate_coin_input() {

  echo "***************************************************************"
  echo "Coin Symbol: (eth)"
  printf "\033[2m- This trading symbol is a short hand for this coin.\033[22m\n" 
  read answer

  COIN_CODE=${answer:-eth}

  printf "\n"
  echo "${answer:-eth} ✔"
  printf "\n"
  
  echo "*********************************************"
  echo "Symbol: $COIN_CODE"
  echo "*********************************************"

  echo "Are the values are all correct? (y/N)"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "You picked false. Please confirm the values and run the command again."
    exit 1;
  
  fi

}

function activate_coin_exec() {

  if [[ "$USE_KUBERNETES" ]]; then

    function generate_kubernetes_activate_coin_values() {

    # Generate Kubernetes Configmap
    cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/activate-coin.yaml <<EOL
job:
  enable: true
  mode: activate_coin
  env:
    coin_code: $COIN_CODE
EOL

    }

    generate_kubernetes_activate_coin_values;

    echo "Activating $COIN_CODE on Kubernetes"
    
    if command helm install $ENVIRONMENT_EXCHANGE_NAME-activate-coin-$COIN_CODE \
                            --namespace $ENVIRONMENT_EXCHANGE_NAME \
                            --set job.enable="true" \
                            --set job.mode="activate_coin" \
                            --set DEPLOYMENT_MODE="api" \
                            --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                            --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                            --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                            --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                            -f $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server/values.yaml \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/activate-coin.yaml \
                            $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server; then

      echo "Kubernetes Job has been created for activating $COIN_CODE."

      echo "Waiting until Job get completely run"
      sleep 60;

    else 

      printf "\033[91mFailed to create Kubernetes Job for activating $COIN_CODE, Please confirm your input values and try again.\033[39m\n"
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-activate-coin-$COIN_CODE

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-activate-coin-$COIN_CODE --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Coin $COIN_CODE has been successfully activated!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-activate-coin-$COIN_CODE
      
      echo "Updating settings file to add new $COIN_CODE."
      for i in ${CONFIG_FILE_PATH[@]}; do

        if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then

            CONFIGMAP_FILE_PATH=$i
            
            if ! command grep -q "HOLLAEX_CONFIGMAP_CURRENCIES.*${COIN_CODE}.*" $i ; then

              HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE="${HOLLAEX_CONFIGMAP_CURRENCIES},${COIN_CODE}"
              sed -i.bak "s/$HOLLAEX_CONFIGMAP_CURRENCIES/$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
              rm $CONFIGMAP_FILE_PATH.bak

            else

              HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE=$HOLLAEX_CONFIGMAP_CURRENCIES
                
            fi

        fi

      done

      echo "Removing created Kubernetes Job..."
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-activate-coin-$COIN_CODE

      # Running database job for Kubernetes
      echo "Applying changes on database..."
      kubernetes_hollaex_network_database_init upgrade;

      hollaex_ascii_coin_has_been_added

      echo -e "\nPlease run 'hollaex network --restart --kube' to apply the latest change."

    else

      printf "\033[91mFailed to activate $COIN_CODE! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-activate-coin-$COIN_CODE
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-activate-coin-$COIN_CODE

      
    fi

    elif [[ ! "$USE_KUBERNETES" ]]; then


      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"
          

      echo "Activating $COIN_CODE on HollaEx Network."
      if command docker exec \
                  --env "COIN_CODE=$COIN_CODE" \
                  ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                  node tools/dbs/activateCoin.js; then

         
        echo "Successfully activated $COIN_CODE!"

        echo "Updating settings file to add new $COIN_CODE."
        for i in ${CONFIG_FILE_PATH[@]}; do

          if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then

              CONFIGMAP_FILE_PATH=$i
              
              if ! command grep -q "HOLLAEX_CONFIGMAP_CURRENCIES.*${COIN_CODE}.*" $i ; then

                HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE="${HOLLAEX_CONFIGMAP_CURRENCIES},${COIN_CODE}"
                sed -i.bak "s/$HOLLAEX_CONFIGMAP_CURRENCIES/$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
                rm $CONFIGMAP_FILE_PATH.bak

              else

                HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE=$HOLLAEX_CONFIGMAP_CURRENCIES
                  
              fi

          fi

        done

        if [[ ! "$IS_HOLLAEX_SETUP" ]]; then

            # Running database triggers
            docker exec  --env "PAIRS=${HOLLAEX_CONFIGMAP_PAIRS}" ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js > /dev/null

          fi

        hollaex_ascii_coin_has_been_added;

        echo -e "\nPlease run 'hollaex network --restart' to apply the latest change.\n"


      else

        printf "\033[91mFailed to activate $COIN_CODE. Please confirm your input values and try again.\033[39m\n"

        exit 1;

      fi
      
  fi


}

function change_pair_owner_input() {

  echo "***************************************************************"
  echo "[1/2] Name of Trading Pair: (eth-usdt)"
  printf "\033[2m- First enter the base currency (eth) with a dash (-) followed be the second quoted currency (usdt). \033[22m\n"
  read answer

  PAIR_CODE=${answer:-eth-usdt}

  printf "\n"
  echo "${answer:-eth-usdt} ✔"
  printf "\n"


  echo "***************************************************************"
  echo "[2/2] Target Pair Owner ID: (2)"
  printf "\033[2m- The target network user ID to transfer the ownership.\033[22m\n" 
  printf "\n"
  read answer

  PAIR_OWNER_ID=${answer:-2}

  printf "\n"
  echo "${answer:-2} ✔"
  printf "\n"
  
  echo "*********************************************"
  echo "Trading Pair Name: $PAIR_CODE"
  echo "Trading Pair Owner ID: $PAIR_OWNER_ID"
  echo "*********************************************"

  echo "Are the values are all correct? (y/N)"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "You picked false. Please confirm the values and run the command again."
    exit 1;
  
  fi

}

function change_pair_owner_exec() {

  # export_add_coin_configuration_env;

  if [[ "$USE_KUBERNETES" ]]; then

    function generate_kubernetes_change_pair_owner_values() {

    # Generate Kubernetes Configmap
    cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/change-pair-owner.yaml <<EOL
job:
  enable: true
  mode: change_pair_owner
  env:
    pair_code: $PAIR_CODE
    pair_owner_id: "$PAIR_OWNER_ID"
EOL

    }

    generate_kubernetes_change_pair_owner_values;

    echo "Changing the ownership of $PAIR_CODE on Kubernetes"
    
    if command helm install $ENVIRONMENT_EXCHANGE_NAME-change-pair-owner-$PAIR_CODE \
                            --namespace $ENVIRONMENT_EXCHANGE_NAME \
                            --set job.enable="true" \
                            --set job.mode="change_pair_owner" \
                            --set DEPLOYMENT_MODE="api" \
                            --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                            --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                            --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                            --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                            -f $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server/values.yaml \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/change-pair-owner.yaml \
                            $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server; then

      echo "Kubernetes Job has been created for change the pair ownership of $PAIR_CODE."

      echo "Waiting until Job get completely run"
      sleep 60;

    else 

      printf "\033[91mFailed to create Kubernetes Job for change pair ownership $PAIR_CODE, Please confirm your input values and try again.\033[39m\n"
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-change-pair-owner-$PAIR_CODE

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-change-pair-owner-$PAIR_CODE --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Pair ownership of $PAIR_CODE has been successfully changed!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-change-pair-owner-$PAIR_CODE

      echo "Removing created Kubernetes Job..."
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-change-pair-owner-$PAIR_CODE

      echo "Please run 'hollaex network --restart --kube' to apply the latest change."

    else

      printf "\033[91mFailed to change pair ownership of $PAIR_CODE! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-change-pair-owner-$PAIR_CODE
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-change-pair-owner-$PAIR_CODE

      
    fi

    elif [[ ! "$USE_KUBERNETES" ]]; then


      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"
          

      echo "Changing pair ownership of $PAIR_CODE on HollaEx Network."
      if command docker exec \
                  --env "PAIR_CODE=$PAIR_CODE" \
                  --env "PAIR_OWNER_ID=$PAIR_OWNER_ID" \
                  ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                  node tools/dbs/changePairOwner.js; then

         
        echo "Successfully changed the ownership of $PAIR_CODE!"

        echo -e "\nPlease run 'hollaex network --restart' to apply the latest change.\n"


      else

        printf "\033[91mFailed to change the ownership of $PAIR_CODE. Please confirm your input values and try again.\033[39m\n"

        exit 1;

      fi
      
  fi


}

function activate_pair_input() {

  echo "***************************************************************"
  echo "Name of Trading Pair: (eth-usdt)"
  printf "\033[2m- First enter the base currency (eth) with a dash (-) followed be the second quoted currency (usdt). \033[22m\n"
  read answer

  PAIR_CODE=${answer:-eth-usdt}

  printf "\n"
  echo "${answer:-eth-usdt} ✔"
  printf "\n"

  
  echo "*********************************************"
  echo "Trading Pair Name: $PAIR_CODE"
  echo "*********************************************"

  echo "Are the values are all correct? (y/N)"
  read answer

  if [[ "$answer" = "${answer#[Yy]}" ]]; then
      
    echo "You picked false. Please confirm the values and run the command again."
    exit 1;
  
  fi

}

function activate_pair_exec() {

  # export_add_coin_configuration_env;

  if [[ "$USE_KUBERNETES" ]]; then

    function generate_kubernetes_activate_pair_values() {

    # Generate Kubernetes Configmap
    cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/activate-pair.yaml <<EOL
job:
  enable: true
  mode: activate_pair
  env:
    pair_code: $PAIR_CODE

EOL

    }

    generate_kubernetes_activate_pair_values;

    echo "Activating pair $PAIR_CODE on Kubernetes"
    
    if command helm install $ENVIRONMENT_EXCHANGE_NAME-activate-pair-$PAIR_CODE \
                            --namespace $ENVIRONMENT_EXCHANGE_NAME \
                            --set job.enable="true" \
                            --set job.mode="activate_pair" \
                            --set DEPLOYMENT_MODE="api" \
                            --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                            --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                            --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                            --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                            -f $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server/values.yaml \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/activate-pair.yaml \
                            $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server; then

      echo "Kubernetes Job has been created for activating $PAIR_CODE."

      echo "Waiting until Job get completely run"
      sleep 60;

    else 

      printf "\033[91mFailed to create Kubernetes Job for activating $PAIR_CODE, Please confirm your input values and try again.\033[39m\n"
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-activate-pair-$PAIR_CODE

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-activate-pair-$PAIR_CODE --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Pair $PAIR_CODE has been successfully activated!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-activate-pair-$PAIR_CODE

      for i in ${CONFIG_FILE_PATH[@]}; do

        if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
      
            CONFIGMAP_FILE_PATH=$i

            if ! command grep -q "HOLLAEX_CONFIGMAP_PAIRS.*${PAIR_CODE}.*" $i ; then

              HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE="${HOLLAEX_CONFIGMAP_PAIRS},${PAIR_CODE}"
              sed -i.bak "s/$HOLLAEX_CONFIGMAP_PAIRS/$HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE/" $CONFIGMAP_FILE_PATH
              rm $CONFIGMAP_FILE_PATH.bak

            else

              HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE=$HOLLAEX_CONFIGMAP_PAIRS
              
            fi

        fi

      done

      echo "Removing created Kubernetes Job..."
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-activate-pair-$PAIR_CODE

      # Running database job for Kubernetes
      echo "Applying changes on database..."
      kubernetes_hollaex_network_database_init upgrade;

      echo "Running pair container $PAIR_CODE..."
      # Run engine container (helm install) if it doesn't exists on the cluster.

      helm install --namespace $ENVIRONMENT_EXCHANGE_NAME \
                  $ENVIRONMENT_EXCHANGE_NAME-server-engine-$PAIR_CODE \
                  --set DEPLOYMENT_MODE="engine" \
                  --set PAIR=$PAIR_CODE \
                  --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                  --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                  --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                  --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                  --set podRestart_webhook_url="$ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL" \
                  -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                  -f $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server/values.yaml $SCRIPTPATH/kubernetes/helm-chart/hollaex-network-server


      hollaex_ascii_pair_has_been_added;

      echo -e "\nPlease run 'hollaex network --restart --kube' to apply the latest change."

    else

      printf "\033[91mFailed to activate $PAIR_CODE! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-activate-pair-$PAIR_CODE
      helm uninstall --namespace $ENVIRONMENT_EXCHANGE_NAME $ENVIRONMENT_EXCHANGE_NAME-activate-pair-$PAIR_CODE

      
    fi

    elif [[ ! "$USE_KUBERNETES" ]]; then


      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"
          

      echo "Activating $PAIR_CODE on HollaEx Network."
      if command docker exec \
                  --env "PAIR_CODE=$PAIR_CODE" \
                  ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                  node tools/dbs/activatePair.js; then

         
        echo "Successfully activated $PAIR_CODE!"

        for i in ${CONFIG_FILE_PATH[@]}; do

          if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
        
              CONFIGMAP_FILE_PATH=$i

              if ! command grep -q "HOLLAEX_CONFIGMAP_PAIRS.*${PAIR_CODE}.*" $i ; then

                HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE="${HOLLAEX_CONFIGMAP_PAIRS},${PAIR_CODE}"
                sed -i.bak "s/$HOLLAEX_CONFIGMAP_PAIRS/$HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE/" $CONFIGMAP_FILE_PATH
                rm $CONFIGMAP_FILE_PATH.bak

              else

                HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE=$HOLLAEX_CONFIGMAP_PAIRS
                
              fi

          fi

        done

        sed -i.bak "s/$HOLLAEX_CONFIGMAP_PAIRS/$HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE/" $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME.env.local
        rm $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME.env.local.bak

        export HOLLAEX_CONFIGMAP_PAIRS="$HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE"
        echo "Current Trading Pairs: ${HOLLAEX_CONFIGMAP_PAIRS}"
        #Regenerating env based on changes of PAIRs
        generate_local_docker_compose_for_network;

        # Running database triggers
        docker exec  --env "PAIRS=${HOLLAEX_CONFIGMAP_PAIRS}" ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js > /dev/null

        hollaex_ascii_pair_has_been_added

        echo -e "\nPlease run 'hollaex network --restart' to apply the latest change.\n"


      else

        printf "\033[91mFailed to activate $PAIR_CODE. Please confirm your input values and try again.\033[39m\n"

        exit 1;

      fi
      
  fi


}

function check_latest_hollaex_network_docker_tag() {

  DOCKER_HUB_BEARER_TOKEN=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'${ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME}'", "password": "'${ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD}'"}' https://hub.docker.com/v2/users/login/ | jq -r .token)
  curl -s -S -H "Authorization: Bearer $DOCKER_HUB_BEARER_TOKEN" https://registry.hub.docker.com/v2/repositories/bitholla/hollaex-network-standalone/tags?page_size=100 | jq -r '."results"[]["name"]' | sed -n 1p 

}

function hollaex_setup_existing_exchange_check() {

  CONFIG_FILE_PATH=$(pwd)/settings/*

  for i in ${CONFIG_FILE_PATH[@]}; do
      source $i
  done;

  if [[ "$USE_KUBERNETES" ]]; then

      if command kubectl get ns $ENVIRONMENT_EXCHANGE_NAME > /dev/null 2>&1; then

          export IS_HOLLAEX_KUBE_ALREADY_EXISTS=true

      fi
  
  else 

      if command docker ps -a | grep local_$ENVIRONMENT_EXCHANGE_NAME > /dev/null 2>&1; then

          export IS_HOLLAEX_LOCAL_ALREADY_EXISTS=true

      fi

  fi

  if [[ "$IS_HOLLAEX_KUBE_ALREADY_EXISTS" ]] || [[ "$IS_HOLLAEX_LOCAL_ALREADY_EXISTS" ]]; then

      hollaex_ascii_think_emoji;

      echo -e "\n\033[91mOops! There's an exchange $ENVIRONMENT_EXCHANGE_NAME already running on the system.\033[39m"
      echo -e "\nIf this was a mistake, there's nothing you should do."
      echo -e "\nIf you \033[1mmeant to run the setup again\033[0m due to the failure of the previous setup job, or with any other reasons, you should \033[1mterminate the current exchange\033[0m first."
      echo -e "\nPlease run \033[1m'hollaex server --terminate$(if [[ "$IS_HOLLAEX_KUBE_ALREADY_EXISTS" ]];then echo " --kube"; fi)'\033[0m to fully terminate the exchange and run \033[1m'hollaex server --setup$(if [[ "$IS_HOLLAEX_KUBE_ALREADY_EXISTS" ]]; then echo " --kube"; fi)'\033[0m again.\n"

      exit 1;

  fi 

}

function hollaex_setup_existing_settings_values_check() {

  CONFIG_FILE_PATH=$(pwd)/settings/*

  for i in ${CONFIG_FILE_PATH[@]}; do
      source $i
  done;

  if [[ ! "$ENVIRONMENT_EXCHANGE_NAME" == "my-hollaex-exchange" ]] && [[ "$HOLLAEX_SECRET_API_KEY" ]] && [[ "$HOLLAEX_SECRET_API_SECRET" ]]; then 

    echo -e "\n\033[93mWarning: HollaEx CLI has detected your existing exchange information.\033[39m\n"
    echo "Network: $HOLLAEX_CONFIGMAP_NETWORK_URL"
    echo "Exchange Name: $ENVIRONMENT_EXCHANGE_NAME"
    echo "API Key: $HOLLAEX_SECRET_API_KEY"
    echo "API Secret: $(echo ${HOLLAEX_SECRET_API_SECRET//?/◼︎}$(echo $HOLLAEX_SECRET_API_SECRET | grep -o '....$'))"

    echo -e "\nDo you want to continue with the existing information? (Y/n)"
    read answer

    if [[ ! "$answer" = "${answer#[Nn]}" ]]; then

        echo "Proceeding to the initialization wizard..."
    
    else 

        echo "Skipping the initialization wizard..."
        exit 0
                
    fi
  
  fi

}
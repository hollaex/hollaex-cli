#!/bin/bash 
SCRIPTPATH=$HOME/.hollaex-cli

function local_database_init() {

    # if [[ "$RUN_WITH_VERIFY" == true ]]; then

    #     echo "Are you sure you want to run database init jobs for your local $ENVIRONMENT_EXCHANGE_NAME db? (y/N)"

    #     read answer

    #   if [[ "$answer" = "${answer#[Yy]}" ]]; then
    #     echo "Exiting..."
    #     exit 0;
    #   fi

    # fi

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

    elif [[ "$1" == 'upgrade' ]]; then

      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

      echo "Running sequelize db:migrate"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 sequelize db:migrate

      echo "Running database triggers"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/runTriggers.js

      echo "Running checkConstants"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/checkConstants.js

      echo "Setting up the exchange with provided activation code"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/setActivationCode.js
    
    # elif [[ "$1" == 'dev' ]]; then

    #   IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

    #   echo "Running sequelize db:migrate"
    #   docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 sequelize db:migrate

    #   echo "Running database triggers"
    #   docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/runTriggers.js

    #   echo "Running sequelize db:seed:all"
    #   docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 sequelize db:seed:all

    #   echo "Running InfluxDB migrations"
    #   docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/createInflux.js
    #   docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/migrateInflux.js
    #   docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/initializeInflux.js

    fi
}

function kubernetes_database_init() {

  if [[ "$1" == "launch" ]]; then

     # Checks the api container(s) get ready enough to run database upgrade jobs.
    while ! kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- echo "API is ready!" > /dev/null 2>&1;
        do echo "API container is not ready! Retrying..."
        sleep 10;
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

  elif [[ "$1" == "upgrade" ]]; then

    echo "Running database jobs..."

    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade \
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
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade

    else 

      printf "\033[91mFailed to create Kubernetes Job for running database jobs, Please confirm your input values and try again.\033[39m\n"

      echo "Displayling logs..."
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade
      
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-hollaex-upgrade

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

}

function generate_nginx_upstream_for_web(){

  # Generate local nginx conf
  cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream-web.conf <<EOL

  upstream web {
    server host.access:8080;
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
    restart: always
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
    restart: always
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
    restart: always
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
    restart: always
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
  
  ${ENVIRONMENT_EXCHANGE_NAME}-server-plugins-controller:
    image: ${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY}:${ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION}
    restart: always
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
    restart: always
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
    restart: always
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
    restart: always
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
    image: ${ENVIRONMENT_DOCKER_IMAGE_REDIS_REGISTRY:-redis}:${ENVIRONMENT_DOCKER_IMAGE_REDIS_VERSION:-5.0.5-alpine}
    restart: always
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
    restart: always
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
    restart: always
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

  ${ENVIRONMENT_EXCHANGE_NAME}-nginx:
    image: ${ENVIRONMENT_DOCKER_IMAGE_LOCAL_NGINX_REGISTRY:-bitholla/nginx-with-certbot}:${ENVIRONMENT_DOCKER_IMAGE_LOCAL_NGINX_VERSION:-1.15.8}
    restart: always
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
    image: ${ENVIRONMENT_DOCKER_IMAGE_REDIS_REGISTRY:-redis}:${ENVIRONMENT_DOCKER_IMAGE_REDIS_VERSION:-5.0.5-alpine}
    restart: always
    depends_on:
      - ${ENVIRONMENT_EXCHANGE_NAME}-db
    ports:
      - 6379:6379
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    command : ["sh", "-c", "redis-server --requirepass \$\${REDIS_PASSWORD}"]
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL

fi

if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" == "true" ]]; then 
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-db:
    image: ${ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_REGISTRY:-postgres}:${ENVIRONMENT_DOCKER_IMAGE_POSTGRESQL_VERSION:-10.9-alpine}
    restart: always
    ports:
      - 5432:5432
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    command : ["sh", "-c", "export POSTGRES_DB=\$\${DB_NAME} && export POSTGRES_USER=\$\${DB_USERNAME} && export POSTGRES_PASSWORD=\$\${DB_PASSWORD} && ./docker-entrypoint.sh postgres"]
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL

fi

#LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE=$ENVIRONMENT_EXCHANGE_RUN_MODE

IFS=',' read -ra LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE <<< "$ENVIRONMENT_EXCHANGE_RUN_MODE"

for i in ${LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE[@]}; do

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

  ${ENVIRONMENT_EXCHANGE_NAME}-server-${i}:
    image: $ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION
    restart: always
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    entrypoint:
      - node
    command:
      $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- app.js"; fi) 
      $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- ws/index.js"; fi) 
    $(if [[ "${i}" == "api" ]] || [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "ports:"; fi)
      $(if [[ "${i}" == "api" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- 10010:10010"; fi) 
      $(if [[ "${i}" == "stream" ]] && [[ ! "$ENVIRONMENT_HOLLAEX_SCALEING" ]]; then echo "- 10080:10080"; fi)
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
    $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" ]] || [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" ]] || [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" ]]; then echo "depends_on:"; fi)
      $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_POSTGRESQL_DB" ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-redis"; fi)
      $(if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_REDIS" ]]; then echo "- ${ENVIRONMENT_EXCHANGE_NAME}-db"; fi)

EOL

  if [[ "$i" == "api" ]]; then
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

  ${ENVIRONMENT_EXCHANGE_NAME}-nginx:
    image: ${ENVIRONMENT_DOCKER_IMAGE_LOCAL_NGINX_REGISTRY:-bitholla/nginx-with-certbot}:${ENVIRONMENT_DOCKER_IMAGE_LOCAL_NGINX_VERSION:-1.15.8}
    restart: always
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
    ports:
      - 8080:80
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
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      limit_req zone=api burst=10 nodelay;
      limit_req_log_level notice;
      limit_req_status 429;
spec:
  rules:
  - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
    http:
      paths:
      - path: /v1
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010

  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api-order
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      limit_req zone=api burst=10 nodelay;
      limit_req_log_level notice;
      limit_req_status 429;
spec:
  rules:
  - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
    http:
      paths:
      - path: /v1/order
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010
  
  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api-admin
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
spec:
  rules:
  - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
    http:
      paths:
      - path: /v1/admin
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010

  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)

    
---

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-plugins-controller
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
spec:
  rules:
  - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
    http:
      paths:
      - path: /plugins
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-api
          servicePort: 10010
    
  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-stream
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
    nginx.org/websocket-services: "${ENVIRONMENT_EXCHANGE_NAME}-server-stream"
    nginx.ingress.kubernetes.io/upstream-hash-by: "\$binary_remote_addr"
spec:
  rules:
  - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
    http:
      paths:
      - path: /socket.io
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-stream
          servicePort: 10080
  
  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_SERVER" == true ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)

EOL

}

function generate_kubernetes_ingress_for_web() { 

if [[ -z "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB" ]] || [[ ! "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB" == false ]]; then 

  ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB=true

fi

  # Generate Kubernetes Secret
cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/${ENVIRONMENT_EXCHANGE_NAME}-ingress-web.yaml <<EOL

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-web
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB" == true ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB" == true ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"

spec:
  rules:
  - host: $(echo ${HOLLAEX_CONFIGMAP_DOMAIN} | cut -f3 -d "/")
    http:
      paths:
      - path: /
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-web
          servicePort: 80
  
  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]] && [[ "$ENVIRONMENT_KUBERNETES_INGRESS_SSL_ENABLE_WEB" == true ]];then ingress_web_tls_snippets $HOLLAEX_CONFIGMAP_DOMAIN; fi)

EOL

}

function generate_random_values() {

  # Runs random.js through docker with latest compatible hollaex core (minimum 1.23.0)
  docker run --rm --entrypoint node bitholla/hollaex-core:${HOLLAEX_CORE_MAXIMUM_COMPATIBLE:-1.24.9} tools/general/random.js
  
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
      sed -i.bak "s/ENVIRONMENT_DOCKER_IMAGE_VERSION=.*/ENVIRONMENT_DOCKER_IMAGE_VERSION=$ENVIRONMENT_DOCKER_IMAGE_VERSION_OVERRIDE/" $CONFIGMAP_FILE_PATH
      sed -i.bak "s/ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION=.*/ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION=$ENVIRONMENT_DOCKER_IMAGE_VERSION_OVERRIDE/" $CONFIGMAP_FILE_PATH
    fi
    
  done

  sed -i.bak "s/$(echo $ENVIRONMENT_DOCKER_IMAGE_REGISTRY | cut -f2 -d '/'):.*/$(echo $ENVIRONMENT_DOCKER_IMAGE_REGISTRY | cut -f2 -d '/'):$ENVIRONMENT_DOCKER_IMAGE_VERSION_OVERRIDE/" $HOLLAEX_CLI_INIT_PATH/Dockerfile

  rm $HOLLAEX_CLI_INIT_PATH/Dockerfile.bak
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

function launch_basic_settings_input() {

  /bin/cat << EOF
  
Please fill up the interaction form to launch your own exchange.

If you don't have activation code for HOLLAEX Core yet, We also provide trial license.
Please visit https://dash.bitholla.com to see more details.

Check https://docs.bitholla.com to read full docs regarding whole HollaEx Kit operations.

EOF
  
  # SET TOTAL NUMBERS OF QUESTIONS
  local TOTAL_QUESTIONS=33

  if [[ "$RECONFIGURE_BASIC_SETTINGS" ]]; then 

    local TOTAL_QUESTIONS=28

  fi

  local QUESTION_NUMBER=1

  # Exchange name (API_NAME)

  echo "***************************************************************"
  echo "[$QUESTION_NUMBER/$TOTAL_QUESTIONS] Exchange name: ($HOLLAEX_CONFIGMAP_API_NAME)"
  printf "\033[2m- Alphanumeric, Dash (-), Underscore Only (_). No space or special character allowed.\033[22m\n" 
  read answer

  local EXCHANGE_API_NAME_OVERRIDE=${answer:-$HOLLAEX_CONFIGMAP_API_NAME}

  while true;
    do if [[ ! "$EXCHANGE_API_NAME_OVERRIDE" =~ ^[A-Za-z0-9_-]+$ ]]; then 
      printf "\nInvalid Exchange Name. Make sure to input Alphanumeric, Dash (-), Underscore Only (_).\n"
      echo "New Exchange Name: "
      read answer
      local EXCHANGE_API_NAME_OVERRIDE=${answer}
    else
      break;
    fi
  done


  printf "\n"
  echo "$EXCHANGE_API_NAME_OVERRIDE ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # Activation Code
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Activation Code: ($(echo ${HOLLAEX_SECRET_ACTIVATION_CODE//?/◼︎}$(echo $HOLLAEX_SECRET_ACTIVATION_CODE | grep -o '....$')))"
  printf "\033[2m- Go to https://dash.bitholla.com to issue your activation code.\033[22m\n" 
  read answer

  local EXCHANGE_ACTIVATION_CODE_OVERRIDE=${answer:-$HOLLAEX_SECRET_ACTIVATION_CODE}

  local EXCHANGE_ACTIVATION_CODE_MASKED=$(echo ${EXCHANGE_ACTIVATION_CODE_OVERRIDE//?/◼︎}$(echo $EXCHANGE_ACTIVATION_CODE_OVERRIDE | grep -o '....$'))

  printf "\n"
  echo "$EXCHANGE_ACTIVATION_CODE_MASKED ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # Web Domain
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Exchange URL: ($HOLLAEX_CONFIGMAP_DOMAIN)"
  printf "\033[2m- Keep it as 'example.com' for local test exchange.\033[22m\n"
  read answer

  local ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN="${answer:-$HOLLAEX_CONFIGMAP_DOMAIN}"

  # while true;
  #   do if [[ ! "$ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN" == *"http"* ]]; then
  #     printf "\nValue should be a full URL including 'http' or 'https'.\n"
  #     echo  "Exchange URL: "
  #     read answer
  #     local ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN="${answer}"
  #   else
  #     break;
  #   fi
  # done

  if [[ ! "$ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN" == *"http"* ]]; then

    local ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN=$(echo "http://${ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN}")

  fi

  local PARSE_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN=${ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN//\//\\/}
  local EXCHANGE_WEB_DOMAIN_OVERRIDE="$PARSE_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN"
  
  printf "\n"
  echo "${ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # Light Logo Path
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Exchange Light Logo URL: ($HOLLAEX_CONFIGMAP_LOGO_PATH)"
  printf "\033[2m- Logo file should be always a http(s) link. \033[22m\n"
  read answer

  local ORIGINAL_CHARACTER_FOR_LOGO_PATH="${answer:-$HOLLAEX_CONFIGMAP_LOGO_PATH}"

  while true;
    do if [[ ! "$ORIGINAL_CHARACTER_FOR_LOGO_PATH" == *"http"* ]]; then
      printf "\nLogo file should be always a http(s) link.\n"
      echo  "Exchange Light Logo Path: "
      read answer
      local ORIGINAL_CHARACTER_FOR_LOGO_PATH="${answer}"
    else
      break;
    fi
  done

  local ESCAPED_HOLLAEX_CONFIGMAP_LOGO_PATH=${ORIGINAL_CHARACTER_FOR_LOGO_PATH//\//\\/}

  local PARSE_CHARACTER_FOR_LOGO_PATH=${ORIGINAL_CHARACTER_FOR_LOGO_PATH//\//\\/}
  local HOLLAEX_CONFIGMAP_LOGO_PATH_OVERRIDE="$PARSE_CHARACTER_FOR_LOGO_PATH"

  printf "\n"
  echo "${answer:-$HOLLAEX_CONFIGMAP_LOGO_PATH} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # Dark Logo Path
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Exchange Dark Logo URL: ($HOLLAEX_CONFIGMAP_LOGO_BLACK_PATH)"
  printf "\033[2m- Logo file should be always a http(s) link. \033[22m\n"
  read answer

  local ORIGINAL_CHARACTER_FOR_LOGO_BLACK_PATH="${answer:-$HOLLAEX_CONFIGMAP_LOGO_BLACK_PATH}"

  while true;
    do if [[ ! "$ORIGINAL_CHARACTER_FOR_LOGO_BLACK_PATH" == *"http"* ]]; then
      printf "\nLogo file should be always a http(s) link.\n"
      echo  "Exchange Dark Logo Path: "
      read answer
      local ORIGINAL_CHARACTER_FOR_LOGO_BLACK_PATH="${answer}"
    else
      break;
    fi
  done

  local ESCAPED_HOLLAEX_CONFIGMAP_LOGO_BLACK_PATH=${ORIGINAL_CHARACTER_FOR_LOGO_BLACK_PATH//\//\\/}}

  local PARSE_CHARACTER_FOR_LOGO_BLACK_PATH=${ORIGINAL_CHARACTER_FOR_LOGO_BLACK_PATH//\//\\/}
  local HOLLAEX_CONFIGMAP_LOGO_BLACK_PATH_OVERRIDE="$PARSE_CHARACTER_FOR_LOGO_BLAKC_PATH"

  printf "\n"
  echo "${answer:-$HOLLAEX_CONFIGMAP_LOGO_BLACK_PATH} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # WEB CAPTCHA SITE KEY
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Exchange Web Google reCaptcha Sitekey: (${HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY:-$ENVIRONMENT_WEB_CAPTCHA_SITE_KEY})"
  printf "\033[2m- Enter your Web Google reCpathca site key. \033[22m\n"
  read answer
  
  if [[ ! "$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY" ]]; then

    export HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY=$ENVIRONMENT_WEB_CAPTCHA_SITE_KEY

  fi 

  local HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY_OVERRIDE="${answer:-$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY}"
  
  printf "\n"
  echo "${answer:-$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # Server CAPTCHA Secret key
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Exchange API Server Google reCaptcha Secretkey: ($(echo ${HOLLAEX_SECRET_CAPTCHA_SECRET_KEY//?/◼︎}$(echo $HOLLAEX_SECRET_CAPTCHA_SECRET_KEY | grep -o '....$')))"
  printf "\033[2m- Enter your API Server Google reCaptcha Secretkey. \033[22m\n"
  read answer

  local HOLLAEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE="${answer:-$HOLLAEX_SECRET_CAPTCHA_SECRET_KEY}"

  local HOLLAEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE_MASKED=$(echo ${HOLLAEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE//?/◼︎}$(echo $HOLLAEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE | grep -o '....$'))

  printf "\n"
  echo "$HOLLAEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE_MASKED ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # Web default country
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Default Country: ($ENVIRONMENT_WEB_DEFAULT_COUNTRY)"
  printf "\033[2m- Enter the country code for your exchange. \033[22m\n"
  read answer

  local ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE="${answer:-$ENVIRONMENT_WEB_DEFAULT_COUNTRY}"

  printf "\n"
  echo "${answer:-$ENVIRONMENT_WEB_DEFAULT_COUNTRY} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # Emails timezone
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Timezone: ($HOLLAEX_CONFIGMAP_EMAILS_TIMEZONE)"
  printf "\033[2m- Enter timezone code for your exchange. \033[22m\n"
  read answer

  local ORIGINAL_CHARACTER_FOR_TIMEZONE="${answer:-$HOLLAEX_CONFIGMAP_EMAILS_TIMEZONE}"

  while true;
    do if [[ ! "$ORIGINAL_CHARACTER_FOR_TIMEZONE" =~ ^[A-Za-z/]+$ ]]; then 
      printf "\nInvalid Timezone. Timezone code should be formatted as 'Asia/Seoul' or 'UTC' style.\n"
      echo "Timezone: "
      read answer
      local ORIGINAL_CHARACTER_FOR_TIMEZONE=${answer}
    else
      break;
    fi
  done

  local PARSE_CHARACTER_FOR_TIMEZONE=${ORIGINAL_CHARACTER_FOR_TIMEZONE/\//\\/}
  local HOLLAEX_CONFIGMAP_EMAILS_TIMEZONE_OVERRIDE="$PARSE_CHARACTER_FOR_TIMEZONE"

  printf "\n"
  echo "${answer:-$HOLLAEX_CONFIGMAP_EMAILS_TIMEZONE} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # Valid languages
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Valid Languages: ($HOLLAEX_CONFIGMAP_VALID_LANGUAGES)"
  printf "\033[2m- Separate with comma (,)\033[22m\n"
  read answer

  local HOLLAEX_CONFIGMAP_VALID_LANGUAGES_OVERRIDE="${answer:-$HOLLAEX_CONFIGMAP_VALID_LANGUAGES}"

  while true;
    do if [[ ! "$HOLLAEX_CONFIGMAP_VALID_LANGUAGES_OVERRIDE" =~ ^[a-z,]+$ ]]; then 
      printf "\nInvalid Valid Languages. Value should be all in lower case, and separated with comman (,).\n"
      echo "Valid Languages: "
      read answer
      local HOLLAEX_CONFIGMAP_VALID_LANGUAGES_OVERRIDE=${answer}
    else
      break;
    fi
  done

  printf "\n"
  echo "${HOLLAEX_CONFIGMAP_VALID_LANGUAGES_OVERRIDE} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # Default language
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Default Language: ($HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE)"
  printf "\033[2m- Enter the default language code for the exchange \033[22m\n"
  read answer

  local HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE="${answer:-$HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE}"

  while true;
    do if [[ ! "$HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE" =~ ^[a-z]+$ ]]; then 
      printf "\nInvalid Default Language. Value should be all in lower case.\n"
      echo "Default Language: "
      read answer
      local HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE=${answer}
    else
      break;
    fi
  done

  printf "\n"
  echo "${HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # Default theme
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Default Theme: ($HOLLAEX_CONFIGMAP_DEFAULT_THEME)"
  printf "\033[2m- Between 'white' and 'dark'.\033[22m\n"
  read answer

  local HOLLAEX_CONFIGMAP_DEFAULT_THEME_OVERRIDE="${answer:-$HOLLAEX_CONFIGMAP_DEFAULT_THEME}"

  while true;
    do if [[ "$HOLLAEX_CONFIGMAP_DEFAULT_THEME_OVERRIDE" != "white" ]] && [[ "$HOLLAEX_CONFIGMAP_DEFAULT_THEME_OVERRIDE" != "dark" ]]; then
      echo "Theme should be always between 'white' and 'dark'."
      echo  "Default Theme: "
      read answer 
      local HOLLAEX_CONFIGMAP_DEFAULT_THEME_OVERRIDE="${answer}"
    else
      break;
    fi
  done

  printf "\n"
  echo "$HOLLAEX_CONFIGMAP_DEFAULT_THEME_OVERRIDE ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # API Domain
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Exchange Server API URL: ($HOLLAEX_CONFIGMAP_API_HOST)"
  printf "\033[2m- Keep it as 'http://localhost' for local test exchange.\033[22m\n"
  read answer

  local ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST="${answer:-$HOLLAEX_CONFIGMAP_API_HOST}"

  # while true;
  #   do if [[ ! "$ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST" == *"http"* ]]; then
  #     printf "\nValue should be a full URL including 'http' or 'https'.\n"
  #     echo  "Exchange Server API URL: "
  #     read answer
  #     local ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST="${answer:-$HOLLAEX_CONFIGMAP_API_HOST}"
  #   else
  #     break;
  #   fi
  # done

  if [[ ! "$ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST" == *"http"* ]]; then

    local ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST=$(echo "http://${ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST}")

  fi

  local PARSE_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST=${ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST//\//\\/}
  local EXCHANGE_SERVER_DOMAIN_OVERRIDE="$PARSE_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST"

  printf "\n"
  echo "${ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # User tier number
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Number of User Tiers: ($HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER)"
  printf "\033[2m- Enter number of user level tiers. These are the account types that allow for different trading fees, deposit and withdrawal limit amounts. \033[22m\n"
  read answer

  local EXCHANGE_USER_LEVEL_NUMBER_OVERRIDE=${answer:-$HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER}

  while true;
    do if [[ ! "$EXCHANGE_USER_LEVEL_NUMBER_OVERRIDE" =~ [0-9\ ]+$ ]]; then
      echo "User Tiers should be always number."
      echo  "Number of User Tiers: "
      read answer 
      local EXCHANGE_USER_LEVEL_NUMBER_OVERRIDE="${answer}"
    else
      break;
    fi
  done

  printf "\n"
  echo "${answer:-$HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # DO NOT ASK FOR NON OVERRIDABLE VALUES ON 'hollaex setup --reconfigure'
  if [[ ! "$RECONFIGURE_BASIC_SETTINGS" ]]; then 

    # Admin Email
    echo "***************************************************************"
    echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Admin Email: ($HOLLAEX_CONFIGMAP_ADMIN_EMAIL)"
    printf "\033[2m- Enter the email for the admin. This will be used to first login to your exchange platform. \033[22m\n"
    read answer

    local HOLLAEX_CONFIGMAP_ADMIN_EMAIL_OVERRIDE=${answer:-$HOLLAEX_CONFIGMAP_ADMIN_EMAIL}

    while true;
      do if [[ ! "$HOLLAEX_CONFIGMAP_ADMIN_EMAIL_OVERRIDE" == *"@"* ]]; then
        printf "\nValue should be always an email form, such as 'admin@bitholla.com'.\n"
        echo  "Admin Email: "
        read answer 
        local HOLLAEX_CONFIGMAP_ADMIN_EMAIL_OVERRIDE="${answer}"
      else
        break;
      fi
    done

    printf "\n"
    echo "${answer:-$HOLLAEX_CONFIGMAP_ADMIN_EMAIL} ✔"
    printf "\n"

    local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

    # Admin Password
    echo "***************************************************************"
    echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Admin Password: ($(echo ${HOLLAEX_SECRET_ADMIN_PASSWORD//?/◼︎}$(echo $HOLLAEX_SECRET_ADMIN_PASSWORD | grep -o '....$')))"
    printf "\033[2m- Make sure to input at least 8 characters, at least one digit and one character.\033[22m\n"
    read -s answer

    local HOLLAEX_SECRET_ADMIN_PASSWORD_OVERRIDE=${answer:-$HOLLAEX_SECRET_ADMIN_PASSWORD}

    echo "Retype Admin Password to confirm :"
    read -s answer_confirm
    
    while true;
      do if [[ ! "${answer_confirm}" == "${HOLLAEX_SECRET_ADMIN_PASSWORD_OVERRIDE}" ]]; then
        echo "Password doesn't match. Please type it again."
        echo "Retype Admin Password to confirm : "
        read -s answer_confirm
      else
        break;
      fi
    done

    while true;
      do if [[ "${#HOLLAEX_SECRET_ADMIN_PASSWORD_OVERRIDE}" -lt 8 ]]; then
        printf "\nInvalid Password. Make sure to input at least 8 characters, at least one digit and one character.\n"
        echo "New Admin Password: "
        read -s answer
        local HOLLAEX_SECRET_ADMIN_PASSWORD_OVERRIDE=${answer}
        printf "\nRetype Admin Password to confirm : \n"
        read -s answer_confirm

          while true;
          do if [[ ! "${answer_confirm}" == "${HOLLAEX_SECRET_ADMIN_PASSWORD_OVERRIDE}" ]]; then
            echo "Password doesn't match. Please type it again."
            echo "Retype Admin Password to confirm : "
            read -s answer_confirm
          else
            break;
          fi
          done

      else
        break;
      fi
    
    done

    local HOLLAEX_SECRET_ADMIN_PASSWORD_MASKED=$(echo ${HOLLAEX_SECRET_ADMIN_PASSWORD_OVERRIDE//?/◼︎}$(echo $HOLLAEX_SECRET_ADMIN_PASSWORD_OVERRIDE | grep -o '....$'))

    printf "\n"
    echo "$HOLLAEX_SECRET_ADMIN_PASSWORD_MASKED ✔"
    printf "\n"

    local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

    # Support Email
    echo "***************************************************************"
    echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Support Email: ($HOLLAEX_CONFIGMAP_SUPPORT_EMAIL)"
    printf "\033[2m- Email address to send and receive all support communications. It also sends important notifications such as login, registration, etc. \033[22m\n"
    read answer

    local HOLLAEX_CONFIGMAP_SUPPORT_EMAIL_OVERRIDE=${answer:-$HOLLAEX_CONFIGMAP_SUPPORT_EMAIL}

    while true;
      do if [[ ! "$HOLLAEX_CONFIGMAP_SUPPORT_EMAIL_OVERRIDE" == *"@"* ]]; then
        printf "\nValue should be always an email form, such as 'support@bitholla.com'.\n"
        echo  "Support Email: "
        read answer 
        local HOLLAEX_CONFIGMAP_SUPPORT_EMAIL_OVERRIDE="${answer}"
      else
        break;
      fi
    done

    printf "\n"
    echo "${answer:-$HOLLAEX_CONFIGMAP_SUPPORT_EMAIL} ✔"
    printf "\n"

    local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

    # Supervisor Email
    echo "***************************************************************"
    echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Do you want to create a different role for the exchange supervisor agent? (y/N)"
    printf "\033[2m- Add an exchange supervisor agent role. \033[22m\n"
    read answer

    if [[ ! "$answer" = "${answer#[Yy]}" ]] ;then

      echo "Supervisor Email: ($HOLLAEX_CONFIGMAP_SUPERVISOR_EMAIL)"
      read answer

      local HOLLAEX_CONFIGMAP_SUPERVISOR_EMAIL_OVERRIDE=${answer:-$HOLLAEX_CONFIGMAP_SUPERVISOR_EMAIL}

      while true;
        do if [[ ! "$HOLLAEX_CONFIGMAP_SUPERVISOR_EMAIL_OVERRIDE" == *"@"* ]]; then
          printf "\nValue should be always an email form, such as 'supervisor@bitholla.com'.\n"
          echo  "Supervisor Email: "
          read answer 
          local HOLLAEX_CONFIGMAP_SUPERVISOR_EMAIL_OVERRIDE="${answer}"
        else
          break;
        fi
      done

      printf "\n"
      echo "$HOLLAEX_CONFIGMAP_SUPERVISOR_EMAIL_OVERRIDE ✔"
      printf "\n"
      
    else

      local HOLLAEX_CONFIGMAP_SUPERVISOR_EMAIL_OVERRIDE=

      printf "\n"
      echo "Skipping..."
      printf "\n"

    fi

    local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))


    # KYC Email
    echo "***************************************************************"
    echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Do you want to create a different role for the exchange KYC agent? (y/N)"
    printf "\033[2m- Add an exchange KYC agent role. \033[22m\n"
    read answer

    if [[ ! "$answer" = "${answer#[Yy]}" ]] ;then

      echo "KYC Email: ($HOLLAEX_CONFIGMAP_KYC_EMAIL)"
      read answer

      local HOLLAEX_CONFIGMAP_KYC_EMAIL_OVERRIDE=${answer:-$HOLLAEX_CONFIGMAP_KYC_EMAIL}

      while true;
        do if [[ ! "$HOLLAEX_CONFIGMAP_KYC_EMAIL_OVERRIDE" == *"@"* ]]; then
          printf "\nValue should be always an email form, such as 'kyc@bitholla.com'.\n"
          echo  "KYC Email: "
          read answer 
          local HOLLAEX_CONFIGMAP_KYC_EMAIL_OVERRIDE="${answer}"
        else
          break;
        fi
      done

      printf "\n"
      echo "${answer:-$HOLLAEX_CONFIGMAP_KYC_EMAIL} ✔"
      printf "\n"
      
    else

      local HOLLAEX_CONFIGMAP_KYC_EMAIL_OVERRIDE=

      printf "\n"
      echo "Skipping..."
      printf "\n"

    fi

    local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))
  
  fi

  # New user is activated
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Allow New User Signup?: (Y/n)"
  printf "\033[2m- Allow new users to signup once exchange setup is done. \033[22m\n"
  read answer

  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    HOLLAEX_CONFIGMAP_NEW_USER_IS_ACTIVATED_OVERRIDE=false
  
  else

    HOLLAEX_CONFIGMAP_NEW_USER_IS_ACTIVATED_OVERRIDE=true

  fi

  printf "\n"
  echo "$HOLLAEX_CONFIGMAP_NEW_USER_IS_ACTIVATED_OVERRIDE ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # SMTP Server
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] SMTP Server Endpoint?: ($HOLLAEX_CONFIGMAP_SMTP_SERVER)"
  printf "\033[2m- SMTP Server Endpoint for sending email. \033[22m\n"
  read answer

  local HOLLAEX_CONFIGMAP_SMTP_SERVER_OVERRIDE=${answer:-$HOLLAEX_CONFIGMAP_SMTP_SERVER}

  while true;
    do if [[ "$HOLLAEX_CONFIGMAP_SMTP_SERVER_OVERRIDE" == *"http"* ]]; then
      printf "\nSMTP Server Endpoint should not have http(s) included.\n"
      echo  "Exchange URL: "
      read answer
      local HOLLAEX_CONFIGMAP_SMTP_SERVER_OVERRIDE="${answer}"
    else
      break;
    fi
  done

  printf "\n"
  echo "${answer:-$HOLLAEX_CONFIGMAP_SMTP_SERVER} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # SMTP Port
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] SMTP Port?: ($HOLLAEX_CONFIGMAP_SMTP_PORT)"
  printf "\033[2m- SMTP Server port number for sending email. \033[22m\n"
  read answer

  local HOLLAEX_CONFIGMAP_SMTP_PORT_OVERRIDE=${answer:-$HOLLAEX_CONFIGMAP_SMTP_PORT}

  printf "\n"
  echo "${answer:-$HOLLAEX_CONFIGMAP_SMTP_PORT} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # SMTP User
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] SMTP User?: ($HOLLAEX_CONFIGMAP_SMTP_USER)"
  printf "\033[2m- SMTP Server username for sending email. \033[22m\n"
  read answer

  local HOLLAEX_CONFIGMAP_SMTP_USER_OVERRIDE=${answer:-$HOLLAEX_CONFIGMAP_SMTP_USER}

  printf "\n"
  echo "${answer:-$HOLLAEX_CONFIGMAP_SMTP_USER} ✔"
  printf "\n"

  # SMTP Password
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] SMTP Password?: ($HOLLAEX_CONFIGMAP_SMTP_PASSWORD)"
  printf "\033[2m- SMTP Server password for sending email. \033[22m\n"
  read answer

  local HOLLAEX_SECRET_SMTP_PASSWORD_OVERRIDE=${answer:-$HOLLAEX_CONFIGMAP_SMTP_PASSWORD}

  printf "\n"
  echo "${answer:-$HOLLAEX_SECRET_SMTP_PASSWORD} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # AWS AccessKey
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] AWS AccessKey?: ($HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID) - Optional"
  printf "\033[2m- AWS IAM AccessKey for S3, SNS.\033[22m\n"
  read answer

  local HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID_OVERRIDE=${answer:-$HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID}

  printf "\n"
  echo "${answer:-$HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # AWS SecretKey
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] AWS SecretKey?: ($(echo ${HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY//?/◼︎}$(echo $HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY | grep -o '....$'))) - Optional"
  printf "\033[2m- AWS IAM SecretKey for S3, SNS.\033[22m\n"
  read answer
  local ESCAPED_HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY=${HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY//\//\\\/}

  local ORIGINAL_HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY="${answer:-$HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY}"
  local PARSE_CHARACTER_FOR_HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY=${ORIGINAL_HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY//\//\\\/}
  local HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY_OVERRIDE="$PARSE_CHARACTER_FOR_HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY"

  local HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY_MASKED=$(echo ${ORIGINAL_HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY//?/◼︎}$(echo $ORIGINAL_HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY | grep -o '....$'))
  
  printf "\n"
  echo "$HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY_MASKED ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # AWS Region
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] AWS Region?: ($HOLLAEX_SECRET_SNS_REGION) - Optional"
  printf "\033[2m- AWS Region for SNS.\033[22m\n"
  read answer

  local HOLLAEX_SECRET_SNS_REGION_OVERRIDE=${answer:-$HOLLAEX_SECRET_SNS_REGION}

  printf "\n"
  echo "${answer:-$HOLLAEX_SECRET_SNS_REGION} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # AWS S3 bucket
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] AWS S3 Bucket: ($HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET) - Optional"
  printf "\033[2m- S3 bucket to store user provided ID docs. Should be 'my-bucket:aws-region' style.\033[22m\n"
  read answer

  local HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET_OVERRIDE=${answer:-$HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET}

  printf "\n"
  echo "${answer:-$HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # Vault Name
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Vault Name: ($HOLLAEX_CONFIGMAP_VAULT_NAME) - Optional"
  printf "\033[2m- Vault Name. Check docs to see more details.\033[22m\n"
  read answer

  local HOLLAEX_CONFIGMAP_VAULT_NAME_OVERRIDE=${answer:-$HOLLAEX_CONFIGMAP_VAULT_NAME}

  printf "\n"
  echo "${answer:-$HOLLAEX_CONFIGMAP_VAULT_NAME} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # Vault key
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Vault Key: ($HOLLAEX_SECRET_VAULT_KEY) - Optional"
  printf "\033[2m- Vault Access Key.\033[22m\n"
  read answer

  local HOLLAEX_SECRET_VAULT_KEY_OVERRIDE=${answer:-$HOLLAEX_SECRET_VAULT_KEY}

  printf "\n"
  echo "${answer:-$HOLLAEX_SECRET_VAULT_KEY} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # Vault secret
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Vault Secret: ($(echo ${HOLLAEX_SECRET_VAULT_SECRET//?/◼︎}$(echo $HOLLAEX_SECRET_VAULT_SECRET | grep -o '....$'))) - Optional"
  printf "\033[2m- Vault Secret Key.\033[22m\n"
  read answer

  local HOLLAEX_SECRET_VAULT_SECRET_OVERRIDE=${answer:-$HOLLAEX_SECRET_VAULT_SECRET}
  local HOLLAEX_SECRET_VAULT_SECRET_MASKED=$(echo ${HOLLAEX_SECRET_VAULT_SECRET_OVERRIDE//?/◼︎}$(echo $HOLLAEX_SECRET_VAULT_SECRET_OVERRIDE | grep -o '....$'))

  printf "\n"
  echo "$HOLLAEX_SECRET_VAULT_SECRET_MASKED ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  # FreshDesk Host
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] FreshDesk Host: ($HOLLAEX_CONFIGMAP_FRESHDESK_HOST) - Optional"
  printf "\033[2m- FreshDesk Host URL.\033[22m\n"
  read answer

  local HOLLAEX_CONFIGMAP_FRESHDESK_HOST_OVERRIDE=${answer:-$HOLLAEX_CONFIGMAP_FRESHDESK_HOST}

  printf "\n"
  echo "${answer:-$HOLLAEX_CONFIGMAP_FRESHDESK_HOST} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))


# FreshDesk Key
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] FreshDesk Key: ($HOLLAEX_SECRET_FRESHDESK_KEY) - Optional"
  printf "\033[2m- FreshDesk Access Key.\033[22m\n"
  read answer

  local HOLLAEX_SECRET_FRESHDESK_KEY_OVERRIDE=${answer:-$HOLLAEX_SECRET_FRESHDESK_KEY}

  printf "\n"
  echo "${answer:-$HOLLAEX_SECRET_FRESHDESK_KEY} ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))


# FreshDesk Auth
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] FreshDesk Auth: ($(echo ${HOLLAEX_SECRET_FRESHDESK_AUTH//?/◼︎}$(echo $HOLLAEX_SECRET_FRESHDESK_AUTH | grep -o '....$'))) - Optional"
  printf "\033[2m- FreshDesk Access Auth.\033[22m\n"
  read answer

  local HOLLAEX_SECRET_FRESHDESK_AUTH_OVERRIDE=${answer:-$HOLLAEX_SECRET_FRESHDESK_AUTH}
  local HOLLAEX_SECRET_FRESHDESK_AUTH_MASKED=$(echo ${HOLLAEX_SECRET_FRESHDESK_AUTH_OVERRIDE//?/◼︎}$(echo $HOLLAEX_SECRET_FRESHDESK_AUTH_OVERRIDE | grep -o '....$'))

  printf "\n"
  echo "$HOLLAEX_SECRET_FRESHDESK_AUTH_MASKED ✔"
  printf "\n"

  local QUESTION_NUMBER=$((QUESTION_NUMBER + 1))

  /bin/cat << EOF
  
***************************************************************
Exchange Name: $EXCHANGE_API_NAME_OVERRIDE
Activation Code: $EXCHANGE_ACTIVATION_CODE_MASKED

Exchange URL: $ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN

Light Logo Path: $ORIGINAL_CHARACTER_FOR_LOGO_PATH
Dark Logo Path: $ORIGINAL_CHARACTER_FOR_LOGO_BLACK_PATH

Web Captcha Sitekey: $HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY_OVERRIDE
Server Captcha Secretkey: $HOLLAEX_SECRET_ADMIN_PASSWORD_MASKED

Default Country: $ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE
Timezone: $ORIGINAL_CHARACTER_FOR_TIMEZONE
Valid Languages: $HOLLAEX_CONFIGMAP_VALID_LANGUAGES_OVERRIDE
Default Language: $HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE
Default Theme: $HOLLAEX_CONFIGMAP_DEFAULT_THEME_OVERRIDE

Exchange API URL: $ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST

User Tiers: $EXCHANGE_USER_LEVEL_NUMBER_OVERRIDE
$(if [[ ! "$RECONFIGURE_BASIC_SETTINGS" ]]; then
printf "\n"
echo "Admin Email: $HOLLAEX_CONFIGMAP_ADMIN_EMAIL_OVERRIDE"
echo "Admin Password: $HOLLAEX_SECRET_ADMIN_PASSWORD_MASKED"
echo "Support Email: $HOLLAEX_CONFIGMAP_SUPPORT_EMAIL_OVERRIDE"
echo "Supervisor Email: $HOLLAEX_CONFIGMAP_SUPERVISOR_EMAIL_OVERRIDE"
echo "KYC Email: $HOLLAEX_CONFIGMAP_KYC_EMAIL_OVERRIDE" 
printf "\n"
fi)
Allow New User Signup: $HOLLAEX_CONFIGMAP_NEW_USER_IS_ACTIVATED_OVERRIDE

SMTP Server: $HOLLAEX_CONFIGMAP_SMTP_SERVER_OVERRIDE
SMTP Port: $HOLLAEX_CONFIGMAP_SMTP_PORT_OVERRIDE
SMTP User: $HOLLAEX_CONFIGMAP_SMTP_USER_OVERRIDE
SMTP Password: $HOLLAEX_SECRET_SMTP_PASSWORD_OVERRIDE

AWS AccessKey (Optional): $HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID_OVERRIDE
AWS SecretKey (Optional): $HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY_MASKED
AWS Region (Optional): $HOLLAEX_SECRET_SNS_REGION_OVERRIDE
AWS S3 Bucket (Optional): $HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET_OVERRIDE

Vault Name (Optional): $HOLLAEX_CONFIGMAP_VAULT_NAME_OVERRIDE
Vault Key (Optional): $HOLLAEX_SECRET_VAULT_KEY_OVERRIDE
Vault Secret (Optional): $HOLLAEX_SECRET_VAULT_SECRET_MASKED

FreshDesk Host (Optional): $OLLAEX_CONFIGMAP_FRESHDESK_HOST_OVERRIDE
FreshDesk Key (Optional): $HOLLAEX_SECRET_FRESHDESK_KEY_OVERRIDE
FreshDesk Auth (Optional): $HOLLAEX_SECRET_FRESHDESK_AUTH_MASKED
***************************************************************

EOF

  echo "Are the values all correct? (Y/n)"
  read answer

  if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
      
    echo "You picked false. Please confirm the values and run the command again."
    exit 1;
  
  fi

  echo "Provided values would be updated on your settings file(s) automatically."

  for i in ${CONFIG_FILE_PATH[@]}; do

    # Update exchange name
    if command grep -q "ENVIRONMENT_EXCHANGE_NAME" $i > /dev/null ; then
    CONFIGMAP_FILE_PATH=$i
    #sed -i.bak "s/ENVIRONMENT_EXCHANGE_NAME=$ENVIRONMENT_EXCHANGE_NAME/ENVIRONMENT_EXCHANGE_NAME=$EXCHANGE_NAME_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_API_NAME=.*/HOLLAEX_CONFIGMAP_API_NAME=$EXCHANGE_API_NAME_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_DOMAIN=.*/HOLLAEX_CONFIGMAP_DOMAIN=$EXCHANGE_WEB_DOMAIN_OVERRIDE/" $CONFIGMAP_FILE_PATH

    sed -i.bak "s/ESCAPED_HOLLAEX_CONFIGMAP_LOGO_PATH=.*/ESCAPED_HOLLAEX_CONFIGMAP_LOGO_PATH=$HOLLAEX_CONFIGMAP_LOGO_PATH_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/ESCAPED_HOLLAEX_CONFIGMAP_LOGO_BLACK_PATH=.*/ESCAPED_HOLLAEX_CONFIGMAP_LOGO_BLACK_PATH=$HOLLAEX_CONFIGMAP_LOGO_BLACK_PATH_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY=$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY/HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY=$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/ENVIRONMENT_WEB_DEFAULT_COUNTRY=$ENVIRONMENT_WEB_DEFAULT_COUNTRY/ENVIRONMENT_WEB_DEFAULT_COUNTRY=$ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_EMAILS_TIMEZONE=.*/HOLLAEX_CONFIGMAP_EMAILS_TIMEZONE=$HOLLAEX_CONFIGMAP_EMAILS_TIMEZONE_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_VALID_LANGUAGES=$HOLLAEX_CONFIGMAP_VALID_LANGUAGES/HOLLAEX_CONFIGMAP_VALID_LANGUAGES=$HOLLAEX_CONFIGMAP_VALID_LANGUAGES_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/ENVIRONMENT_WEB_DEFAULT_LANGUAGE=$ENVIRONMENT_WEB_DEFAULT_LANGUAGE/ENVIRONMENT_WEB_DEFAULT_LANGUAGE=$HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE=$HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE/HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE=$HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_DEFAULT_THEME=$HOLLAEX_CONFIGMAP_DEFAULT_THEME/HOLLAEX_CONFIGMAP_DEFAULT_THEME=$HOLLAEX_CONFIGMAP_DEFAULT_THEME_OVERRIDE/" $CONFIGMAP_FILE_PATH

    sed -i.bak "s/HOLLAEX_CONFIGMAP_API_HOST=.*/HOLLAEX_CONFIGMAP_API_HOST=$EXCHANGE_SERVER_DOMAIN_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER=$HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER/HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER=$EXCHANGE_USER_LEVEL_NUMBER_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_ADMIN_EMAIL=$HOLLAEX_CONFIGMAP_ADMIN_EMAIL/HOLLAEX_CONFIGMAP_ADMIN_EMAIL=$HOLLAEX_CONFIGMAP_ADMIN_EMAIL_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_SUPERVISOR_EMAIL=$HOLLAEX_CONFIGMAP_SUPERVISOR_EMAIL/HOLLAEX_CONFIGMAP_SUPERVISOR_EMAIL=$HOLLAEX_CONFIGMAP_SUPERVISOR_EMAIL_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_KYC_EMAIL=$HOLLAEX_CONFIGMAP_KYC_EMAIL/HOLLAEX_CONFIGMAP_KYC_EMAIL=$HOLLAEX_CONFIGMAP_KYC_EMAIL_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_SUPPORT_EMAIL=$HOLLAEX_CONFIGMAP_SUPPORT_EMAIL/HOLLAEX_CONFIGMAP_SUPPORT_EMAIL=$HOLLAEX_CONFIGMAP_SUPPORT_EMAIL_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_SENDER_EMAIL=$HOLLAEX_CONFIGMAP_SENDER_EMAIL/HOLLAEX_CONFIGMAP_SENDER_EMAIL=$HOLLAEX_CONFIGMAP_SUPPORT_EMAIL_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_NEW_USER_IS_ACTIVATED=$HOLLAEX_CONFIGMAP_NEW_USER_IS_ACTIVATED/HOLLAEX_CONFIGMAP_NEW_USER_IS_ACTIVATED=$HOLLAEX_CONFIGMAP_NEW_USER_IS_ACTIVATED_OVERRIDE/" $CONFIGMAP_FILE_PATH

    sed -i.bak "s/HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET=$HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET/HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET=$HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET_OVERRIDE/" $CONFIGMAP_FILE_PATH

    sed -i.bak "s/HOLLAEX_CONFIGMAP_VAULT_NAME=$HOLLAEX_CONFIGMAP_VAULT_NAME/HOLLAEX_CONFIGMAP_VAULT_NAME=$HOLLAEX_CONFIGMAP_VAULT_NAME_OVERRIDE/" $CONFIGMAP_FILE_PATH

    sed -i.bak "s/HOLLAEX_CONFIGMAP_SMTP_SERVER=.*/HOLLAEX_CONFIGMAP_SMTP_SERVER=$HOLLAEX_CONFIGMAP_SMTP_SERVER_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_SMTP_PORT=.*/HOLLAEX_CONFIGMAP_SMTP_PORT=$HOLLAEX_CONFIGMAP_SMTP_PORT_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_SMTP_USER=.*/HOLLAEX_CONFIGMAP_SMTP_USER=$HOLLAEX_CONFIGMAP_SMTP_USER_OVERRIDE/" $CONFIGMAP_FILE_PATH

    #sed -i.bak "s/ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION=.*/ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION=$EXCHANGE_API_NAME_OVERRIDE/" $CONFIGMAP_FILE_PATH

    sed -i.bak "s/HOLLAEX_CONFIGMAP_FRESHDESK_HOST=$HOLLAEX_CONFIGMAP_FRESHDESK_HOST/HOLLAEX_CONFIGMAP_FRESHDESK_HOST=$HOLLAEX_CONFIGMAP_FRESHDESK_HOST_OVERRIDE/" $CONFIGMAP_FILE_PATH
    rm $CONFIGMAP_FILE_PATH.bak
    fi

    # Update activation code
    if command grep -q "HOLLAEX_SECRET_ACTIVATION_CODE" $i > /dev/null ; then
    SECRET_FILE_PATH=$i
    sed -i.bak "s/HOLLAEX_SECRET_ACTIVATION_CODE=$HOLLAEX_SECRET_ACTIVATION_CODE/HOLLAEX_SECRET_ACTIVATION_CODE=$EXCHANGE_ACTIVATION_CODE_OVERRIDE/" $SECRET_FILE_PATH
    sed -i.bak "s/HOLLAEX_SECRET_CAPTCHA_SECRET_KEY=.*/HOLLAEX_SECRET_CAPTCHA_SECRET_KEY=$HOLLAEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE/" $SECRET_FILE_PATH
    sed -i.bak "s/HOLLAEX_SECRET_ADMIN_PASSWORD=.*/HOLLAEX_SECRET_ADMIN_PASSWORD=$HOLLAEX_SECRET_ADMIN_PASSWORD_OVERRIDE/" $SECRET_FILE_PATH

    sed -i.bak "s/HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID=$HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID/HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID=$HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID_OVERRIDE/" $SECRET_FILE_PATH
    sed -i.bak "s/HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY=.*/HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY=$HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY_OVERRIDE/" $SECRET_FILE_PATH

    sed -i.bak "s/HOLLAEX_SECRET_S3_READ_ACCESSKEYID=$HOLLAEX_SECRET_S3_READ_ACCESSKEYID/HOLLAEX_SECRET_S3_READ_ACCESSKEYID=$HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID_OVERRIDE/" $SECRET_FILE_PATH
    sed -i.bak "s/HOLLAEX_SECRET_S3_READ_SECRETACCESSKEY=.*/HOLLAEX_SECRET_S3_READ_SECRETACCESSKEY=$HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY_OVERRIDE/" $SECRET_FILE_PATH

    sed -i.bak "s/HOLLAEX_SECRET_SES_ACCESSKEYID=$HOLLAEX_SECRET_SES_ACCESSKEYID/HOLLAEX_SECRET_SES_ACCESSKEYID=$HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID_OVERRIDE/" $SECRET_FILE_PATH
    sed -i.bak "s/HOLLAEX_SECRET_SES_SECRETACCESSKEY=.*/HOLLAEX_SECRET_SES_SECRETACCESSKEY=$HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY_OVERRIDE/" $SECRET_FILE_PATH

    sed -i.bak "s/HOLLAEX_SECRET_SNS_ACCESSKEYID=$HOLLAEX_SECRET_SNS_ACCESSKEYID/HOLLAEX_SECRET_SNS_ACCESSKEYID=$HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID_OVERRIDE/" $SECRET_FILE_PATH
    sed -i.bak "s/HOLLAEX_SECRET_SNS_SECRETACCESSKEY=.*/HOLLAEX_SECRET_SNS_SECRETACCESSKEY=$HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY_OVERRIDE/" $SECRET_FILE_PATH

    sed -i.bak "s/HOLLAEX_SECRET_SES_REGION=$HOLLAEX_SECRET_SES_REGION/HOLLAEX_SECRET_SES_REGION=$HOLLAEX_SECRET_SNS_REGION_OVERRIDE/" $SECRET_FILE_PATH
    sed -i.bak "s/HOLLAEX_SECRET_SNS_REGION=$HOLLAEX_SECRET_SNS_REGION/HOLLAEX_SECRET_SNS_REGION=$HOLLAEX_SECRET_SNS_REGION_OVERRIDE/" $SECRET_FILE_PATH

    sed -i.bak "s/HOLLAEX_SECRET_VAULT_KEY=$HOLLAEX_SECRET_VAULT_KEY/HOLLAEX_SECRET_VAULT_KEY=$HOLLAEX_SECRET_VAULT_KEY_OVERRIDE/" $SECRET_FILE_PATH
    sed -i.bak "s/HOLLAEX_SECRET_VAULT_SECRET=$HOLLAEX_SECRET_VAULT_SECRET/HOLLAEX_SECRET_VAULT_SECRET=$HOLLAEX_SECRET_VAULT_SECRET_OVERRIDE/" $SECRET_FILE_PATH

    sed -i.bak "s/HOLLAEX_SECRET_FRESHDESK_KEY=$HOLLAEX_SECRET_FRESHDESK_KEY/HOLLAEX_SECRET_FRESHDESK_KEY=$HOLLAEX_SECRET_FRESHDESK_KEY_OVERRIDE/" $SECRET_FILE_PATH
    sed -i.bak "s/HOLLAEX_SECRET_FRESHDESK_AUTH=$HOLLAEX_SECRET_FRESHDESK_AUTH/HOLLAEX_SECRET_FRESHDESK_AUTH=$HOLLAEX_SECRET_FRESHDESK_AUTH_OVERRIDE/" $SECRET_FILE_PATH

    sed -i.bak "s/HOLLAEX_SECRET_SMTP_PASSWORD=.*/HOLLAEX_SECRET_SMTP_PASSWORD=$HOLLAEX_SECRET_SMTP_PASSWORD_OVERRIDE/" $SECRET_FILE_PATH

    rm $SECRET_FILE_PATH.bak
    fi
      
  done

  #export ENVIRONMENT_EXCHANGE_NAME=$EXCHANGE_NAME_OVERRIDE
  export HOLLAEX_CONFIGMAP_API_NAME=$EXCHANGE_API_NAME_OVERRIDE
  export HOLLAEX_SECRET_ACTIVATION_CODE=$EXCHANGE_ACTIVATION_CODE_OVERRIDE

  export ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION=$EXCHANGE_API_NAME_OVERRIDE

  export HOLLAEX_CONFIGMAP_DOMAIN=$ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN

  export HOLLAEX_CONFIGMAP_LOGO_PATH="$HOLLAEX_CONFIGMAP_LOGO_PATH_OVERRIDE"
  export HOLLAEX_CONFIGMAP_LOGO_BLACK_PATH="$HOLLAEX_CONFIGMAP_LOGO_BLACK_PATH_OVERRIDE"

  export HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY=$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY_OVERRIDE
  export HOLLAEX_SECRET_CAPTCHA_SECRET_KEY=$HOLLAEX_SECRET_CAPTCHA_SECRET_KEY_OVERRIDE

  export ENVIRONMENT_WEB_DEFAULT_COUNTRY=$ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE
  export HOLLAEX_CONFIGMAP_EMAILS_TIMEZONE=$ORIGINAL_CHARACTER_FOR_TIMEZONE
  export HOLLAEX_CONFIGMAP_VALID_LANGUAGES=$HOLLAEX_CONFIGMAP_VALID_LANGUAGES_OVERRIDE
  export HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE=$HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE
  export ENVIRONMENT_WEB_DEFAULT_LANGUAGE=$HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE
  export HOLLAEX_CONFIGMAP_DEFAULT_THEME=$HOLLAEX_CONFIGMAP_DEFAULT_THEME_OVERRIDE

  export HOLLAEX_CONFIGMAP_API_HOST=$ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST
  export HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER=$EXCHANGE_USER_LEVEL_NUMBER_OVERRIDE

  if [[ ! "$RECONFIGURE_BASIC_SETTINGS" ]]; then

    export HOLLAEX_CONFIGMAP_ADMIN_EMAIL=$HOLLAEX_CONFIGMAP_ADMIN_EMAIL_OVERRIDE
    export HOLLAEX_SECRET_ADMIN_PASSWORD=$HOLLAEX_SECRET_ADMIN_PASSWORD_OVERRIDE
    export HOLLAEX_CONFIGMAP_SUPERVISOR_EMAIL=$HOLLAEX_CONFIGMAP_SUPERVISOR_EMAIL_OVERRIDE
    export HOLLAEX_CONFIGMAP_KYC_EMAIL=$HOLLAEX_CONFIGMAP_KYC_EMAIL_OVERRIDE
    export HOLLAEX_CONFIGMAP_SUPPORT_EMAIL=$HOLLAEX_CONFIGMAP_SUPPORT_EMAIL_OVERRIDE
    export HOLLAEX_CONFIGMAP_SENDER_EMAIL=$HOLLAEX_CONFIGMAP_SENDER_EMAIL_OVERRIDE
  
  fi

  export HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID=$HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID_OVERRIDE
  export HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY=$HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY_OVERRIDE
  export HOLLAEX_SECRET_SES_REGION=$HOLLAEX_SECRET_SNS_REGION_OVERRIDE

  export HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET=$HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET_OVERRIDE

  export HOLLAEX_CONFIGMAP_VAULT_NAME=$HOLLAEX_CONFIGMAP_VAULT_NAME_OVERRIDE
  export HOLLAEX_SECRET_VAULT_KEY=$HOLLAEX_SECRET_VAULT_KEY_OVERRIDE
  export HOLLAEX_SECRET_VAULT_SECRET=$HOLLAEX_SECRET_VAULT_SECRET_OVERRIDE

  export HOLLAEX_CONFIGMAP_FRESHDESK_HOST=$HOLLAEX_CONFIGMAP_FRESHDESK_HOST_OVERRIDE
  export HOLLAEX_SECRET_FRESHDESK_KEY=$HOLLAEX_SECRET_FRESHDESK_KEY_OVERRIDE
  export HOLLAEX_SECRET_FRESHDESK_AUTH=$HOLLAEX_SECRET_FRESHDESK_AUTH_OVERRIDE

  export HOLLAEX_CONFIGMAP_SMTP_SERVER=$HOLLAEX_CONFIGMAP_SMTP_SERVER_OVERRIDE
  export HOLLAEX_CONFIGMAP_SMTP_PORT=$HOLLAEX_CONFIGMAP_SMTP_PORT_OVERRIDE
  export HOLLAEX_CONFIGMAP_SMTP_USER=$HOLLAEX_CONFIGMAP_SMTP_USER_OVERRIDE
  export HOLLAEX_SECRET_SMTP_PASSWORD=$HOLLAEX_SECRET_SMTP_PASSWORD_OVERRIDE

}

function basic_settings_for_web_client_input() {

  /bin/cat << EOF
  
Please fill up the interaction form to setup your Web Client.

Make sure to you already setup HOLLAEX exchange first before setup the web client.
Web client relies on HOLLAEX exchange to function.

Please visit docs.bitholla.com to see the details or need any help.

EOF

  # Web Domain
  echo "***************************************************************"
  echo "[1/5] Exchange URL: ($HOLLAEX_CONFIGMAP_DOMAIN)"
  printf "\033[2m- Enter the full URL of your exchange website including 'http' or 'https'.\033[22m\n"
  read answer

  local ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN="${answer:-$HOLLAEX_CONFIGMAP_DOMAIN}"

  while true;
    do if [[ ! "$ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN" == *"http"* ]]; then
      printf "\nValue should be a full URL including 'http' or 'https'.\n"
      echo  "Exchange URL: "
      read answer
      local ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN="${answer}"
    else
      break;
    fi
  done

  local PARSE_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN=${ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN//\//\\/}
  local EXCHANGE_WEB_DOMAIN_OVERRIDE="$PARSE_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN"

  printf "\n"
  echo "${answer:-$HOLLAEX_CONFIGMAP_DOMAIN} ✔"
  printf "\n"

  # API Domain
  echo "***************************************************************"
  echo "[$(echo $QUESTION_NUMBER)/$TOTAL_QUESTIONS] Exchange Server API URL: ($HOLLAEX_CONFIGMAP_API_HOST)"
  printf "\033[2m- Enter the full URL of your exchange API server including 'http' or 'https'. Keep it as 'http://localhost' for local test exchange.\033[22m\n"
  read answer

  local ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST="${answer:-$HOLLAEX_CONFIGMAP_API_HOST}"

  while true;
    do if [[ ! "$ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST" == *"http"* ]]; then
      printf "\nValue should be a full URL including 'http' or 'https'.\n"
      echo  "Exchange Server API URL: "
      read answer
      local ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST="${answer:-$HOLLAEX_CONFIGMAP_API_HOST}"
    else
      break;
    fi
  done

  local PARSE_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST=${ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST//\//\\/}
  local EXCHANGE_SERVER_DOMAIN_OVERRIDE="$PARSE_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST"

  printf "\n"
  echo "${answer:-$HOLLAEX_CONFIGMAP_API_HOST} ✔"
  printf "\n"

  # WEB CAPTCHA SITE KEY
  echo "***************************************************************"
  echo "[3/5] Exchange Web Google reCaptcha Sitekey: ($HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY:-$ENVIRONMENT_WEB_CAPTCHA_SITE_KEY)"
  printf "\n"
  read answer

  if [[ ! "$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY" ]]; then

    export HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY=$ENVIRONMENT_WEB_CAPTCHA_SITE_KEY

  fi

  local HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY_OVERRIDE="${answer:-$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY}"

  printf "\n"
  echo "${answer:-$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY} ✔"
  printf "\n"

  # Web default country
  echo "***************************************************************"
  echo "[4/5] Default Country: ($ENVIRONMENT_WEB_DEFAULT_COUNTRY)"
  printf "\n"
  read answer

  local ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE="${answer:-$ENVIRONMENT_WEB_DEFAULT_COUNTRY}"

  printf "\n"
  echo "${answer:-$ENVIRONMENT_WEB_DEFAULT_COUNTRY} ✔"
  printf "\n"

  # Default language
  echo "***************************************************************"
  echo "[5/5] Default Language: ($ENVIRONMENT_WEB_DEFAULT_LANGUAGE)"
  printf "\n"
  read answer

  local ENVIRONMENT_WEB_DEFAULT_LANGUAGE_OVERRIDE="${answer:-$ENVIRONMENT_WEB_DEFAULT_LANGUAGE}"

  printf "\n"
  echo "${answer:-$ENVIRONMENT_WEB_DEFAULT_LANGUAGE} ✔"
  printf "\n"

  /bin/cat << EOF
  
*********************************************
Exchange URL: $ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN

Exchange Server API URL: $ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST

Web Captcha Sitekey: $HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY_OVERRIDE

Default Country: $ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE

Default Language: $ENVIRONMENT_WEB_DEFAULT_LANGUAGE_OVERRIDE
*********************************************

EOF

  echo "Are the values are all correct? (Y/n)"
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
    sed -i.bak "s/HOLLAEX_CONFIGMAP_DOMAIN=.*/HOLLAEX_CONFIGMAP_DOMAIN=$EXCHANGE_WEB_DOMAIN_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_API_HOST=.*/HOLLAEX_CONFIGMAP_API_HOST=$EXCHANGE_SERVER_DOMAIN_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY=$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY/HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY=$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/ENVIRONMENT_WEB_DEFAULT_COUNTRY=$ENVIRONMENT_WEB_DEFAULT_COUNTRY/ENVIRONMENT_WEB_DEFAULT_COUNTRY=$ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE/" $CONFIGMAP_FILE_PATH
    sed -i.bak "s/ENVIRONMENT_WEB_DEFAULT_LANGUAGE=$ENVIRONMENT_WEB_DEFAULT_LANGUAGE/ENVIRONMENT_WEB_DEFAULT_LANGUAGE=$ENVIRONMENT_WEB_DEFAULT_LANGUAGE_OVERRIDE/" $CONFIGMAP_FILE_PATH
    rm $CONFIGMAP_FILE_PATH.bak
    fi
      
  done

  export HOLLAEX_CONFIGMAP_DOMAIN=$ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_DOMAIN

  export HOLLAEX_CONFIGMAP_API_HOST=$ORIGINAL_CHARACTER_FOR_HOLLAEX_CONFIGMAP_API_HOST

  export HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY=$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY_OVERRIDE
  
  export ENVIRONMENT_WEB_DEFAULT_COUNTRY=$ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE

  export ENVIRONMENT_WEB_DEFAULT_LANGUAGE=$ENVIRONMENT_WEB_DEFAULT_LANGUAGE_OVERRIDE

}

# function reactivate_exchange() {
  
# echo "Are the sure your want to reactivate your exchange? (y/N)"
# echo "Make sure you already updated your Activation Code, Exchange Name, or API Server URL."
# read answer

# if [[ "$answer" = "${answer#[Yy]}" ]]; then
    
#   echo "You picked false. Please confirm the values and run the command again."
#   exit 1;

# fi

# if [[ "$USE_KUBERNETES" ]]; then


#   echo "*********************************************"
#   echo "Verifying current KUBECONFIG on the machine"
#   kubectl get nodes
#   echo "*********************************************"

#   if [[ "$RUN_WITH_VERIFY" == true ]]; then


#       echo "Is this a correct Kubernetes cluster? (Y/n)"

#       read answer

#       if [[ ! "$answer" = "${answer#[Nn]}" ]] ;then
#           echo "Exiting..."
#           exit 0;
#       fi

#   fi

#   echo "Reactivating the exchange..."
  
#   # Generate Kubernetes Configmap
#     cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/reactivate-exchange.yaml <<EOL
# job:
#   enable: true
#   mode: reactivate_exchange
# EOL


#   echo "Generating Kubernetes Configmap"
#   generate_kubernetes_configmap;

#   echo "Generating Kubernetes Secret"
#   generate_kubernetes_secret;

#   echo "Applying configmap on the namespace"
#   kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-configmap.yaml

#   echo "Applying secret on the namespace"
#   kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-secret.yaml

#   if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-reactivate-exchange \
#                 --namespace $ENVIRONMENT_EXCHANGE_NAME \
#                 --set DEPLOYMENT_MODE="api" \
#                 --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
#                 --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
#                 --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
#                 --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
#                 -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex.yaml \
#                 -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml \
#                 -f $TEMPLATE_GENERATE_PATH/kubernetes/config/reactivate-exchange.yaml \
#                 $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server; then

#     echo "Kubernetes Job has been created for reactivating your exchange."

#     echo "Waiting until Job get completely run"
#     sleep 30;


#   else 

#     printf "\033[91mFailed to create Kubernetes Job for reactivating your exchange, Please confirm your input values and try again.\033[39m\n"
#     helm del --purge $ENVIRONMENT_EXCHANGE_NAME-reactivate-exchange
  
#   fi

#   if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-reactivate-exchange \
#             --namespace $ENVIRONMENT_EXCHANGE_NAME \
#             -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

#     echo "Successfully reactivated your exchange!"
#     kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-reactivate-exchange

#     echo "Removing created Kubernetes Job for reactivating the exchange..."
#     helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME

#     echo "Restarting the exchange..."
#     kubectl delete pods --namespace $ENVIRONMENT_EXCHANGE_NAME -l role=$$ENVIRONMENT_EXCHANGE_NAME
  
#   else 

#     printf "\033[91mFailed to create Kubernetes Job for reactivating your exchange, Please confirm your input values and try again.\033[39m\n"

#     echo "Displaying logs..."
#     kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-reactivate-exchange

#     helm del --purge $ENVIRONMENT_EXCHANGE_NAME-reactivate-exchange
  
#   fi

# elif [[ ! "$USE_KUBERNETES" ]]; then

#   IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

#   # Overriding container prefix for develop server
#   if [[ "$IS_DEVELOP" ]]; then
    
#     CONTAINER_PREFIX=

#   fi

#   echo "Reactivating the exchange..."
#   if command docker exec --env "API_HOST=${PAIR_NAME}" \
#                   --env "API_NA<E=${PAIR_BASE}" \
#                   --env "ACTIVATION_CODE=${PAIR_2}" \
#                   ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
#                   node tools/dbs/setActivationCode.js; then
  
#     echo "Restarting the exchange to apply changes."

#     if  [[ "$IS_DEVELOP" ]]; then

#       # Restarting containers after database init jobs.
#       echo "Restarting containers to apply database changes."
#       docker-compose -f $HOLLAEX_CORE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml stop
#       docker-compose -f $HOLLAEX_CORE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d

#     else

#       # Restarting containers after database init jobs.
#       echo "Restarting containers to apply database changes."
#       docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml stop
#       docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d

#     fi

#     echo "Successfully reactivated the exchange."
  
#   else 

#     printf "\033[91mFailed to reactivate the exchange. Please review your configurations and try again.\033[39m\n"
#     exit 1;

#   fi

# fi

# exit 0;

# } 

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

    $(if [[ "$USE_KUBERNETES" ]]; then 
      if ! command helm ls | grep $ENVIRONMENT_EXCHANGE_NAME-web > /dev/null 2>&1; then 
        echo "You can proceed to setup the web server with 'hollaex web --setup --kube'." 
      fi 
    elif [[ ! "$USE_KUBERNETES" ]]; then 
      if ! command docker ps | grep $ENVIRONMENT_EXCHANGE_NAME-web > /dev/null 2>&1; then 
        echo "You can proceed to setup the web server with 'hollaex web --setup'." 
      fi 
    fi)

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

    Please run 'hollaex restart$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)' and 'hollaex web --restart$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)'
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
    Run 'hollaex start$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)' to start the exchange.
          
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
    Run 'hollaex setup$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)' to setup the exchange from a scratch.
                 

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

    Exchange has been successfully upgraded!
    Try to reach $HOLLAEX_CONFIGMAP_API_HOST

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

  # Preparing HollaEx Core image with custom mail configurations
  echo "Building the user HollaEx Core image with user custom Kit setups."

  if command docker build -t $ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION -f $HOLLAEX_CLI_INIT_PATH/Dockerfile $HOLLAEX_CLI_INIT_PATH; then

      echo "Your custom HollaEx Core image has been successfully built."

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

      override_user_hollaex_core;

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

            export USER_HOLLAEX_CORE_PUSHED=false

          else 

            push_user_hollaex_core;
            export USER_HOLLAEX_CORE_PUSHED=true
        
          fi

      else 

        echo "Pushing the built image to the Docker Registry..."

        push_user_hollaex_core;
        export USER_HOLLAEX_CORE_PUSHED=true
      
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

          printf "\033[93mHollaEx Kit deployment for Kubernetes requires user's HollaEx Core image pushed at Docker Registry.\033[39m\n"
          echo "Plesae try again after you confirm the image name is correct, and got proper Docker Registry access."
          exit 1;

      fi
  
  fi

}

function build_user_hollaex_web() {

  # Preparing HollaEx Core image with custom mail configurations
  echo "Building the user HollaEx Web image."

  if [[ ! "$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY" ]] || [[ ! "$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION" ]]; then

    echo "Error: Your 'ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY' or 'ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION' is missing!"
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

      override_user_hollaex_web;

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
          echo "Please run 'hollaex web --restart' to apply the new image."
        
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
          echo "Please run 'hollaex web --restart' to apply the new image."
  
      else

          echo "HollaEx Kit deployment for Kubernetes requires user's HollaEx Core image pushed at Docker Registry."
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

function create_kubernetes_docker_registry_secret() {

   if [[ ! "$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME" ]] || [[ ! "$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD" ]] || [[ ! "$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL" ]] || [[ "$MANUAL_DOCKER_REGISTRY_SECRET_UPDATE" ]] ; then

    echo "Docker registry credentials are not detected on your secret file of HollaEx Kit directory."
    echo "You can provide them now on here."

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

    export ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_HOST=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_HOST_OVERRIDE
    export ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_USERNAME_OVERRIDE
    export ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_PASSWORD_OVERRIDE
    export ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL=$ENVIRONMENT_KUBERNETES_DOCKER_REGISTRY_EMAIL_OVERRIDE

    echo "Are you sure you want to proceed with this credentials? (Y/n)"
    read answer

    if [[ ! "$answer" = "${answer#[Nn]}" ]] ;then
        echo "HollaEx Kit on Kubernetes mandatorily requires docker registry secret for running."
        echo "Please try it again."
        create_kubernetes_docker_registry_secret;
    fi

    override_kubernetes_docker_registry_secret;
  
  fi

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

          Coin $COIN_SYMBOL has been successfully added
          Please run 'hollaex restart$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)' to activate it.

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

      Trading Pair ${PAIR_NAME} has been successfully added
      Please run 'hollaex restart$(if [[ "$USE_KUBERNETES" ]]; then echo " --kube"; fi)' to activate it.

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
  printf "\033[2m- Go to https://dash.bitholla.com to issue your activation code.\033[22m\n" 
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

    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-set-activation-code \
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
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-set-activation-code

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-set-activation-code --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Your activation code has been successfully updated on your exchange!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-set-activation-code

      echo "Removing created Kubernetes Job for updating the activation code..."
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-set-activation-code

    else 

      printf "\033[91mFailed to update the activation code! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-set-activation-code
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-set-activation-code

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

    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-check-constants \
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
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-check-constants

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-check-constants --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Your missing database constants has been successfully updated!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-check-constants

      echo "Removing created Kubernetes Job for setting up the config..."
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-check-constants

      echo "Successfully updated the missing database constants with your local configmap values."
      echo "Make sure to run 'hollaex restart --kube' to fully apply it."

    else 

      printf "\033[91mFailed to update the database constants! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-check-constants
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-check-constants

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

    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-set-config \
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
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-set-config

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-set-config --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Your database constants has been successfully updated!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-set-config

      echo "Removing created Kubernetes Job for setting up the config..."
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-set-config

      echo "Successfully updated database constants with your local configmap values."
      echo "Make sure to run 'hollaex restart --kube' to fully apply it."

    else 

      printf "\033[91mFailed to update the database constants! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-set-config
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-set-config

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

    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-set-security \
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
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-set-security

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-set-security --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Your database constants has been successfully updated!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-set-security

      echo "Removing created Kubernetes Job for setting up security values..."
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-set-security

      echo "Successfully updated security values with your local configmap values."
      echo "Make sure to run 'hollaex restart --kube' to fully apply it."

    else 

      printf "\033[91mFailed to update the database constants! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-set-security
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-set-security

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
  local ORIGINAL_CHARACTER_FOR_LOGO_PATH=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.LOGO_IMAGE_LIGHT";)
  local HOLLAEX_CONFIGMAP_LOGO_PATH_OVERRIDE="${ORIGINAL_CHARACTER_FOR_LOGO_PATH//\//\\/}"

  #LOGO BLACK PATH ESCAPING
  local ORIGINAL_CHARACTER_FOR_LOGO_BLACK_PATH=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.LOGO_IMAGE_DARK";)
  local HOLLAEX_CONFIGMAP_LOGO_BLACK_PATH_OVERRIDE="${ORIGINAL_CHARACTER_FOR_LOGO_BLACK_PATH//\//\\/}"

  local ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.DEFAULT_COUNTRY";)

  local ORIGINAL_CHARACTER_FOR_TIMEZONE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.TIME_ZONE";)
  local HOLLAEX_CONFIGMAP_EMAILS_TIMEZONE_OVERRIDE="${ORIGINAL_CHARACTER_FOR_TIMEZONE/\//\\/}"

  local HOLLAEX_CONFIGMAP_VALID_LANGUAGES_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.LANGUAGE";)
  local HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.LANGUAGE";)

  #Converting wrong language definition to correct format.
  if [[ "$HOLLAEX_CONFIGMAP_VALID_LANGUAGES_OVERRIDE" == "English" ]]; then

    local HOLLAEX_CONFIGMAP_VALID_LANGUAGES_OVERRIDE="en"
    local HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE="en"

  fi

  local HOLLAEX_CONFIGMAP_DEFAULT_THEME_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.DEFAULT_COLOR";)
  
  #CURRENCIES CONVERTING TO ARRAY AND EXPORT
  local CURRENCIES_ARRAY_COUNT=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ASSETS" | jq '.| length ')
  local CURRENCIES_ARRAY_COUNT=$(($CURRENCIES_ARRAY_COUNT-1))

  for ((i=0;i<=CURRENCIES_ARRAY_COUNT;i++)); do 

      currencies_array+=( "$(echo "$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ASSETS[$i].ASSET_SYMBOL")" )" )

  done

  local HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(IFS=','; echo "${currencies_array[*]}")
  unset currencies_array

  #PAIRS CONVERTING TO ARRAY AND EXPORT
  local PAIRS_ARRAY_COUNT=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS" | jq '.| length ')
  local PAIRS_ARRAY_COUNT=$(($PAIRS_ARRAY_COUNT-1))

  for ((i=0;i<=PAIRS_ARRAY_COUNT;i++)); do 

      pairs_array+=( "$(echo "$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS[$i].BASE_ASSET")-$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.PAIRS[$i].PRICED_ASSET")")" )
  
  done;

  local HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE=$(IFS=','; echo "${pairs_array[*]}")
  unset pairs_array

  local HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ACCOUNT_TIERS";)

  local HOLLAEX_CONFIGMAP_ADMIN_EMAIL_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ADMIN_EMAIL";)
  local HOLLAEX_CONFIGMAP_SUPPORT_EMAIL_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.tech.RECEIVING_EMAIL";)
  local HOLLAEX_CONFIGMAP_SENDER_EMAIL_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.tech.DISTRIBUTION_EMAIL";)

  local HOLLAEX_CONFIGMAP_SMTP_SERVER_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.tech.AUTOMATED_EMAIL_SERVER";)
  local HOLLAEX_CONFIGMAP_SMTP_PORT_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.tech.AUTOMATED_EMAIL_PORT";)
  local HOLLAEX_CONFIGMAP_SMTP_USER_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.tech.AUTOMATED_EMAIL_USER";)
  
  local HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET_OVERRIDE=$(echo "$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.tech.STORAGE_TYPE";):$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.tech.STORAGE_REGION";)")

  # Set the default HollaEx Core version as the maximum compatible version of the current release of CLI.
  local ENVIRONMENT_DOCKER_IMAGE_VERSION_OVERRIDE="$HOLLAEX_CORE_MAXIMUM_COMPATIBLE"

  local HOLLAEX_CONFIGMAP_TECH_EMAIL_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.TECH_EMAIL";)

  # Secrets
  local HOLLAEX_SECRET_ADMIN_PASSWORD_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ADMIN_PASSWORD";)

  ## SMTP Password escaping
  local ORIGINAL_CHARACTER_FOR_SMTP_PASSWORD=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.tech.AUTOAMTED_EMAIL_PASSWORD";)
  local PARSE_CHARACTER_FOR_SMTP_PASSWORD=${ORIGINAL_CHARACTER_FOR_SMTP_PASSWORD//\//\\\/}
  local HOLLAEX_SECRET_SMTP_PASSWORD_OVERRIDE="$PARSE_CHARACTER_FOR_SMTP_PASSWORD"

  local HOLLAEX_SECRET_S3_ACCESSKEYID_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.tech.STORAGE_KEY";)
  local HOLLAEX_SECRET_S3_SECRETACCESSKEY_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.tech.STORAGE_SECRET";)
  local HOLLAEX_SECRET_S3_REGION_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.tech.STORAGE_REGION";)

  local HOLLAEX_SECRET_TECH_PASSWORD_OVERRIDE=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.TECH_PASSWORD";)

    
  # CONFIGMAP 
  sed -i.bak "s/ENVIRONMENT_EXCHANGE_NAME=.*/ENVIRONMENT_EXCHANGE_NAME=$ENVIRONMENT_EXCHANGE_NAME_OVERRIDE/" $CONFIGMAP_FILE_PATH

  sed -i.bak "s/HOLLAEX_CONFIGMAP_API_NAME=.*/HOLLAEX_CONFIGMAP_API_NAME=$HOLLAEX_CONFIGMAP_API_NAME_OVERRIDE/" $CONFIGMAP_FILE_PATH

  sed -i.bak "s/HOLLAEX_CONFIGMAP_LOGO_PATH=.*/HOLLAEX_CONFIGMAP_LOGO_PATH=$HOLLAEX_CONFIGMAP_LOGO_PATH_OVERRIDE/" $CONFIGMAP_FILE_PATH
  sed -i.bak "s/HOLLAEX_CONFIGMAP_LOGO_BLACK_PATH=.*/HOLLAEX_CONFIGMAP_LOGO_BLACK_PATH=$HOLLAEX_CONFIGMAP_LOGO_BLACK_PATH_OVERRIDE/" $CONFIGMAP_FILE_PATH
  
  sed -i.bak "s/ENVIRONMENT_WEB_DEFAULT_COUNTRY=$ENVIRONMENT_WEB_DEFAULT_COUNTRY/ENVIRONMENT_WEB_DEFAULT_COUNTRY=$ENVIRONMENT_WEB_DEFAULT_COUNTRY_OVERRIDE/" $CONFIGMAP_FILE_PATH
  sed -i.bak "s/HOLLAEX_CONFIGMAP_EMAILS_TIMEZONE=.*/HOLLAEX_CONFIGMAP_EMAILS_TIMEZONE=$HOLLAEX_CONFIGMAP_EMAILS_TIMEZONE_OVERRIDE/" $CONFIGMAP_FILE_PATH
  sed -i.bak "s/HOLLAEX_CONFIGMAP_VALID_LANGUAGES=$HOLLAEX_CONFIGMAP_VALID_LANGUAGES/HOLLAEX_CONFIGMAP_VALID_LANGUAGES=$HOLLAEX_CONFIGMAP_VALID_LANGUAGES_OVERRIDE/" $CONFIGMAP_FILE_PATH
  sed -i.bak "s/HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE=$HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE/HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE=$HOLLAEX_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE_OVERRIDE/" $CONFIGMAP_FILE_PATH
  sed -i.bak "s/HOLLAEX_CONFIGMAP_DEFAULT_THEME=$HOLLAEX_CONFIGMAP_DEFAULT_THEME/HOLLAEX_CONFIGMAP_DEFAULT_THEME=$HOLLAEX_CONFIGMAP_DEFAULT_THEME_OVERRIDE/" $CONFIGMAP_FILE_PATH

  sed -i.bak "s/HOLLAEX_CONFIGMAP_CURRENCIES=$HOLLAEX_CONFIGMAP_CURRENCIES/HOLLAEX_CONFIGMAP_CURRENCIES=$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
  sed -i.bak "s/HOLLAEX_CONFIGMAP_PAIRS=.*/HOLLAEX_CONFIGMAP_PAIRS='$HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE'/" $CONFIGMAP_FILE_PATH

  sed -i.bak "s/HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER=$HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER/HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER=$HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER_OVERRIDE/" $CONFIGMAP_FILE_PATH
  sed -i.bak "s/HOLLAEX_CONFIGMAP_ADMIN_EMAIL=$HOLLAEX_CONFIGMAP_ADMIN_EMAIL/HOLLAEX_CONFIGMAP_ADMIN_EMAIL=$HOLLAEX_CONFIGMAP_ADMIN_EMAIL_OVERRIDE/" $CONFIGMAP_FILE_PATH
  sed -i.bak "s/HOLLAEX_CONFIGMAP_SUPPORT_EMAIL=$HOLLAEX_CONFIGMAP_SUPPORT_EMAIL/HOLLAEX_CONFIGMAP_SUPPORT_EMAIL=$HOLLAEX_CONFIGMAP_SUPPORT_EMAIL_OVERRIDE/" $CONFIGMAP_FILE_PATH
  sed -i.bak "s/HOLLAEX_CONFIGMAP_SENDER_EMAIL=$HOLLAEX_CONFIGMAP_SENDER_EMAIL/HOLLAEX_CONFIGMAP_SENDER_EMAIL=$HOLLAEX_CONFIGMAP_SENDER_EMAIL_OVERRIDE/" $CONFIGMAP_FILE_PATH

  sed -i.bak "s/HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET=$HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET/HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET=$HOLLAEX_CONFIGMAP_ID_DOCS_BUCKET_OVERRIDE/" $CONFIGMAP_FILE_PATH

  sed -i.bak "s/HOLLAEX_CONFIGMAP_SMTP_SERVER=.*/HOLLAEX_CONFIGMAP_SMTP_SERVER=$HOLLAEX_CONFIGMAP_SMTP_SERVER_OVERRIDE/" $CONFIGMAP_FILE_PATH
  sed -i.bak "s/HOLLAEX_CONFIGMAP_SMTP_PORT=.*/HOLLAEX_CONFIGMAP_SMTP_PORT=$HOLLAEX_CONFIGMAP_SMTP_PORT_OVERRIDE/" $CONFIGMAP_FILE_PATH
  sed -i.bak "s/HOLLAEX_CONFIGMAP_SMTP_USER=.*/HOLLAEX_CONFIGMAP_SMTP_USER=$HOLLAEX_CONFIGMAP_SMTP_USER_OVERRIDE/" $CONFIGMAP_FILE_PATH

  sed -i.bak "s/ENVIRONMENT_DOCKER_IMAGE_VERSION=.*/ENVIRONMENT_DOCKER_IMAGE_VERSION=$ENVIRONMENT_DOCKER_IMAGE_VERSION_OVERRIDE/" $CONFIGMAP_FILE_PATH

  sed -i.bak "s/HOLLAEX_CONFIGMAP_TECH_EMAIL=.*/HOLLAEX_CONFIGMAP_TECH_EMAIL=$HOLLAEX_CONFIGMAP_TECH_EMAIL_OVERRIDE/" $CONFIGMAP_FILE_PATH

  # SECRET 
  sed -i.bak "s/HOLLAEX_SECRET_ADMIN_PASSWORD=.*/HOLLAEX_SECRET_ADMIN_PASSWORD=$HOLLAEX_SECRET_ADMIN_PASSWORD_OVERRIDE/" $SECRET_FILE_PATH

  sed -i.bak "s/HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID=$HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID/HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID=$HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID_OVERRIDE/" $SECRET_FILE_PATH
  sed -i.bak "s/HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY=.*/HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY=$HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY_OVERRIDE/" $SECRET_FILE_PATH

  sed -i.bak "s/HOLLAEX_SECRET_S3_READ_ACCESSKEYID=$HOLLAEX_SECRET_S3_READ_ACCESSKEYID/HOLLAEX_SECRET_S3_READ_ACCESSKEYID=$HOLLAEX_SECRET_S3_WRITE_ACCESSKEYID_OVERRIDE/" $SECRET_FILE_PATH
  sed -i.bak "s/HOLLAEX_SECRET_S3_READ_SECRETACCESSKEY=.*/HOLLAEX_SECRET_S3_READ_SECRETACCESSKEY=$HOLLAEX_SECRET_S3_WRITE_SECRETACCESSKEY_OVERRIDE/" $SECRET_FILE_PATH

  sed -i.bak "s/HOLLAEX_SECRET_SMTP_PASSWORD=.*/HOLLAEX_SECRET_SMTP_PASSWORD=$HOLLAEX_SECRET_SMTP_PASSWORD_OVERRIDE/" $SECRET_FILE_PATH

  sed -i.bak "s/HOLLAEX_SECRET_TECH_PASSWORD=.*/HOLLAEX_SECRET_TECH_PASSWORD=$HOLLAEX_SECRET_TECH_PASSWORD_OVERRIDE/" $SECRET_FILE_PATH

  rm $CONFIGMAP_FILE_PATH.bak
  rm $SECRET_FILE_PATH.bak

}

function save_coin_configs() {

  cat >> $CONFIGMAP_FILE_PATH << EOL

ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_SYMBOL=$COIN_SYMBOL
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_FULLNAME=$COIN_FULLNAME
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_ALLOW_DEPOSIT=$COIN_ALLOW_DEPOSIT
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_ALLOW_WITHDRAWAL=$COIN_ALLOW_WITHDRAWAL
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_WITHDRAWAL_FEE=$COIN_WITHDRAWAL_FEE
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_MIN=$COIN_MIN
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_MAX=$COIN_MAX
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_INCREMENT_UNIT=$COIN_INCREMENT_UNIT
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_DEPOSIT_LIMITS=$COIN_DEPOSIT_LIMITS_PARSED
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_WITHDRAWAL_LIMITS=$COIN_WITHDRAWAL_LIMITS_PARSED
ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_ACTIVE=$COIN_ACTIVE

EOL
}

function save_pairs_configs() {

  cat >> $CONFIGMAP_FILE_PATH << EOL

ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_PAIR_NAME=$PAIR_NAME
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

  if [[ "$CURRENT_HOLLAEX_KIT_VERSION" < "$HOLLAEX_KIT_MINIMUM_COMPATIBLE" ]] || [[ "$CURRENT_HOLLAEX_KIT_VERSION" > "$HOLLAEX_KIT_MAXIMUM_COMPATIBLE" ]]; then

    printf "\n\033[91mError: The HollaEx Kit version that you are trying to run is not compatible with the installed CLI.\033[39m\n"
    printf "Your HollaEx Kit version: \033[1m$CURRENT_HOLLAEX_KIT_VERSION\033[0m\n"
    printf "Supported HollaEx Kit version range: \033[1m$HOLLAEX_KIT_MINIMUM_COMPATIBLE ~ $HOLLAEX_KIT_MAXIMUM_COMPATIBLE.\033[0m\n"

    if [[ "$CURRENT_HOLLAEX_KIT_VERSION" > "$HOLLAEX_KIT_MAXIMUM_COMPATIBLE" ]]; then

      printf "\nYour Kit version is \033[1mhigher than the maximum compatible version\033[0m of your CLI.\n"
      printf "You can \033[1mreinstall the HollaEx CLI\033[0m to higher version.\n\n"
      printf "To reinstall the HollaEx CLI to a compatible version, Please run '\033[1mhollaex toolbox --install_cli <VERSION_NUMBER>\033[0m.\n"

    elif [[ "$CURRENT_HOLLAEX_KIT_VERSION" < "$HOLLAEX_KIT_MINIMUM_COMPATIBLE" ]]; then

      printf "\nYour Kit version is \033[1mlower than the minimum compatible version\033[0m of your CLI.\n"
      printf "\nYou can either \033[1mreinstall the HollaEx CLI, or upgrade your HollaEx Kit\033[0m.\n\n"
      printf "To reinstall the HollaEx CLI to a compatible version, Please run '\033[1mhollaex toolbox --install_cli <VERSION_NUMBER>\033[0m.\n"
      printf "To see how to upgrade your HollaEx Kit, Please \033[1mcheck our official upgrade docs (docs.bitholla.com/hollaex-kit/upgrade)\033[0m.\n"

    fi

    printf "\nYou can see the version compatibility range of between CLI and Kit at our \033[1mofficial docs (docs.bitholla.com/hollaex-kit/upgrade/version-compatibility)\033[0m.\n\n"

    exit 1;

  fi

}

function check_core_version_compatibility_range() {

  CURRENT_HOLLAEX_CORE_VERSION=$(echo $ENVIRONMENT_DOCKER_IMAGE_VERSION | cut -f1 -d "-")

  if [[ "$CURRENT_HOLLAEX_CORE_VERSION" < "$HOLLAEX_CORE_MINIMUM_COMPATIBLE" ]] || [[ "$CURRENT_HOLLAEX_CORE_VERSION" > "$HOLLAEX_CORE_MAXIMUM_COMPATIBLE" ]]; then

    printf "\n\033[91mError: The HollaEx Core version that you are trying to run is not compatible with the installed CLI.\033[39m\n"
    printf "Your HollaEx Core version: \033[1m$CURRENT_HOLLAEX_CORE_VERSION\033[0m\n"
    printf "Supported HollaEx Core version range: \033[1m$HOLLAEX_CORE_MINIMUM_COMPATIBLE ~ $HOLLAEX_CORE_MAXIMUM_COMPATIBLE.\033[0m\n"

    printf "\nPlease try it again after setting up the correct ranged version of Core.\033[0m.\n\n"

    exit 1;

  fi

}

function generate_backend_passwords() {

  echo "Generating random passwords for backends..."

  export HOLLAEX_SECRET_REDIS_PASSWORD=$(generate_random_values)
  export HOLLAEX_SECRET_DB_PASSWORD=$(generate_random_values)

  if command grep -q "HOLLAEX_SECRET_ACTIVATION_CODE" $i > /dev/null ; then

    SECRET_FILE_PATH=$i

    sed -i.bak "s/HOLLAEX_SECRET_REDIS_PASSWORD=.*/HOLLAEX_SECRET_REDIS_PASSWORD=$HOLLAEX_SECRET_REDIS_PASSWORD/" $SECRET_FILE_PATH
    sed -i.bak "s/HOLLAEX_SECRET_PUBSUB_PASSWORD=.*/HOLLAEX_SECRET_PUBSUB_PASSWORD=$HOLLAEX_SECRET_REDIS_PASSWORD/" $SECRET_FILE_PATH

    sed -i.bak "s/HOLLAEX_SECRET_DB_PASSWORD=.*/HOLLAEX_SECRET_DB_PASSWORD=$HOLLAEX_SECRET_DB_PASSWORD/" $SECRET_FILE_PATH

    rm $SECRET_FILE_PATH.bak
    
  fi


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

          printf "\033[92mHelm v2: Installed\033[39m\n"

      else 

          printf "\033[91mHelm v2: Not Installed\033[39m\n"

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
        https://$ENVIRONMENT_HOLLAEX_NETWORK_TARGET_SERVER/v2/dash/user/token)

  BITHOLLA_HMAC_TOKEN_ISSUE_POST_RESPOND=$(echo $BITHOLLA_HMAC_TOKEN_ISSUE_POST | cut -f1 -d "=")
  BITHOLLA_HMAC_TOKEN_ISSUE_POST_HTTP_CODE=$(echo $BITHOLLA_HMAC_TOKEN_ISSUE_POST | cut -f2 -d "=")

  if [[ ! "$BITHOLLA_HMAC_TOKEN_ISSUE_POST_HTTP_CODE" == "200" ]]; then

    echo -e "\nFailed to issue a security token!"

    echo -e "\nPlease check your internet connectivity, and try it again."
    echo -e "You could also check the bitHolla service status at https://status.bitholla.com."

    exit 1;

  fi 
  
  HOLLAEX_SECRET_API_KEY=$(echo $BITHOLLA_HMAC_TOKEN_ISSUE_POST_RESPOND | jq -r '.apiKey')
  HOLLAEX_SECRET_API_SECRET=$(echo $BITHOLLA_HMAC_TOKEN_ISSUE_POST_RESPOND | jq -r '.secret')

  echo -e "\n# # # # # Your Security Token # # # # #"
  echo -e "\033[1mYour API Key: $HOLLAEX_SECRET_API_KEY\033[0m"
  echo -e "\033[1mYour Secret Key: $HOLLAEX_SECRET_API_SECRET\033[0m"
  echo -e "# # # # # # # # # # # # # # # #\n"

  if command sed -i.bak "s/HOLLAEX_SECRET_API_KEY=.*/HOLLAEX_SECRET_API_KEY=$HOLLAEX_SECRET_API_KEY/" $SECRET_FILE_PATH && command sed -i.bak "s/HOLLAEX_SECRET_API_SECRET=.*/HOLLAEX_SECRET_API_SECRET=$HOLLAEX_SECRET_API_SECRET/" $SECRET_FILE_PATH; then

    echo -e "\033[92mSuccessfully stored the issued token to the settings file.\033[39m\n"

  else 

    echo -e "\n\033[91mFailed to store the issued token to the settings file.\033[39m\n"
    echo "Please make sure to manually save the issued token displayed above, and try the process again."
    
    exit 1;

  fi 

  rm -f $SECRET_FILE_PATH.bak

}

function get_hmac_token() {

  echo "Issueing a security token for the HollaEx Network communication..."
  
  BITHOLLA_HMAC_TOKEN_GET_COUNT=$(curl -s -H "Content-Type: application/json" -H "Authorization: Bearer $BITHOLLA_ACCOUNT_TOKEN"\
            --request GET \
            https://$ENVIRONMENT_HOLLAEX_NETWORK_TARGET_SERVER/v2/dash/user/token?active=true | jq '.count')
    
  if [[ ! $BITHOLLA_HMAC_TOKEN_GET_COUNT == "0" ]]; then 

    BITHOLLA_HMAC_TOKEN_EXISTING_APIKEY=$(curl -s -H "Content-Type: application/json" -H "Authorization: Bearer $BITHOLLA_ACCOUNT_TOKEN"\
            --request GET \
            https://$ENVIRONMENT_HOLLAEX_NETWORK_TARGET_SERVER/v2/dash/user/token?active=true | jq -r '.data[0].apiKey')
    
    BITHOLLA_HMAC_TOKEN_EXISTING_TOKEN_ID=$(curl -s -H "Content-Type: application/json" -H "Authorization: Bearer $BITHOLLA_ACCOUNT_TOKEN"\
            --request GET \
            https://$ENVIRONMENT_HOLLAEX_NETWORK_TARGET_SERVER/v2/dash/user/token?active=true | jq -r '.data[0].id')

    printf "\n\033[1mYou already have an active Token! (API Key: $BITHOLLA_HMAC_TOKEN_EXISTING_APIKEY)\033[0m\n\n"

    echo -e "You could \033[1mprovide the existing token manually\033[0m on the further menu."
    echo -e "If you dont have an existing token, \033[1myou could also revoke the token at the https://dash.bitholla.com.\033[0m\n"

    echo -e "Please \033[1mtype 'Y', if you have an existing token and ready to type.\033[0m"
    echo -e "Please \033[1mtype 'N', if you want to revoke and issue a new token.\033[0m\n"

    echo -e "\033[1mDo you want to continue with the exisitng token manually? (Y/n)\033[0m"

    read tokenAnswer

    if [[ "$tokenAnswer" = "${tokenAnswer#[Yy]}" ]]; then

      echo -e "\nIf you dont have an existing token with you, you could \033[1mrevoke and reissue it.\033[0m"
      echo -e "\n\033[1mRevoking the token can't be undo and would bring down the existing exchange running with the revoked token.\033[0m"
      echo -e "Please \033[1mmake sure that you are not running the exchange already.\033[0m"
      echo -e "\nDo you want to \033[1mproceed to revoke\033[0m the existing token? (API Key: $BITHOLLA_HMAC_TOKEN_EXISTING_APIKEY) (y/N)"

      read answer

      if [[ "$answer" = "${answer#[Yy]}" ]] ;then

        echo -e "\n\033[91mA security token is must required to setup an HollaEx Exchange.\033[39m"
        echo -e "\nPlease \033[1mrun this command again once you becomes ready.\033[0m"
        echo -e "You could also revoke the token through the https://dash.bitholla.com."

        echo -e "\nSee you in a bit!\n"

        exit 1;

      fi

      echo -e "Revoking the exisitng token ($BITHOLLA_HMAC_TOKEN_EXISTING_APIKEY)..."

      # Revoking the security token through the bitHolla API.
      BITHOLLA_HMAC_TOKEN_REVOKE_CALL=$(curl -s -H "Content-Type: application/json" -H "Authorization: Bearer $BITHOLLA_ACCOUNT_TOKEN" -w " HTTP_CODE=%{http_code}" \
          --request DELETE \
          -d "{\"name\": \"kit\", \"token_id\": $BITHOLLA_HMAC_TOKEN_EXISTING_TOKEN_ID}" \
          https://$ENVIRONMENT_HOLLAEX_NETWORK_TARGET_SERVER/v2/dash/user/token)

      BITHOLLA_HMAC_TOKEN_REVOKE_CALL_RESPOND=$(echo $BITHOLLA_HMAC_TOKEN_REVOKE_CALL | cut -f1 -d "=")
      BITHOLLA_HMAC_TOKEN_REVOKE_CALL_HTTP_CODE=$(echo $BITHOLLA_HMAC_TOKEN_REVOKE_CALL | cut -f2 -d "=")

      if [[ ! "$BITHOLLA_HMAC_TOKEN_REVOKE_CALL_HTTP_CODE" == "200" ]]; then 

        echo -e "\033[91mFailed to revoke the security token!\033[39m"
        echo -e "\nPlease check the error logs and try it again."
        echo -e "You could also revoke the token through the https://dash.bitholla.com.\n"

        exit 1;

      fi 

      echo -e "\n\033[92mSuccessfully revoked the security token!\033[39m"

      echo -e "\n\033[1mProceeding to reissue it...\033[0m"
      issue_new_hmac_token;

    else

      function existing_token_form() {

        echo -e "\033[1mYour existing API Key: \033[0m"
        read answer 
        HOLLAEX_SECRET_API_KEY=$answer

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

          echo -e "\n\033[92mSuccessfully stored the provided token to the settings file.\033[39m\n"

        else 

          echo -e "\n\033[91mFailed to store the issued token to the settings file.\033[39m\n"
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

        # Check that settings files are already configured.
        if [[ ! "$HOLLAEX_CONFIGMAP_API_NAME" == "my-hollaex-exchange" ]] && [[ $HOLLAEX_SECRET_ACTIVATION_CODE ]] && [[ $HOLLAEX_SECRET_API_KEY ]] && [[ $HOLLAEX_SECRET_API_SECRET ]]; then

            echo "HollaEx CLI detected the preconfigured values on your HollaEx Kit."
            echo "Do you want to proceed with these preconfigured values? (Y/n)"
            read answer

            if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
                
                export CONTINUE_WITH_PRECONFIGURED_VALUES=false
            
            else 

                export CONTINUE_WITH_PRECONFIGURED_VALUES=true

            fi

        fi
    
    else 

        echo "Proceeding with the preconfigured values..."
        export CONTINUE_WITH_PRECONFIGURED_VALUES=true

    fi

    if [[ "$CONTINUE_WITH_PRECONFIGURED_VALUES" == false ]]; then

        printf "\nWelcome to HollaEx Setup!\n\n"

        echo -e "You need to \033[1msetup your exchange\033[0m with the configurations."
        echo -e "You can follow the \033[1mexchange setup wizard\033[0m on \033[1mhttps://dash.bitholla.com\033[0m before you do this process. (Recommended)"
        echo -e "\033[1mHave you already setup your exchange on bitHolla Dashboard? (Y/n)\033[0m"
        read answer

        if [[ ! "$answer" = "${answer#[Nn]}" ]]; then

            printf "\nWe recommend you to setup your exchange on \033[1mbitHolla dashboard (dash.bitholla.com)\033[0m before you proceed.\n"
            printf "Select \033[1m'Y'\033[0m to \033[1mquit the CLI\033[0m in order to first setup your exchange on the dashboard,\n" 
            printf "Select \033[1m'N'\033[0m to proceed \033[1mmanual\033[0m CLI exchange setup wizard.\n" 
            echo "Do you want to quit the CLI setup? (Y/n)"
            read answer

            if [[ ! "$answer" = "${answer#[Nn]}" ]]; then
                
                echo "Proceeding to a CLI exchange wizard..."
                launch_basic_settings_input;
            
            else 

                printf "\n\nPlease visit \033[1mdash.bitholla.com\033[0m and setup your exchange there first.\n"
                printf "Once your exchange is configured on the dashboard, please start the procedure by using \033[1m'hollaex setup'\033[0m.\n\n"
                exit 1;
            
            fi
        
        else 

            if ! command hollaex login; then

                exit 1;

            fi

            if ! command hollaex pull --skip; then

                exit 1;

            fi

        fi
    
    fi

}
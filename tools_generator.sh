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

      echo "Running InfluxDB migrations"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/createInflux.js
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/migrateInflux.js
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/initializeInflux.js

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

      echo "Running InfluxDB initialization"
      docker exec ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX}_1 node tools/dbs/initializeInflux.js

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

    echo "Running InfluxDB migrations"
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/createInflux.js
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/migrateInflux.js
    kubectl exec --namespace $ENVIRONMENT_EXCHANGE_NAME $(kubectl get pod --namespace $ENVIRONMENT_EXCHANGE_NAME -l "app=$ENVIRONMENT_EXCHANGE_NAME-server-api" -o name | sed 's/pod\///' | head -n 1) -- node tools/dbs/initializeInflux.js

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

  HOLLAEX_SECRET_VARIABLES_BASE64=$(for value in ${HOLLAEX_SECRET_VARIABLES} 
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
  upstream plugins-controller {
    server ${ENVIRONMENT_EXCHANGE_NAME}-server-plugins-controller:10011;
  }
EOL

  fi

done


# #Upstream generator for dev environments
# if [[ "$IS_DEVELOP" ]]; then

#  # Generate local nginx conf
#   cat > $TEMPLATE_GENERATE_PATH/local/nginx/conf.d/upstream.conf <<EOL
#   upstream api {
#     server ${ENVIRONMENT_EXCHANGE_NAME}-server:10010;
#   }
#   upstream socket {
#     ip_hash;
#     server ${ENVIRONMENT_EXCHANGE_NAME}-server:10080;
#   }
#   upstream plugins-controller {
#     server ${ENVIRONMENT_EXCHANGE_NAME}-server:10011;
#   }
# EOL

# fi

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
    image: ${ENVIRONMENT_DOCKER_IMAGE_INFLUXDB_REGISTRY:-influxdb}:${ENVIRONMENT_DOCKER_IMAGE_INFLUXDB_VERSION:-1.7-alpine}
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

  ${ENVIRONMENT_EXCHANGE_NAME}-influxdb:
    image: ${ENVIRONMENT_DOCKER_IMAGE_INFLUXDB_REGISTRY:-influxdb}:${ENVIRONMENT_DOCKER_IMAGE_INFLUXDB_VERSION:-1.7-alpine}
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
    entrypoint:
      - /app/api-binary
    volumes:
      - ${HOLLAEX_CLI_INIT_PATH}/db/migrations:/app/db/migrations
      - ${HOLLAEX_CLI_INIT_PATH}/db/models:/app/db/models
      - ${HOLLAEX_CLI_INIT_PATH}/db/seeders:/app/db/seeders
      # - ${HOLLAEX_CLI_INIT_PATH}/mail:/app/mail
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
    entrypoint:
      - nodemon
      - plugins/index.js
    volumes:
      - ${HOLLAEX_CLI_INIT_PATH}/plugins:/app/plugins
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
    entrypoint:
      - /app/stream-binary
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
      - ${TEMPLATE_GENERATE_PATH}/local/${ENVIRONMENT_EXCHANGE_NAME}.env.local
    environment:
      - PAIR=${TRADE_PARIS_DEPLOYMENT}
    entrypoint:
      - /app/engine-binary
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

if [[ "$ENVIRONMENT_DOCKER_COMPOSE_RUN_INFLUXDB" == "true" ]]; then
  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL
  ${ENVIRONMENT_EXCHANGE_NAME}-influxdb:
    image: ${ENVIRONMENT_DOCKER_IMAGE_INFLUXDB_REGISTRY:-influxdb}:${ENVIRONMENT_DOCKER_IMAGE_INFLUXDB_VERSION:-1.7-alpine}
    restart: always
    ports:
      - 8086:8086
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    environment:
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

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

  ${ENVIRONMENT_EXCHANGE_NAME}-server-plugins-controller:
    image: $ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION
    restart: always
    ports:
      - 10011:10011
    entrypoint:
      - node
    command:
      - plugins/index.js
    env_file:
      - ${ENVIRONMENT_EXCHANGE_NAME}.env.local
    networks:
      - ${ENVIRONMENT_EXCHANGE_NAME}-network
EOL


#LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE=$ENVIRONMENT_EXCHANGE_RUN_MODE

IFS=',' read -ra LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE <<< "$ENVIRONMENT_EXCHANGE_RUN_MODE"

for i in ${LOCAL_DEPLOYMENT_MODE_DOCKER_COMPOSE_PARSE[@]}; do

  if [[ ! "$i" == "engine" ]]; then

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

  ${ENVIRONMENT_EXCHANGE_NAME}-server-${i}:
    image: $ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION
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

  if [[ "$i" == "engine" ]]; then

  IFS=',' read -ra PAIRS <<< "$HOLLAEX_CONFIGMAP_PAIRS"    #Convert string to array

  for j in "${PAIRS[@]}"; do
    TRADE_PARIS_DEPLOYMENT=$(echo $j | cut -f1 -d ",")

  # Generate docker-compose
  cat >> $TEMPLATE_GENERATE_PATH/local/${ENVIRONMENT_EXCHANGE_NAME}-docker-compose.yaml <<EOL

  ${ENVIRONMENT_EXCHANGE_NAME}-server-${i}-$TRADE_PARIS_DEPLOYMENT:
    image: $ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION
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
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
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

  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api-order
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
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
  
  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-api-admin
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
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

  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)

    
---

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-plugins-controller
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
spec:
  rules:
  - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
    http:
      paths:
      - path: /plugins
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-plugins-controller
          servicePort: 10011
    
  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${ENVIRONMENT_EXCHANGE_NAME}-ingress-stream
  namespace: ${ENVIRONMENT_EXCHANGE_NAME}
  annotations:
    kubernetes.io/ingress.class: "nginx"
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo 'kubernetes.io/tls-acme: "true"';  fi)
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
    nginx.ingress.kubernetes.io/proxy-body-size: "2m"
    nginx.org/websocket-services: "${ENVIRONMENT_EXCHANGE_NAME}-server-stream"
    nginx.ingress.kubernetes.io/upstream-hash-by: '$binary_remote_addr'
spec:
  rules:
  - host: $(echo ${HOLLAEX_CONFIGMAP_API_HOST} | cut -f3 -d "/")
    http:
      paths:
      - path: /socket.io
        backend:
          serviceName: ${ENVIRONMENT_EXCHANGE_NAME}-server-stream
          servicePort: 10080
  
  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then ingress_tls_snippets $HOLLAEX_CONFIGMAP_API_HOST; fi)

EOL

}

function generate_kubernetes_ingress_for_web() { 

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
    $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then echo "cert-manager.io/cluster-issuer: ${ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER}";  fi)
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
  
  $(if [[ "$ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER" ]];then ingress_web_tls_snippets $HOLLAEX_CONFIGMAP_DOMAIN; fi)

EOL

}

function generate_random_values() {

  # Runs random.js through docker with latest compatible hollaex core (minimum 1.23.0)
  docker run --rm --entrypoint node bitholla/hollaex-core:${HOLLAEX_CORE_MAXIMUM_COMPATIBLE:-1.23.0} tools/general/random.js
  
}

function update_random_values_to_config() {


GENERATE_VALUES_LIST=( "HOLLAEX_SECRET_SUPERVISOR_PASSWORD" "HOLLAEX_SECRET_SUPPORT_PASSWORD" "HOLLAEX_SECRET_KYC_PASSWORD" "HOLLAEX_SECRET_QUICK_TRADE_SECRET" "HOLLAEX_SECRET_SECRET" )

for j in ${CONFIG_FILE_PATH[@]}; do

  if command grep -q "HOLLAEX_SECRET" $j > /dev/null ; then

    SECRET_CONFIG_FILE_PATH=$j

    # if [[ ! -z "$HOLLAEX_SECRET_SECRET" ]] ; then
  
    #   echo "Pre-generated secrets are detected on your secret file!"
    #   printf "\033[93mIf you are trying to migrate your existing Exchange on new machine, DO NOT OVERRIDE IT.\033[39m\n"
    #   echo "Are you sure you want to override them? (y/N)"

    #   read answer

    #   if [[ "$answer" = "${answer#[Yy]}" ]] ;then

    #     echo "Skipping..."
    #     return 0

    #   fi

    # fi  

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
                   --recreate-pods \
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
                   -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server

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

  for i in ${HOLLAEX_CONFIGMAP_VARIABLES[@]}; do

    PARSED_CONFIGMAP_VARIABLES=$(echo $i | cut -f2 -d '=')

    if [[ -z $PARSED_CONFIGMAP_VARIABLES ]]; then

      printf "\033[94mInfo: Configmap - \"$(echo $i | cut -f1 -d '=')\" got an empty value! Please reconfirm the settings files.\033[39m\n"

    fi
  
  done

  GENERATE_VALUES_LIST=( "ADMIN_PASSWORD" "SUPERVISOR_PASSWORD" "SUPPORT_PASSWORD" "KYC_PASSWORD" "QUICK_TRADE_SECRET" "SECRET" )

  for i in ${HOLLAEX_SECRET_VARIABLES[@]}; do

    PARSED_SECRET_VARIABLES=$(echo $i | cut -f2 -d '=')

    if [[ -z $PARSED_SECRET_VARIABLES ]]; then

      printf "\033[94mInfo: Secret - \"$(echo $i | cut -f1 -d '=')\" got an empty value! Please reconfirm the settings files.\033[39m\n"

      for k in "${GENERATE_VALUES_LIST[@]}"; do

          GENERATE_VALUES_FILTER=$(echo $i | cut -f1 -d '=')

          if [[ "$k" == "${GENERATE_VALUES_FILTER}" ]] ; then

              echo -n "\"$k\" is a value should be automatically generated by HollaEx CLI."
              printf "\n"

          fi

      done

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

function add_coin_input() {

  echo "***************************************************************"
  echo "[1/11] Coin Symbol: (eth)"
  printf "\033[2m- This trading symbol is a short hand for this coin.\033[22m\n" 
  read answer

  COIN_SYMBOL=${answer:-eth}

  printf "\n"
  echo "${answer:-eth} ✔"
  printf "\n"

  for i in ${CONFIG_FILE_PATH[@]}; do

    if command grep -q "ENVIRONMENT_ADD_COIN_$(echo $COIN_SYMBOL | tr a-z A-Z)_" $i > /dev/null ; then

      printf "\033[92mDetected configurations for coin $COIN_SYMBOL in your settings file.\033[39m\n"
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

  # Checking user level setup on settings file is set or not
  if [[ ! "$HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER" ]]; then

    printf "\033[93mWarning: Settings value - HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER is not configured. Please confirm your settings files.\033[39m\n"
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
  for i in $(seq 1 $HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER);

    do echo "***************************************************************"
       echo "[9/11] Deposit limit of user level $i: (0)"
       printf "\033[2m- Set the coins deposit limit amount for the user level $i. Set zero (0) for no limits. \033[22m\n"
       read answer
       export DEPOSIT_LIMITS_LEVEL_$i=${answer:-0}
       printf "\n"
       echo "${answer:-1} ✔"
       printf "\n"
  
  done;

  local PARSE_RANGE_DEPOSIT_LIMITS_LEVEL=$(set -o posix ; set | grep "DEPOSIT_LIMITS_LEVEL_" | cut -c22 )
  local PARSE_VALUE_DEPOSIT_LIMITS_LEVEL=$(set -o posix ; set | grep "DEPOSIT_LIMITS_LEVEL_" | cut -f2 -d "=" )

  read -ra RANGE_DEPOSIT_LIMITS_LEVEL <<< ${PARSE_RANGE_DEPOSIT_LIMITS_LEVEL[@]}
  read -ra VALUE_DEPOSIT_LIMITS_LEVEL <<< ${PARSE_VALUE_DEPOSIT_LIMITS_LEVEL[@]}

  COIN_DEPOSIT_LIMITS=$(join_array_to_json $(print_deposit_array_side_by_side))

  # Asking withdrawal limit of new coin per level
  for i in $(seq 1 $HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER);

    do echo "***************************************************************"
       echo "[10/11] Withdrawal limit of user level $i: (0)"
       printf "\033[2m- Set the coins withdrawal limit amount for the user level $i. Set zero (0) for no limits. \033[22m\n"
       read answer
       export WITHDRAWAL_LIMITS_LEVEL_$i=${answer:-0}
       printf "\n"
       echo "${answer:-1} ✔"
       printf "\n"
  
  done;

  local PARSE_RANGE_WITHDRAWAL_LIMITS_LEVEL=$(set -o posix ; set | grep "WITHDRAWAL_LIMITS_LEVEL_" | cut -c25 )
  local PARSE_VALUE_WITHDRAWAL_LIMITS_LEVEL=$(set -o posix ; set | grep "WITHDRAWAL_LIMITS_LEVEL_" | cut -f2 -d "=" )

  read -ra RANGE_WITHDRAWAL_LIMITS_LEVEL <<< ${PARSE_RANGE_WITHDRAWAL_LIMITS_LEVEL[@]}
  read -ra VALUE_WITHDRAWAL_LIMITS_LEVEL <<< ${PARSE_VALUE_WITHDRAWAL_LIMITS_LEVEL[@]}

  COIN_WITHDRAWAL_LIMITS=$(join_array_to_json $(print_withdrawal_array_side_by_side))

  echo "***************************************************************"
  echo "[11/11] Activate Coin: (Y/n)"
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
  echo "Symbol: $COIN_SYMBOL"
  echo "Full name: $COIN_FULLNAME"
  echo "Allow deposit: $COIN_ALLOW_DEPOSIT"
  echo "Allow withdrawal: $COIN_ALLOW_WITHDRAWAL"
  echo "Withdrawal Fee: $COIN_WITHDRAWAL_FEE"
  echo "Minimum Withdrawal Amount: $COIN_MIN"
  echo "Maximum Withdrawal Amount: $COIN_MAX"
  echo "Increment size: $COIN_INCREMENT_UNIT"
  echo "Deposit limits per level: $COIN_DEPOSIT_LIMITS"
  echo "Withdrawal limits per level: $COIN_WITHDRAWAL_LIMITS"
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

  local COIN_PREFIX=$(echo $COIN_SYMBOL | tr a-z A-Z)

  local COIN_DEPOSIT_LIMITS_PARSED=$(echo ${COIN_DEPOSIT_LIMITS//\"/\\\"})
  local COIN_WITHDRAWAL_LIMITS_PARSED=$(echo ${COIN_WITHDRAWAL_LIMITS//\"/\\\"})

  # REMOVE STORED VALUES AT CONFIGMAP FOR COIN 
  if [[ ! "$VALUE_IMPORTED_FROM_CONFIGMAP" ]]; then 
  
    remove_existing_coin_configs_from_settings;

  fi

  save_coin_configs;

}

function export_add_coin_configuration_env() {

  COIN_SYMBOL_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_SYMBOL
  COIN_FULLNAME_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_FULLNAME
  COIN_ALLOW_DEPOSIT_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_ALLOW_DEPOSIT
  COIN_ALLOW_WITHDRAWAL_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_ALLOW_WITHDRAWAL
  COIN_WITHDRAWAL_FEE_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_WITHDRAWAL_FEE
  COIN_MIN_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_MIN
  COIN_MAX_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_MAX
  COIN_INCREMENT_UNIT_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_INCREMENT_UNIT
  COIN_DEPOSIT_LIMITS_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_DEPOSIT_LIMITS
  COIN_WITHDRAWAL_LIMITS_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_WITHDRAWAL_LIMITS
  COIN_ACTIVE_OVERRIDE=ENVIRONMENT_ADD_COIN_${COIN_PREFIX}_COIN_ACTIVE

  if [[ "$VALUE_IMPORTED_FROM_CONFIGMAP" ]]; then

    export COIN_SYMBOL_OVERRIDE=$(echo ${COIN_SYMBOL_OVERRIDE})
    export COIN_FULLNAME_OVERRIDE=$(echo ${COIN_FULLNAME_OVERRIDE})
    export COIN_ALLOW_DEPOSIT_OVERRIDE=$(echo ${COIN_ALLOW_DEPOSIT_OVERRIDE})
    export COIN_ALLOW_WITHDRAWAL_OVERRIDE=$(echo ${COIN_ALLOW_WITHDRAWAL_OVERRIDE})
    export COIN_WITHDRAWAL_FEE_OVERRIDE=$(echo ${COIN_WITHDRAWAL_FEE_OVERRIDE})
    export COIN_MIN_OVERRIDE=$(echo ${COIN_MIN_OVERRIDE})
    export COIN_MAX_OVERRIDE=$(echo ${COIN_MAX_OVERRIDE})
    export COIN_INCREMENT_UNIT_OVERRIDE=$(echo ${COIN_INCREMENT_UNIT_OVERRIDE})
    export COIN_DEPOSIT_LIMITS_OVERRIDE=$(echo ${COIN_DEPOSIT_LIMITS_OVERRIDE})
    export COIN_WITHDRAWAL_LIMITS_OVERRIDE=$(echo ${COIN_WITHDRAWAL_LIMITS_OVERRIDE})
    export COIN_ACTIVE_OVERRIDE=$(echo ${COIN_ACTIVE_OVERRIDE})

    # if [[ ! "$COIN_DEPOSIT_LIMITS_OVERRIDE" == *"\""* ]] &&  [[ ! "$COIN_WITHDRAWAL_LIMITS_OVERRIDE" == *"\""* ]]; then

    #   COIN_DEPOSIT_LIMITS_OVERRIDE=$(echo ${!COIN_DEPOSIT_LIMITS_OVERRIDE}) #| awk '{ gsub(/"/,"\\\"") } 1')
    #   COIN_WITHDRAWAL_LIMITS_OVERRIDE=$(echo ${!COIN_WITHDRAWAL_LIMITS_OVERRIDE}) #| awk '{ gsub(/"/,"\\\"") } 1')

    #   echo $COIN_DEPOSIT_LIMITS_OVERRIDE
    #   echo $COIN_WITHDRAWAL_LIMITS_OVERRIDE

    # fi

  else 

    export $(echo $COIN_SYMBOL_OVERRIDE)=$COIN_SYMBOL
    export $(echo $COIN_FULLNAME_OVERRIDE)=$COIN_FULLNAME
    export $(echo $COIN_ALLOW_DEPOSIT_OVERRIDE)=$COIN_ALLOW_DEPOSIT
    export $(echo $COIN_ALLOW_WITHDRAWAL_OVERRIDE)=$COIN_ALLOW_WITHDRAWAL
    export $(echo $COIN_WITHDRAWAL_FEE_OVERRIDE)=$COIN_WITHDRAWAL_FEE
    export $(echo $COIN_MIN_OVERRIDE)=$COIN_MIN
    export $(echo $COIN_MAX_OVERRIDE)=$COIN_MAX
    export $(echo $COIN_INCREMENT_UNIT_OVERRIDE)=$COIN_INCREMENT_UNIT
    export $(echo $COIN_DEPOSIT_LIMITS_OVERRIDE)=$COIN_DEPOSIT_LIMITS
    export $(echo $COIN_WITHDRAWAL_LIMITS_OVERRIDE)=$COIN_WITHDRAWAL_LIMITS
    export $(echo $COIN_ACTIVE_OVERRIDE)=$COIN_ACTIVE
  
  fi

}


function add_coin_exec() {

  local COIN_PREFIX=$(echo $COIN_SYMBOL | tr a-z A-Z)

  export_add_coin_configuration_env;

  if [[ "$USE_KUBERNETES" ]]; then

    function generate_kubernetes_add_coin_values() {

    # Generate Kubernetes Configmap
    cat > $TEMPLATE_GENERATE_PATH/kubernetes/config/add-coin.yaml <<EOL
job:
  enable: true
  mode: add_coin
  env:
    coin_symbol: $(echo ${!COIN_SYMBOL_OVERRIDE})
    coin_fullname: $(echo ${!COIN_FULLNAME_OVERRIDE})
    coin_allow_deposit: $(echo ${!COIN_ALLOW_DEPOSIT_OVERRIDE})
    coin_allow_withdrawal: $(echo ${!COIN_ALLOW_WITHDRAWAL_OVERRIDE})
    coin_withdrawal_fee: $(echo ${!COIN_WITHDRAWAL_FEE_OVERRIDE})
    coin_min: $(echo ${!COIN_MIN_OVERRIDE})
    coin_max: $(echo ${!COIN_MAX_OVERRIDE})
    coin_increment_unit: $(echo ${!COIN_INCREMENT_UNIT_OVERRIDE})
    coin_deposit_limits: '$(echo ${!COIN_DEPOSIT_LIMITS_OVERRIDE})'
    coin_withdrawal_limits: '$(echo ${!COIN_WITHDRAWAL_LIMITS_OVERRIDE})'
    coin_active: $(echo ${!COIN_ACTIVE_OVERRIDE})
EOL

    }

    generate_kubernetes_add_coin_values;

    # Only tries to attempt remove ingress rules from Kubernetes if it exists.
    # if ! command kubectl get ingress -n $ENVIRONMENT_EXCHANGE_NAME > /dev/null; then
    
    #     echo "Removing $HOLLAEX_CONFIGMAP_API_NAME ingress rule on the cluster."
    #     kubectl delete -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    # fi

    echo "Adding new coin $COIN_SYMBOL on Kubernetes"
    
    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL \
                            --namespace $ENVIRONMENT_EXCHANGE_NAME \
                            --set job.enable="true" \
                            --set job.mode="add_coin" \
                            --set DEPLOYMENT_MODE="api" \
                            --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                            --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                            --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                            --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                            -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml \
                            -f $TEMPLATE_GENERATE_PATH/kubernetes/config/add-coin.yaml \
                            $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server; then

      echo "Kubernetes Job has been created for adding new coin $COIN_SYMBOL."

      echo "Waiting until Job get completely run"
      sleep 30;

    else 

      printf "\033[91mFailed to create Kubernetes Job for adding new coin $COIN_SYMBOL, Please confirm your input values and try again.\033[39m\n"
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL

      # echo "Allowing exchange external connections"
      # kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL --namespace $ENVIRONMENT_EXCHANGE_NAME -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Coin $COIN_SYMBOL has been successfully added on your exchange!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL

      echo "Removing created Kubernetes Job for adding new coin..."
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL

      echo "Updating settings file to add new $COIN_SYMBOL."
      for i in ${CONFIG_FILE_PATH[@]}; do

        if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then

            CONFIGMAP_FILE_PATH=$i
            
            if ! command grep -q "HOLLAEX_CONFIGMAP_CURRENCIES.*${COIN_SYMBOL}.*" $i ; then

              HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE="${HOLLAEX_CONFIGMAP_CURRENCIES},${COIN_SYMBOL}"
              sed -i.bak "s/$HOLLAEX_CONFIGMAP_CURRENCIES/$HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE/" $CONFIGMAP_FILE_PATH
              rm $CONFIGMAP_FILE_PATH.bak

            else

              HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE=$HOLLAEX_CONFIGMAP_CURRENCIES
                
            fi

        fi

      done

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
        kubernetes_database_init upgrade;

      fi

      hollaex_ascii_coin_has_been_added;

    else

      printf "\033[91mFailed to add coin $COIN_SYMBOL! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-coin-$COIN_SYMBOL

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

      echo "Adding new coin $(echo ${!COIN_SYMBOL_OVERRIDE}) on local exchange"
      if command docker exec --env "COIN_FULLNAME=$(echo ${!COIN_FULLNAME_OVERRIDE})" \
                  --env "COIN_SYMBOL=$(echo ${!COIN_SYMBOL_OVERRIDE})" \
                  --env "COIN_ALLOW_DEPOSIT=$(echo ${!COIN_ALLOW_DEPOSIT_OVERRIDE})" \
                  --env "COIN_ALLOW_WITHDRAWAL=$(echo ${!COIN_ALLOW_WITHDRAWAL_OVERRIDE})" \
                  --env "COIN_WITHDRAWAL_FEE=$(echo ${!COIN_WITHDRAWAL_FEE_OVERRIDE})" \
                  --env "COIN_MIN=$(echo ${!COIN_MIN_OVERRIDE})" \
                  --env "COIN_MAX=$(echo ${!COIN_MAX_OVERRIDE})" \
                  --env "COIN_INCREMENT_UNIT=$(echo ${!COIN_INCREMENT_UNIT_OVERRIDE})" \
                  --env "COIN_DEPOSIT_LIMITS=$(echo ${!COIN_DEPOSIT_LIMITS_OVERRIDE})" \
                  --env "COIN_WITHDRAWAL_LIMITS=$(echo ${!COIN_WITHDRAWAL_LIMITS_OVERRIDE})" \
                  --env "COIN_ACTIVE=$(echo ${!COIN_ACTIVE_OVERRIDE})"  \
                  ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                  node tools/dbs/addCoin.js; then

         echo "Updating configmap file to add new $COIN_SYMBOL."
         for i in ${CONFIG_FILE_PATH[@]}; do

            if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then

              CONFIGMAP_FILE_PATH=$i
              
              if ! command grep -q "HOLLAEX_CONFIGMAP_CURRENCIES.*${COIN_SYMBOL}.*" $i ; then

                HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE="${HOLLAEX_CONFIGMAP_CURRENCIES},${COIN_SYMBOL}"
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

        printf "\033[91mFailed to add new coin $COIN_SYMBOL on local exchange. Please confirm your input values and try again.\033[39m\n"

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

  export COIN_SYMBOL=$answer

  printf "\n"
  echo "${answer:-$COIN_SYMBOL} ✔"
  printf "\n"

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

  if [[ $(echo ${HOLLAEX_CONFIGMAP_PAIRS} | grep $COIN_SYMBOL) ]]; then

    printf "\n\033[91mError: You can't remove coin $COIN_SYMBOL which already being used by trading pair.\033[39m\n"
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

  echo "Removing existing coin $COIN_SYMBOL on Kubernetes"
    
    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set job.enable="true" \
                --set job.mode="remove_coin" \
                --set job.env.coin_symbol="$COIN_SYMBOL" \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server; then

      echo "Kubernetes Job has been created for removing existing coin $COIN_SYMBOL."

      echo "Waiting until Job get completely run"
      sleep 30;

    else 

      printf "\033[91mFailed to create Kubernetes Job for removing existing coin $COIN_SYMBOL, Please confirm your input values and try again.\033[39m\n"
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL

      echo "Allowing exchange external connections"
      kubectl apply -f $TEMPLATE_GENERATE_PATH/kubernetes/config/$ENVIRONMENT_EXCHANGE_NAME-ingress.yaml

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL \
            --namespace $ENVIRONMENT_EXCHANGE_NAME \
            -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Coin $COIN_SYMBOL has been successfully removed on your exchange!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL

      echo "Removing created Kubernetes Job for removing existing coin..."
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL

      echo "Updating settings file to remove $COIN_SYMBOL."
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          if [[ "$COIN_SYMBOL" == "hex" ]]; then
            HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HOLLAEX_CONFIGMAP_CURRENCIES//$COIN_SYMBOL,}")
          else
            HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HOLLAEX_CONFIGMAP_CURRENCIES//,$COIN_SYMBOL}")
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

      echo "Coin $COIN_SYMBOL has been successfully removed."
      echo "Please run 'hollaex restart --kube' to apply it."

    else

      printf "\033[91mFailed to remove existing coin $COIN_SYMBOL! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-coin-$COIN_SYMBOL

    fi

  elif [[ ! "$USE_KUBERNETES" ]]; then

      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

      # # Overriding container prefix for develop server
      # if [[ "$IS_DEVELOP" ]]; then
        
      #   CONTAINER_PREFIX=

      # fi

      # echo "Shutting down Nginx to block exchange external access"
      # docker stop $(docker ps -a | grep $ENVIRONMENT_EXCHANGE_NAME-nginx | cut -f1 -d " ")

    echo "Removing new coin $COIN_SYMBOL on local docker"
    if command docker exec --env "COIN_SYMBOL=${COIN_SYMBOL}" \
                ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                node tools/dbs/removeCoin.js; then

      echo "Updating settings file to remove $COIN_SYMBOL."
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          IFS="," read -ra CURRENCIES_TO_ARRAY <<< "${HOLLAEX_CONFIGMAP_CURRENCIES}"

          local REVOME_SELECTED_CURRENCY=${CURRENCIES_TO_ARRAY[@]/$COIN_SYMBOL}
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

      echo "Coin $COIN_SYMBOL has been successfully removed."
      echo "Please run 'hollaex restart' to apply it."

    else

        printf "\033[91mFailed to remove coin $COIN_SYMBOL on local exchange. Please confirm your input values and try again.\033[39m\n"
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

  PAIR_NAME=${answer:-eth-usdt}
  PAIR_BASE=$(echo $PAIR_NAME | cut -f1 -d '-')
  PAIR_2=$(echo $PAIR_NAME | cut -f2 -d '-')

  printf "\n"
  echo "${answer:-eth-usdt} ✔"
  printf "\n"

  for i in ${CONFIG_FILE_PATH[@]}; do

    if command grep -q "ENVIRONMENT_ADD_PAIR_$(echo $PAIR_BASE | tr a-z A-Z)_$(echo $PAIR_2 | tr a-z A-Z)_" $i > /dev/null ; then

      printf "\033[92mDetected configurations for trading pair $PAIR_NAME in your settings file.\033[39m\n"
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

  # Checking user level setup on settings file is set or not
  if [[ ! "$HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER" ]]; then

    printf "\033[93mWarning: Settings value - HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER is not configured. Please confirm your settings files.\033[39m\n"
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
  for i in $(seq 1 $HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER);

    do echo "***************************************************************"
       echo "[2/10] Taker fee of user level $i? (0)"
       echo "- As Percentage %, Number only. Set zero (0) for no limits." 
       read answer
       printf "\n"
       echo "${answer:-0} ✔"
       printf "\n"
       export TAKER_FEES_LEVEL_$i=${answer:-0}
  
  done;

  local PARSE_RANGE_TAKER_FEES_LEVEL=$(set -o posix ; set | grep "TAKER_FEES_LEVEL_" | cut -c18 )
  local PARSE_VALUE_TAKER_FEES_LEVEL=$(set -o posix ; set | grep "TAKER_FEES_LEVEL_" | cut -f2 -d "=" )

  read -ra RANGE_TAKER_FEES_LEVEL <<< ${PARSE_RANGE_TAKER_FEES_LEVEL[@]}
  read -ra VALUE_TAKER_FEES_LEVEL <<< ${PARSE_VALUE_TAKER_FEES_LEVEL[@]}

  TAKER_FEES=$(join_array_to_json $(print_taker_fees_array_side_by_side))

  # Asking withdrawal limit of new coin per level
  for i in $(seq 1 $HOLLAEX_CONFIGMAP_USER_LEVEL_NUMBER);
    do echo "***************************************************************"
       echo "[3/10] Maker fee of user level $i? (0)"
       echo "- As Percentage %, Number only. Set zero (0) for no limits."
       read answer
       printf "\n"
       echo "${answer:-0} ✔"
       printf "\n"
       export MAKER_FEES_LEVEL_$i=${answer:-0}
  
  done;

  local PARSE_RANGE_MAKER_FEES_LEVEL=$(set -o posix ; set | grep "MAKER_FEES_LEVEL_" | cut -c18 )
  local PARSE_VALUE_MAKER_FEES_LEVEL=$(set -o posix ; set | grep "MAKER_FEES_LEVEL_" | cut -f2 -d "=" )

  read -ra RANGE_MAKER_FEES_LEVEL <<< ${PARSE_RANGE_MAKER_FEES_LEVEL[@]}
  read -ra VALUE_MAKER_FEES_LEVEL <<< ${PARSE_VALUE_MAKER_FEES_LEVEL[@]}

  MAKER_FEES=$(join_array_to_json $(print_maker_fees_array_side_by_side))

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

  function print_taker_fees_deposit_level(){ 

    for i in $(set -o posix ; set | grep "TAKER_FEES_LEVEL_");

      do printf "$i"

    done;

  }

  function print_maker_fees_withdrawal_level(){ 

    for i in $(set -o posix ; set | grep "MAKER_FEES_LEVEL_");

      do printf "$i"

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

  local TAKER_FEES_PARSED=$(echo ${TAKER_FEES//\"/\\\"})
  local MAKER_FEES_PARSED=$(echo ${MAKER_FEES//\"/\\\"})

   # REMOVE STORED VALUES AT CONFIGMAP FOR COIN 
  if [[ ! "$VALUE_IMPORTED_FROM_CONFIGMAP" ]]; then 
  
    remove_existing_pairs_configs_from_settings;

  fi

  save_pairs_configs;

}


function export_add_pair_configuration_env() {

  PAIR_NAME_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_PAIR_NAME
  PAIR_BASE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_PAIR_BASE
  PAIR_2_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_PAIR_2
  TAKER_FEES_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_TAKER_FEES
  MAKER_FEES_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_MAKER_FEES
  MIN_SIZE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_MIN_SIZE
  MAX_SIZE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_MAX_SIZE
  MIN_PRICE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_MIN_PRICE
  MAX_PRICE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_MAX_PRICE
  INCREMENT_SIZE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_INCREMENT_SIZE
  INCREMENT_PRICE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_INCREMENT_PRICE
  PAIR_ACTIVE_OVERRIDE=ENVIRONMENT_ADD_PAIR_${PAIR_PREFIX}_PAIR_ACTIVE


  if [[ "$VALUE_IMPORTED_FROM_CONFIGMAP" ]]; then

    PAIR_NAME_OVERRIDE=$(echo ${PAIR_NAME_OVERRIDE})
    PAIR_BASE_OVERRIDE=$(echo ${PAIR_BASE_OVERRIDE})
    PAIR_2_OVERRIDE=$(echo ${PAIR_2_OVERRIDE})
    TAKER_FEES_OVERRIDE=$(echo ${TAKER_FEES_OVERRIDE})
    MAKER_FEES_OVERRIDE=$(echo ${MAKER_FEES_OVERRIDE})
    MIN_SIZE_OVERRIDE=$(echo ${MIN_SIZE_OVERRIDE})
    MAX_SIZE_OVERRIDE=$(echo ${MAX_SIZE_OVERRIDE})
    MIN_PRICE_OVERRIDE=$(echo ${MIN_PRICE_OVERRIDE})
    MAX_PRICE_OVERRIDE=$(echo ${MAX_PRICE_OVERRIDE})
    INCREMENT_SIZE_OVERRIDE=$(echo ${INCREMENT_SIZE_OVERRIDE})
    INCREMENT_PRICE_OVERRIDE=$(echo ${INCREMENT_PRICE_OVERRIDE})
    PAIR_ACTIVE_OVERRIDE=$(echo ${PAIR_ACTIVE_OVERRIDE})

  else 

    export $(echo $PAIR_NAME_OVERRIDE)=$PAIR_NAME
    export $(echo $PAIR_BASE_OVERRIDE)=$PAIR_BASE
    export $(echo $PAIR_2_OVERRIDE)=$PAIR_2
    export $(echo $TAKER_FEES_OVERRIDE)=$TAKER_FEES
    export $(echo $MAKER_FEES_OVERRIDE)=$MAKER_FEES
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
    pair_name: $(echo ${!PAIR_NAME_OVERRIDE})
    pair_base: $(echo ${!PAIR_BASE_OVERRIDE})
    pair_2: $(echo ${!PAIR_2_OVERRIDE})
    taker_fees: '$(echo ${!TAKER_FEES_OVERRIDE})'
    maker_fees: '$(echo ${!MAKER_FEES_OVERRIDE})'
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

    echo "Adding new pair $PAIR_NAME on Kubernetes"
    
    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set job.enable="true" \
                --set job.mode="add_pair" \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/add-pair.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server; then

      echo "Kubernetes Job has been created for adding new pair $PAIR_NAME."

      echo "Waiting until Job get completely run"
      sleep 30;

    else 

      printf "\033[91mFailed to create Kubernetes Job for adding new pair $PAIR_NAME, Please confirm your input values and try again.\033[39m\n"
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME \
            --namespace $ENVIRONMENT_EXCHANGE_NAME \
            -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "Pair $PAIR_NAME has been successfully added on your exchange!"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME

      echo "Removing created Kubernetes Job for adding new coin..."
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME

      echo "Updating settings file to add new $PAIR_NAME."
      for i in ${CONFIG_FILE_PATH[@]}; do

     if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          
          CONFIGMAP_FILE_PATH=$i

          if ! command grep -q "HOLLAEX_CONFIGMAP_PAIRS=.*${PAIR_NAME}.*" $i ; then

            HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE="${HOLLAEX_CONFIGMAP_PAIRS},${PAIR_NAME}"
            sed -i.bak "s/$HOLLAEX_CONFIGMAP_PAIRS/$HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE/" $CONFIGMAP_FILE_PATH
            rm $CONFIGMAP_FILE_PATH.bak

          else

            HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE=$HOLLAEX_CONFIGMAP_PAIRS
            echo $HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE
          
          fi

      fi

      done

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
        kubernetes_database_init upgrade;
      
      fi

      # Run engine container (helm install) if it doesn't exists on the cluster.
      if ! command helm ls | grep $ENVIRONMENT_EXCHANGE_NAME-server-engine-$(echo ${!PAIR_BASE_OVERRIDE})$(echo ${!PAIR_2_OVERRIDE}); then

        echo "Running $(echo ${!PAIR_NAME_OVERRIDE}) on the Kubernetes."
        helm install --namespace $ENVIRONMENT_EXCHANGE_NAME \
                    --name $ENVIRONMENT_EXCHANGE_NAME-server-engine-$(echo ${!PAIR_BASE_OVERRIDE})$(echo ${!PAIR_2_OVERRIDE}) \
                    --set DEPLOYMENT_MODE="engine" \
                    --set PAIR="$(echo ${!PAIR_NAME_OVERRIDE})" \
                    --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                    --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                    --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                    --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                    --set podRestart_webhook_url="$ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL" \
                    -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                    -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server
      
      fi

      hollaex_ascii_pair_has_been_added;

    else

      printf "\033[91mFailed to add new pair $PAIR_NAME! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-add-pair-$PAIR_NAME

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

      echo "Adding new pair $PAIR_NAME on local exchange"
      if command docker exec --env "PAIR_NAME=$(echo ${!PAIR_NAME_OVERRIDE})" \
                  --env "PAIR_BASE=$(echo ${!PAIR_BASE_OVERRIDE})" \
                  --env "PAIR_2=$(echo ${!PAIR_2_OVERRIDE})" \
                  --env "TAKER_FEES=$(echo ${!TAKER_FEES_OVERRIDE})" \
                  --env "MAKER_FEES=$(echo ${!MAKER_FEES_OVERRIDE})" \
                  --env "MIN_SIZE=$(echo ${!MIN_SIZE_OVERRIDE})" \
                  --env "MAX_SIZE=$(echo ${!MAX_SIZE_OVERRIDE})" \
                  --env "MIN_PRICE=$(echo ${!MIN_PRICE_OVERRIDE})" \
                  --env "MAX_PRICE=$(echo ${!MAX_PRICE_OVERRIDE})" \
                  --env "INCREMENT_SIZE=$(echo ${!INCREMENT_SIZE_OVERRIDE})" \
                  --env "INCREMENT_PRICE=$(echo ${!INCREMENT_PRICE_OVERRIDE})"  \
                  --env "PAIR_ACTIVE=$(echo ${!PAIR_ACTIVE_OVERRIDE})" \
                  ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 \
                  node tools/dbs/addPair.js; then

          echo "Updating settings file to add new $PAIR_NAME."
          for i in ${CONFIG_FILE_PATH[@]}; do

            if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          
                CONFIGMAP_FILE_PATH=$i

                if ! command grep -q "HOLLAEX_CONFIGMAP_PAIRS.*${PAIR_NAME}.*" $i ; then

                  HOLLAEX_CONFIGMAP_PAIRS_OVERRIDE="${HOLLAEX_CONFIGMAP_PAIRS},${PAIR_NAME}"
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
          generate_local_docker_compose;

          if [[ ! "$IS_HOLLAEX_SETUP" ]]; then

            # Running database triggers
            docker exec  --env "PAIRS=${HOLLAEX_CONFIGMAP_PAIRS}" ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js > /dev/null

          fi

          hollaex_ascii_pair_has_been_added;

      else

        printf "\033[91mFailed to add new pair $PAIR_NAME on local exchange. Please confirm your input values and try again.\033[39m\n"

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

  PAIR_NAME=$answer

  printf "\n"
  echo "${answer} ✔"
  printf "\n"

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


    echo "*** Removing existing pair $PAIR_NAME on Kubernetes ***"
      
    if command helm install --name $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME \
                --namespace $ENVIRONMENT_EXCHANGE_NAME \
                --set job.enable="true" \
                --set job.mode="remove_pair" \
                --set job.env.pair_name="$PAIR_NAME" \
                --set DEPLOYMENT_MODE="api" \
                --set imageRegistry="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_REGISTRY" \
                --set dockerTag="$ENVIRONMENT_USER_HOLLAEX_CORE_IMAGE_VERSION" \
                --set envName="$ENVIRONMENT_EXCHANGE_NAME-env" \
                --set secretName="$ENVIRONMENT_EXCHANGE_NAME-secret" \
                -f $TEMPLATE_GENERATE_PATH/kubernetes/config/nodeSelector-hollaex-stateful.yaml \
                -f $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server/values.yaml \
                $SCRIPTPATH/kubernetes/helm-chart/bitholla-hollaex-server; then

      echo "*** Kubernetes Job has been created for removing existing pair $PAIR_NAME. ***"

      echo "*** Waiting until Job get completely run ***"
      sleep 30;

    else 

      printf "\033[91mFailed to create Kubernetes Job for removing existing pair $PAIR_NAME, Please confirm your input values and try again.\033[39m\n"
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME

    fi

    if [[ $(kubectl get jobs $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME \
            --namespace $ENVIRONMENT_EXCHANGE_NAME \
            -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}') == "True" ]]; then

      echo "*** Pair $PAIR_NAME has been successfully removed on your exchange! ***"
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME

      echo "*** Removing created Kubernetes Job for removing existing pair... ***"
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME

      echo "*** Removing existing $PAIR_NAME container from Kubernetes ***"
      PAIR_BASE=$(echo $PAIR_NAME | cut -f1 -d '-')
      PAIR_2=$(echo $PAIR_NAME | cut -f2 -d '-')

      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-server-engine-$PAIR_BASE$PAIR_2

      echo "*** Updating settings file to remove existing $PAIR_NAME. ***"
      for i in ${CONFIG_FILE_PATH[@]}; do

      if command grep -q "ENVIRONMENT_DOCKER_" $i > /dev/null ; then
          CONFIGMAP_FILE_PATH=$i
          if [[ "$PAIR_NAME" == "hex-usdt" ]]; then
              HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HOLLAEX_CONFIGMAP_PAIRS//$PAIR_NAME,}")
            else
              HOLLAEX_CONFIGMAP_CURRENCIES_OVERRIDE=$(echo "${HOLLAEX_CONFIGMAP_PAIRS//,$PAIR_NAME}")
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

      echo "Trading pair $PAIR_NAME has been successfully removed."
      echo "Please run 'hollaex restart --kube' to fully apply it."

    else

      printf "\033[91mFailed to remove existing pair $PAIR_NAME! Please try again.\033[39m\n"
      
      kubectl logs --namespace $ENVIRONMENT_EXCHANGE_NAME job/$ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME
      helm del --purge $ENVIRONMENT_EXCHANGE_NAME-remove-pair-$PAIR_NAME
      
    fi

  elif [[ ! "$USE_KUBERNETES" ]]; then

      IFS=',' read -ra CONTAINER_PREFIX <<< "-${ENVIRONMENT_EXCHANGE_RUN_MODE}"

      # Overriding container prefix for develop server
      # if [[ "$IS_DEVELOP" ]]; then
        
      #   CONTAINER_PREFIX=

      # fi

      # echo "Shutting down Nginx to block exchange external access"
      # docker stop $(docker ps | grep $ENVIRONMENT_EXCHANGE_NAME-nginx | cut -f1 -d " ")

      echo "*** Removing new pair $PAIR_NAME on local exchange ***"
      if command docker exec --env "PAIR_NAME=${PAIR_NAME}" ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/removePair.js; then

        echo "*** Updating settings file to remove existing $PAIR_NAME. ***"
        for i in ${CONFIG_FILE_PATH[@]}; do

        if command grep -q "HOLLAEX_CONFIGMAP_PAIRS" $i > /dev/null ; then
            CONFIGMAP_FILE_PATH=$i

            IFS="," read -ra PAIRS_TO_ARRAY <<< "${HOLLAEX_CONFIGMAP_PAIRS}"
            local REVOME_SELECTED_PAIR=${PAIRS_TO_ARRAY[@]/$PAIR_NAME}
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
        
        # if  [[ "$IS_DEVELOP" ]]; then

        #   # Restarting containers after database init jobs.
        #   echo "Restarting containers to apply database changes."
        #   docker-compose -f $HOLLAEX_CORE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml stop
        #   docker-compose -f $HOLLAEX_CORE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d --remove-orphans

        # else

        #   # Restarting containers after database init jobs.
        #   echo "Restarting containers to apply database changes."
        #   docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml stop
        #   docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d --remove-orphans

        # fi

        # Running database triggers
        docker exec --env="PAIRS=${HOLLAEX_CONFIGMAP_PAIRS}" ${DOCKER_COMPOSE_NAME_PREFIX}_${ENVIRONMENT_EXCHANGE_NAME}-server${CONTAINER_PREFIX[0]}_1 node tools/dbs/runTriggers.js > /dev/null

        echo "Trading pair $PAIR_NAME has been successfully removed."
        echo "Please run 'hollaex restart' to fully apply it."

        # if  [[ "$IS_DEVELOP" ]]; then

        #   # Restarting containers after database init jobs.
        #   echo "Restarting containers to apply database changes."
        #   docker-compose -f $HOLLAEX_CORE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml stop
        #   docker-compose -f $HOLLAEX_CORE_PATH/.$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d --remove-orphans

        # else

        #   # Restarting containers after database init jobs.
        #   echo "Restarting containers to apply database changes."
        #   docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml stop
        #   docker-compose -f $TEMPLATE_GENERATE_PATH/local/$ENVIRONMENT_EXCHANGE_NAME-docker-compose.yaml up -d --remove-orphans

        # fi

      else

        printf "\033[91mFailed to remove trading pair $PAIR_NAME on local exchange. Please confirm your input values and try again.\033[39m\n"

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
    Try to reach ${HOLLAEX_CONFIGMAP_API_HOST}/v1/health

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

    if [[ "$1" == "is_influxdb" ]]; then
        
        if [[ "$2" ]] && [[ "$3" ]]; then

        echo "--set image.repo=$2 --set image.tag=$3"

        fi

    else
    
        if [[ "$1" ]] && [[ "$2" ]]; then
            echo "--set imageRegistry=$1 --set dockerTag=$2"
        fi

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
  echo "You can proceed to add your own currencies, trading pairs right away from now on."

  echo "Attempting to add user custom currencies automatically..."

  if [[ "$USE_KUBERNETES" ]]; then

      if [[ "$HOLLAEX_DEV_FOR_CORE" ]]; then

        hollaex toolbox --add_coin --kube --is_hollaex_setup

      else

        hollaex toolbox --add_coin --kube --is_hollaex_setup 

      fi
  
  elif [[ ! "$USE_KUBERNETES" ]]; then

       if [[ "$HOLLAEX_DEV_FOR_CORE" ]]; then

        hollaex toolbox --add_coin --is_hollaex_setup

      else

        hollaex toolbox --add_coin --is_hollaex_setup 

      fi

  fi

  echo "Attempting to add user custom trading pairs automatically..."

  if [[ "$USE_KUBERNETES" ]]; then

      if [[ "$HOLLAEX_DEV_FOR_CORE" ]]; then

        hollaex toolbox --add_trading_pair --kube --is_hollaex_setup

      else 

        hollaex toolbox --add_trading_pair --kube --is_hollaex_setup

      fi

  elif [[ ! "$USE_KUBERNETES" ]]; then

      if [[ "$HOLLAEX_DEV_FOR_CORE" ]]; then

        hollaex toolbox --add_trading_pair --is_hollaex_setup

      else 

        hollaex toolbox --add_trading_pair --is_hollaex_setup

      fi

  fi

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
      
      if [[ "$RUN_WITH_VERIFY" == true ]]; then 

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

      if [[ "$RUN_WITH_VERIFY" == true ]]; then 
        
        echo "Do you want to push this image to your Docker Registry? (y/N)"

        read answer
      

          if [[ "$answer" = "${answer#[Yy]}" ]] ;then

            echo "Skipping..."
            echo "Your current image name: $ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_REGISTRY:$ENVIRONMENT_USER_HOLLAEX_WEB_IMAGE_VERSION."
            echo "You can later tag and push it by using 'docker tag' and 'docker push' command manually."
            echo "Please run 'hollaex web --restart' to apply the new image."
          
          else

            push_user_hollaex_web;
          
          fi
        
        else 

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

  if (( $LATEST_HOLLAEX_CLI_VERSION_PARSED > $CURRENT_HOLLAEX_CLI_VERSION_PARSED )); then

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
      sleep 30;

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
                --set allowed_domains="$HOLLAEX_CONFIGMAP_ALLOWED_DOMAINS" \
                --set admin_whitelist_ip="$HOLLAEX_CONFIGMAP_ADMIN_WHITELIST_IP" \
                --set captcha_site_key="$HOLLAEX_CONFIGMAP_CAPTCHA_SITE_KEY" \
                --set captcha_secret_key="$HOLLAEX_SECRET_CAPTCHA_SECRET_KEY" \
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
      export PAIR_NAME=$(echo "${PAIR_BASE}-${PAIR_2}") 

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

    export COIN_SYMBOL=$(echo $BITHOLLA_USER_EXCHANGE_LIST | jq -r ".data[$BITHOLLA_USER_EXCHANGE_ORDER].info.biz.ASSETS[$i].ASSET_SYMBOL") 
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

    export COIN_PREFIX=$(echo ${COIN_SYMBOL} | tr a-z A-Z)

    remove_existing_coin_configs_from_settings;

    save_coin_configs;

  done;


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
  export HOLLAEX_SECRET_INFLUX_PASSWORD=$(generate_random_values)

  if command grep -q "HOLLAEX_SECRET_ACTIVATION_CODE" $i > /dev/null ; then

    SECRET_FILE_PATH=$i

    sed -i.bak "s/HOLLAEX_SECRET_REDIS_PASSWORD=.*/HOLLAEX_SECRET_REDIS_PASSWORD=$HOLLAEX_SECRET_REDIS_PASSWORD/" $SECRET_FILE_PATH
    sed -i.bak "s/HOLLAEX_SECRET_PUBSUB_PASSWORD=.*/HOLLAEX_SECRET_PUBSUB_PASSWORD=$HOLLAEX_SECRET_REDIS_PASSWORD/" $SECRET_FILE_PATH

    sed -i.bak "s/HOLLAEX_SECRET_DB_PASSWORD=.*/HOLLAEX_SECRET_DB_PASSWORD=$HOLLAEX_SECRET_DB_PASSWORD/" $SECRET_FILE_PATH

    sed -i.bak "s/HOLLAEX_SECRET_INFLUX_PASSWORD=.*/HOLLAEX_SECRET_INFLUX_PASSWORD=$HOLLAEX_SECRET_INFLUX_PASSWORD/" $SECRET_FILE_PATH

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
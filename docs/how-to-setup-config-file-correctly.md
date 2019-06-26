## How to setup `config` file correctly for `hollaex-cli`.

All `hollaex-cli` commands relies on `config` file. You should setup it correctly before running any `hollaex-cli` commands. But don't worry. You will figure out how to set it up correctly on this document.

There are 3 types of configurations on `config` file.

> Even If you are just planning to run local environment based on `docker-compose`, make sure to fill up all `config` values including have `KUBERNETES_CONFIGMAP` or `KUBERNETES_SECRET` prefix. `hollaex-cli` generates necessary ENVs for hollaex from all those `config` file values.
- General setup for exchange (with `ENVIRONMENT` prefix).
- Kubernetes [Configmap](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) setup for not sensitive `env` data (with `KUBERNETES_CONFIGMAP` prefix).
- Kubernetes [Secret](https://kubernetes.io/docs/concepts/configuration/secret/) setup for sensitive `env` data (with `KUBERNETES_SECRET` prefix). Outputs will be encode as base64 automatically.


Default `config` file got default values on it which are recommended values from our team. This document will describe some customizable ones here. 

### `ENVIRONMENT` configurations

```
ENVIRONMENT_EXCHANGE_NAME=hollaex
```

The name of your exchange! Most important thing. Make sure you set it all in lower case. Some dangling configurations such as `yaml` files for Kubernetes will reference this name defined on here.

```
ENVIRONMENT_DOCKER_IMAGE_REGISTRY=bitholla/hollaex-production
ENVIRONMENT_DOCKER_IMAGE_VERSION=1.17.0
```

Docker repository for downloading dockerized HollaEx and the version of it. For the most of time, default value on the file is the latest. But you can still modify it if you want.

```
ENVIRONMENT_KUBERNETES_API_SERVER_REPLICAS=2
```

Specifying numbers of API contianers to run on Kubernetes. Default is 2.

```
ENVIRONMENT_DOCKER_COMPOSE_GENERATE_ENV_ENABLE=true
ENVIRONMENT_DOCKER_COMPOSE_GENERATE_YAML_ENABLE=true
```
Only for `docker-compose` users. If you want to generate `docker-compose` file or `env` file of it again, set these as `true`. New users should set it to `true` always.

```
ENVIRONMENT_KUBERNETES_USE_EXTERNAL_POSTGRESQL=false
ENVIRONMENT_KUBERNETES_POSTGRESQL_VOLUMESIZE=50Gi

ENVIRONMENT_KUBERNETES_USE_EXTERNAL_REDIS=false

ENVIRONMENT_KUBERNETES_USE_EXTERNAL_INFLUXDB=false
ENVIRONMENT_KUBERNETES_INFLUXDB_VOLUMESIZE=30Gi
```

Only for Kubernetes users. Option to turn on and off creating database and etc on Kubernetes. If you set them as `true`, make sure you set endpoints to external services correctly. You can also specify persistence volume size of both PostgreSQL and InfluxDB with `ENVIRONMENT_KUBERNETES_POSTGRESQL_VOLUMESIZE` or `ENVIRONMENT_KUBERNETES_INFLUXDB_VOLUMESIZE` values.

```
ENVIRONMENT_KUBERNETES_POSTGRESQL_NODESELECTOR="{}"
ENVIRONMENT_KUBERNETES_REDIS_NODESELECTOR="{}"
ENVIRONMENT_KUBERNETES_INFLUXDB_NODESELECTOR="{}"
ENVIRONMENT_KUBERNETES_EXCHANGE_NODESELECTOR="{doks.digitalocean.com/node-pool:k8s-hollaex-exchange-nodes}"
```
Only for Kubernetes users. Options to define [`nodeSelector`](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/) values for Kubernetes deployments. It follows general `yaml` syntax such as the example above, but WITHOUT SPACES. For example, `{doks.digitalocean.com/node-pool: k8s-hollaex-exchange-nodes}` should be `{doks.digitalocean.com/node-pool:k8s-hollaex-exchange-nodes}` (without spaces). 


```
ENVIRONMENT_KUBERNETES_GENERATE_CONFIGMAP_ENABLE=true
ENVIRONMENT_KUBERNETES_GENERATE_SECRET_ENABLE=true
ENVIRONMENT_KUBERNETES_GENERATE_INGRESS_ENABLE=true
```
Only for Kubernetes users. Option to set `hollaex-cli` to generate necessary files such as `configmap`. New users should set it to `true` always.

```
ENVIRONMENT_KUBERNETES_DOCKER_HUB_USERNAME=
ENVIRONMENT_KUBERNETES_DOCKER_HUB_PASSWORD=
ENVIRONMENT_KUBERNETES_DOCKER_HUB_EMAIL=
```
Credentails for docker hub access. `hollaex-cli` will create `registry-secret` based on these values automatically on your Kubernetes.

```
ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER=letsencrypt-prod
```

Only for Kubernetes users. We recommend to use [`cert-manager`](https://docs.cert-manager.io/en/latest/index.html) for managing SSL certs on Kubernetes. `hollaex-cli` will automatically define `cert-manager` [issuer](https://docs.cert-manager.io/en/latest/tasks/issuers/) name same as `ENVIRONMENT_KUBERNETES_INGRESS_CERT_MANAGER_ISSUER` value.

```
ENVIRONMENT_KUBERNETES_ALLOW_EXTERNAL_POSTGRESQL_ACCESS=false
ENVIRONMENT_KUBERNETES_EXTERNAL_POSTGRESQL_ACCESS_PORT=31250

ENVIRONMENT_KUBERNETES_ALLOW_EXTERNAL_REDIS_ACCESS=false
ENVIRONMENT_KUBERNETES_EXTERNAL_REDIS_ACCESS_PORT=31251
```

You can specify which port number to allocate for PostgreSQL or Redis external access. Port number should be in range of Kubernetes [NodePort](https://kubernetes.io/docs/concepts/services-networking/service/). If you dont want to expose it, set it as `false`.

```
ENVIRONMENT_KUBERNETES_RESTART_NOTIFICATION_WEBHOOK_URL=
```
Webhook URL for getting notifications in case of Kubernetes Pod restart / terminate happens. Tested with [Slack webhook integrations](https://api.slack.com/incoming-webhooks). 


### `Configmap` configurations

```
KUBERNETES_CONFIGMAP_API_HOST
```

Full domain of your exchange's api endpoint, Such as `api.hollaex.com`. Modify it as your own domain.

```
KUBERNETES_CONFIGMAP_DOMAIN
```
Full domain of your exchange's web client endpoint. Such as `hollaex.com`. Modify it as your own domain.

```
KUBERNETES_CONFIGMAP_REDIS_HOST=$ENVIRONMENT_EXCHANGE_NAME-redis
KUBERNETES_CONFIGMAP_REDIS_PORT=6379

KUBERNETES_CONFIGMAP_PUBSUB_HOST=$ENVIRONMENT_EXCHANGE_NAME-redis
KUBERNETES_CONFIGMAP_PUBSUB_PORT=6379
```

```
KUBERNETES_CONFIGMAP_MAX_TRADES=50
```
Max trades number to display on exchange.

```
KUBERNETES_CONFIGMAP_BTC_FIAT_TICK_SIZE=1
KUBERNETES_CONFIGMAP_BTC_FIAT_MIN_PRICE=500
KUBERNETES_CONFIGMAP_BTC_FIAT_MAX_PRICE=50000
KUBERNETES_CONFIGMAP_BTC_FIAT_MIN_SIZE=0.0001
KUBERNETES_CONFIGMAP_BTC_FIAT_MAX_SIZE=21000000

KUBERNETES_CONFIGMAP_ETH_FIAT_TICK_SIZE=1
KUBERNETES_CONFIGMAP_ETH_FIAT_MIN_PRICE=10
KUBERNETES_CONFIGMAP_ETH_FIAT_MAX_PRICE=10000
KUBERNETES_CONFIGMAP_ETH_FIAT_MIN_SIZE=0.001
KUBERNETES_CONFIGMAP_ETH_FIAT_MAX_SIZE=20000000

KUBERNETES_CONFIGMAP_ETH_BTC_TICK_SIZE=0.00001
KUBERNETES_CONFIGMAP_ETH_BTC_MIN_PRICE=0.0001
KUBERNETES_CONFIGMAP_ETH_BTC_MAX_PRICE=10
KUBERNETES_CONFIGMAP_ETH_BTC_MIN_SIZE=0.001
KUBERNETES_CONFIGMAP_ETH_BTC_MAX_SIZE=1000

KUBERNETES_CONFIGMAP_BCH_FIAT_TICK_SIZE=1
KUBERNETES_CONFIGMAP_BCH_FIAT_MIN_PRICE=10
KUBERNETES_CONFIGMAP_BCH_FIAT_MAX_PRICE=10000
KUBERNETES_CONFIGMAP_BCH_FIAT_MIN_SIZE=0.001
KUBERNETES_CONFIGMAP_BCH_FIAT_MAX_SIZE=20000000

KUBERNETES_CONFIGMAP_BCH_BTC_TICK_SIZE=0.00001
KUBERNETES_CONFIGMAP_BCH_BTC_MIN_PRICE=0.0001
KUBERNETES_CONFIGMAP_BCH_BTC_MAX_PRICE=10
KUBERNETES_CONFIGMAP_BCH_BTC_MIN_SIZE=0.001
KUBERNETES_CONFIGMAP_BCH_BTC_MAX_SIZE=1000

KUBERNETES_CONFIGMAP_XRP_FIAT_TICK_SIZE=0.0001
KUBERNETES_CONFIGMAP_XRP_FIAT_MIN_PRICE=0.001
KUBERNETES_CONFIGMAP_XRP_FIAT_MAX_PRICE=100
KUBERNETES_CONFIGMAP_XRP_FIAT_MIN_SIZE=0.1
KUBERNETES_CONFIGMAP_XRP_FIAT_MAX_SIZE=1000000
```
Tick size, min / max price and size values for each currencies. Default values are recommended (same as hollaex.com demo), but also possible to customize it as much as you want.

Endpoint and port of your Redis server. If you set `ENVIRONMENT_KUBERNETES_USE_EXTERNAL_REDIS` as `false`, There's no need to modify this value. Only modify it same as your Redis connection information in case of you planning to use external Redis.

````
KUBERNETES_CONFIGMAP_SENDER_EMAIL=support@bitholla.com
KUBERNETES_CONFIGMAP_SUPPORT_EMAIL=support@bitholla.com

KUBERNETES_CONFIGMAP_ADMIN_EMAIL=admin@bitholla.com
KUBERNETES_CONFIGMAP_SUPERVISOR_EMAIL=spervisor@bitholla.com
KUBERNETES_CONFIGMAP_KYC_EMAIL=kyc@bitholla.com
````

Email addresses to send user notifications. Modify it as your support emails by referencing the default values.

```
KUBERNETES_CONFIGMAP_FRESHDESK_HOST=
```

HollaEx supports [Freshdesk](https://freshdesk.com/) for easy customer service and support. Please modify this value to your Freshdesk domain.

```
KUBERNETES_CONFIGMAP_ADMIN_WHITELIST_IP=
```

Whitelist IPs list for admin access, management.

```
KUBERNETES_CONFIGMAP_MIN_OPERATION_DEPOSIT_FIAT=100
KUBERNETES_CONFIGMAP_MIN_OPERATION_WITHDRAW_FIAT=100
KUBERNETES_CONFIGMAP_MAX_OPERATION_WITHDRAW_BTC=10
```

```
KUBERNETES_CONFIGMAP_NEW_USER_IS_ACTIVATED=true
KUBERNETES_CONFIGMAP_NEW_USER_DEFAULT_LANGUAGE=en
KUBERNETES_CONFIGMAP_DEFAULT_THEME=dark
KUBERNETES_CONFIGMAP_EMAILS_TIMEZONE=UTC
KUBERNETES_CONFIGMAP_SEND_EMAIL_TO_SUPPORT=true
```

New user allowance for registration, Default language for new user, Default theme value for new user, Timezone setup for system generated emails, Allowance users to send emails to system support.

```
KUBERNETES_CONFIGMAP_LOGO_PATH=https://s3.ap-northeast-2.amazonaws.com/public-holla-images/bitholla-logo.png

KUBERNETES_CONFIGMAP_LOGO_BLACK_PATH=https://s3.ap-northeast-2.amazonaws.com/public-holla-images/bitholla-logo.png
```

Image URLs of logos. Set it as your logo file URLs.

```
KUBERNETES_CONFIGMAP_ALLOWED_DOMAINS=hollaex.com
```

Allowed client domains for your exchange (CORS). Set it as same as your web client domain. In case of you need a local client access for development, Also add `localhost` on here.

```
KUBERNETES_CONFIGMAP_S3_BUCKETS=

KUBERNETES_CONFIGMAP_ID_DOCS_BUCKET=
```

AWS S3 URLs to store user verification data. Make sure to set them as private buckets.

```
KUBERNETES_CONFIGMAP_FIAT_CURRENCY_NAME=Euro
KUBERNETES_CONFIGMAP_CURRENCY_FIAT=fiat
KUBERNETES_CONFIGMAP_CURRENCIES=fiat,btc,eth,bch
KUBERNETES_CONFIGMAP_PAIRS='btc-eur|btc|fiat,eth-eur|eth|fiat,eth-btc|eth|btc,bch-eur|bch|fiat,bch-btc|bch|btc'
```
Name of the fiat currency that exchange supports, name of `fiat` on system, supported currencies on exchange, trading paris list that exchange supports.

```
KUBERNETES_CONFIGMAP_NETWORK=testnet
```

Crypto network selection for exchange. Default value is `testnet`. If your exchange is ready to become handle some real money, Set it as `mainnet`.

```
KUBERNETES_CONFIGMAP_VALID_LANGUAGES=en
```

Valid languages of exchange. Default value is English (`en`).


### `Secret` configurations

```
KUBERNETES_SECRET_REDIS_PASSWORD=
KUBERNETES_SECRET_PUBSUB_PASSWORD=
```

Password setups for Redis access. If you set `ENVIRONMENT_KUBERNETES_USE_EXTERNAL_REDIS` as `false`, Redis will follow this value you specify to set it's password.

```
KUBERNETES_SECRET_DB_NAME=

KUBERNETES_SECRET_DB_USERNAME=

KUBERNETES_SECRET_DB_PASSWORD=

KUBERNETES_SECRET_DB_HOST=$ENVIRONMENT_EXCHANGE_NAME-db
```

Credentials for PostgreSQL DB. Make sure to modify them as secure one. If you are planning to use external PostgreSQL DB, Please set `KUBERNETES_SECRET_DB_HOST` to your external database's endpoint.

```
KUBERNETES_SECRET_S3_WRITE_ACCESSKEYID=

KUBERNETES_SECRET_S3_WRITE_SECRETACCESSKEY=


KUBERNETES_SECRET_S3_READ_ACCESSKEYID=

KUBERNETES_SECRET_S3_READ_SECRETACCESSKEY=
```

AWS S3 access keys to read and write (upload) user verification data. You can generate those keys on [AWS IAM](https://aws.amazon.com/iam/?nc1=h_ls).

```
KUBERNETES_SECRET_SES_ACCESSKEYID=

KUBERNETES_SECRET_SES_SECRETACCESSKEY=

KUBERNETES_SECRET_SES_REGION=


KUBERNETES_SECRET_SNS_ACCESSKEYID=

KUBERNETES_SECRET_SNS_SECRETACCESSKEY=

KUBERNETES_SECRET_SNS_REGION=
```

Access keys for [AWS SES](https://aws.amazon.com/ses/?nc1=h_ls) and [AWS SNS](https://aws.amazon.com/sns/?nc1=h_ls). HollaEx requires both two for sending emails and notifications.

```
KUBERNETES_SECRET_CAPTCHA_SECRET_KEY=
```

reCAPTCHA key for enabling CAPTCHA support on login page. HollaEx uses [Google reCAPTCHA](https://www.google.com/recaptcha/intro/v3.html) to block malicious logins on website. 

```
KUBERNETES_SECRET_INFLUX_DB=

KUBERNETES_SECRET_INFLUX_HOST=$ENVIRONMENT_EXCHANGE_NAME-influxdb

KUBERNETES_SECRET_INFLUX_PORT=8086

KUBERNETES_SECRET_INFLUX_USER=

KUBERNETES_SECRET_INFLUX_PASSWORD=
```

Credentials for InfluxDB. Make sure to modify them as secure one. If you are planning to use external InfluxDB, Please set `KUBERNETES_SECRET_INFLUX_HOST` to your external database's endpoint.

```
KUBERNETES_SECRET_WALLI_KEY=
KUBERNETES_SECRET_WALLI_SECRET=

KUBERNETES_SECRET_WALLA_KEY=
KUBERNETES_SECRET_WALLA_SECRET=
```

KEY and Secret values for WALLI / WALLA access. Which manages user's crypto balance and notifying system If there are new transactions. Contact bitHolla Team to get keys If you don't have it already. 

```
KUBERNETES_SECRET_FRESHDESK_KEY=

KUBERNETES_SECRET_FRESHDESK_AUTH=
```

Key and auth credentials for your Freshdesk. 

```
#### AUTOMATICALLY GENERATED PASSWORDS SHOULD GO DOWN BELOW ####
```

Once you run `hollaex init`, or `hollaex upgrade` with `--generate-passwords` flag, `hollaex-cli` will generate necessary passwords safely and mark it on your `config` file. Values would be store down below the comment. 
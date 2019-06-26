## Playing with `hollaex-cli`.

`hollaex-cli` lets you to create, upgrade, and remove hollaex exchange both on local machine and production kubernets cluster. On this docs, we will figure out how to actually use this awesome tool.

> `hollaex-cli` always relies on config file. Make sure you already setup it correctly before actually running `hollaex-cli` commands. You can check detailed information on [here](how-to-setup-config-file-correctly.md).

### Running HollaEx Exchange on local machine.

```
hollaex local --config <CONFIG_FILE_PATH> --command "<DOCKER_COMPOSE_COMMAND>"
```

You can run these type of commands to run full HollaEx exchange on your local machine. It's based on standard `docker-compose`, so all general `docker-compose` commands are compatible.

```
hollaex local --config <CONFIG_FILE_PATH> --command "up"
```
For example, If you want to just bring up HollaEx, command above will do it's job.


```
hollaex local --config <CONFIG_FILE_PATH> --command "up -d"
```
Do you want to run it on your background? Try to add `-d` flag behind of `docker-compose` command.

```
hollaex local --config <CONFIG_FILE_PATH> --command "down"
```

Similar concept, Bringing down HollaEx can be done with this command.

Once you run `hollaex local` command with defined config file, `hollaex-cli` will automatically generates necessary components such as `docker-compose` yaml file and `env` for it.

Generataed files will store at `$HOME/.hollaex-cli/local` directory on your local machine.

```
ENVIRONMENT_DOCKER_COMPOSE_GENERATE_ENV_ENABLE
ENVIRONMENT_DOCKER_COMPOSE_GENERATE_YAML_ENABLE
```

If you already got a generated files and don't want to update it, you can set these values above as false on config file.

#### Database Jobs

Once you completely generated HollaEx environment on your local for the first time, You also need to run some "database jobs". Sounds complicated, but Don't worry. We already automated necessary things.

```
hollaex local --config <CONFIG_FILE_PATH> --database_init
```

This command above will run all necessary database jobs based on your `config` file settings. Once everything is done, It's all good to use. Try to connect `http://localhost/v0/health` endpoint with your web browser to check HollaEx is really up or not.


Enjoy!


### Running HollaEx Exchange on Kubernetes

```
hollaex init --config <CONFIG_FILE_PATH>
```

This command will run HollaEx exchange on your Kubernetes cluster.

```
ENVIRONMENT_KUBERNETESUSE_EXTERNAL_POSTGRESQL
ENVIRONMENT_KUBERNETESUSE_EXTERNAL_REDIS
ENVIRONMENT_KUBERNETESUSE_EXTERNAL_INFLUXDB
```
You can set these values above as true or false based on your needs. If you set to use external services for db and etc, `hollaex-cli` will not run it on Kubernetes. Make sure you already set endpoints of it to your existing external services.

Also If you also got a external Walli, You can set `ENVIRONMENT_KUBERNETES_USE_EXTERNAL_WALLI` as true.

Necessary database initiallization jobs will be run together during the `init` process.

```
hollaex init --config <CONFIG_FILE_PATH> --no_verify
```

If you want to run any commands without verifying with `(y/n)`, add `--no_verify` flag on command.

```
hollaex init --config <CONFIG_FILE_PATH> --skip_generate_passwords
```

If you want to use pre-defined passwords on your `config` file, instead of generating new values. You can use `--skip_generate_passwords` flag for it.

Make sure you already defined all necessary values before using this flag. Otherwise the exchange WILL NOT BE fully initalize. 

### Upgrading HollaEx Exchange on Kubernetes

```
hollaex upgrade --config <CONFIG_FILE_PATH>
```

This command will upgrade existing HollaEx exchange with new configurations based on `config` file.

New configurations can be new docker image version, New domain for exchange, New endpoint for database, anything which defined on `config` file.

For example, If you want to upgrade the exchange version to `1.15.0` from `1.14.0`, modify configuration on `config` file like down below and run the command.

```
ENVIRONMENT_DOCKER_IMAGE_VERSION=1.15.0
```

`hollaex-cli` will regenerate necessary files based `on` config and apply on Kubernetes. Make sure you don't set `ENVIRONMENT_KUBERNETES_GENERATE_CONFIGMAP_ENABLE` (or secret, ingress...) as false.

```
hollaex upgrade --config <CONFIG_FILE_PATH> --generate_passwords
```

In case of you want to renew generated passwords on `config` file, You can enable this flag for it.

Make sure to REMOVE ALL GENERATED PASSWORDS which located bottom of config file BEFORE runnig this flag.    

*Exchange service will be unavailable while applying these changes.*

#### Upgrading backend components

In case of If you need to upgrade backend components, such as Redis, PostgreSQL, or InfluxDB, You can use `--upgrade_backends` flag like down below.

```
hollaex upgrade --config <CONFIG_FILE_PATH> --upgrade_backends
```

This will let your backend components refresh based on helm chart which pre defined at `hollaex-cli` path. It will not touch your persistence volume, so *YOUR DATA WILL BE SAFE*. but We generally recommend to backup every necessary data before you run this command for just in case. Backup is always important!

#### Database Jobs

If the new update of HollaEx requries new database structure or changes, You should run some "database jobs". Sounds complicated, but Don't worry. We already automated necessary things.

```
hollaex upgrade --config <CONFIG_FILE_PATH> --database_init
```

This command above will run all necessary database jobs *during upgrade steps* based on your `config` file settings. Once everything is done, It's all good to use. Log in and look around your exchange that It's really functioning or not!


### Removing HollaEx Exchange on Kubernetes

```
hollaex cleanup --config <CONFIG_FILE_PATH>
```

This command will cleanup existing HollaEx environment based on `config` file.

It will not remove pre-generated files for setting up Kubernetes. The command will only remove existing HollaEx exchange running on Kubernetes. You can always bring it up again with generated files.

*If you are using PostgreSQL or InfluxDB running on Kubernetes, Running this command will cause a permanent data loss. Think twice before running the command and make sure to backup every data necessary.*
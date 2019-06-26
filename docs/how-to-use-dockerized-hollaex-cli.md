## How to use dockerized hollaex-cli

Even `hollaex-cli` provides easy way to fully install it, Sometimes you might need something more.

For example, Making an automation pipeline to upgrade your exchange, Installing a full `hollaex-cli` on your automation server can be messy and overhead. Or maybe you just want to run `hollaex-cli` on incompatible machine, like Windows.

In that kind of cases, Dockerized `hollaex-cli` can be very useful. 

You can pull it from `bitholla/hollaex-cli` registry on Docker Hub. It will be always synced with latest stable release of `hollaex-cli` on GitHub.

### Basic usage

You'll be able to find `docker-compose` file at `/docker` directory of GitHub repository.

```
    environment:
    # TOKEN, API SERVER ENDPOINT, CERT FOR YOUR KUBERNETES CLUSTER
    # YOU CAN ALSO PASS KUBECONFIG FILE INSTEAD OF DEFINING IT MANUALLY
      - KUBERNETES_TOKEN=
      - KUBERNETES_SERVER=
      - KUBERNETES_CERT=
```

You should specifiy your Kubernetes cluster's Access Token, API Server Endpoint, and CA for letting `hollaex-cli` interates with your Kubernetes.

```
volumes:
      #PATH TO KUBECOFNIG FILE
      #NO NEED TO SET IT IF YOU ALREADY DEFINED TOKEN, API SERVER ENDPOINT, AND CA AS ENVIRONMENT
      - <PATH_TO_KUBECONFIG_FILE>:/root/kubeconfig
```

If you have a `KUBECONFIG` file on your local, You can also bound it from your local disk instead of defining all information manually as ENV.

```
volumes:
      - <PATH_TO_HOLLAEX-CLI_CONFIG_FILE>:/root/config
```
You also need to specify a path to your `config` file for `hollaex-cli`.

```
environment:
    - HOLLAEX=upgrade --config /root/config --no_verify
```
Once necessary things are all set, You can pass `hollaex-cli` commands as `HOLLAEX` env to container like above.

MAKE SURE to add `--no_verify` flag to make `hollaex-cli` doesn't ask your confirmation to proceed.

```
docker-compose up -f docker/docker-compose.yaml
```
You can now run it with `docker-compose` like above to execute what you've just defined.



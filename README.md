![hollaex-cli](docs/.docs-images/hollaex-cli.png)

## HollaEx CLI

`hollaex-cli` is a command-line tool for operating HollaEx with simple commands. Anyone even without deep knowledge on Kubernetes and Docker can play with hollaex easily with this awesome tool.

### Installation

You can easily install `hollaex-cli` with a simple command down below.

Make sure you already installed `docker` and `docker-compose` for local deployment, `kubectl` and `helm` for production Kubernetes deployment. `hollaex-cli` will not work properly if those things are missing on your machine.

```
curl -L https://raw.githubusercontent.com/bitholla/hollaex-cli/master/install.sh | bash
```

Enjoy :)

### Uninstallation

As as installing `hollaex-cli`, You can use one simple command down below to completely remove `hollaex-cli` from your computer.

```
curl -L https://raw.githubusercontent.com/bitholla/hollaex-cli/master/uninstall.sh | bash
```

## Documents
### Playing with `hollaex-cli`

> See the full documentation [here](./docs/playing-with-hollaex-cli.md).

### How to setup `config` file correctly

> See the full documentation [here](./docs/how-to-setup-config-file-correctly.md).

### How to use dockerized `hollaex-cli`

> See the full documentation [here](./docs/how-to-use-dockerized-hollaex-cli.md).
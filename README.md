
<!-- PROJECT LOGO -->
<br />
<p align="center">

  <h3 align="center">HollaEx CLI</h3>

  <p align="center">
    CLI tool to run and interact with HollaEx Kit based exchanges.
    <br />
  </p>
</p>

HollaEx CLI is a command-line tool for operating [HollaEx Kit](https://github.com/hollaex/hollaex-kit) with simple commands. Anyone even without deep knowledge on Kubernetes and Docker can play with HollaEx Kit easily with this awesome CLI.

<!-- GETTING STARTED -->
## Getting Started

### Prerequisites

- Bash shell compatible operating system (Ubuntu is recommended)

> The prerequisites mentioned below would be managed by the CLI install automatically.

- `docker` & `docker-compose`
- `kubectl` & `helm` (for Kubernetes deployment)

### Installation

```
curl -L https://raw.githubusercontent.com/bitholla/hollaex-cli/master/install.sh | bash
```

### Version Upgrade

```
curl -L https://raw.githubusercontent.com/bitholla/hollaex-cli/master/install.sh | bash
```

### Uninstallation

```
curl -L https://raw.githubusercontent.com/bitholla/hollaex-cli/master/uninstall.sh | bash
```

Enjoy :)

<!-- USAGE EXAMPLES -->
## Usage

HollaEx CLI is a combination of various command sets for running, operating, and interacting with the HollaEx Kit exchange. 

In this section, you will see the usage and examples of each commands.

<!-- TABLE OF CONTENTS -->
<details open="open">
  <summary><h2 style="display: inline-block">Common Usage</h2></summary>
  <ol>
    <li>
      <a href="#setting-up-the-exchange">Setting up the exchange</a>
    </li>
    <li>
      <a href="#starting-the-exchange">Starting the exchange</a>
    </li>
    <li><a href="#stopping-the-exchange">Stopping the exchange</a></li>
    <li><a href="#restarting-the-exchange">Restarting the exchange</a></li>
    <li><a href="#applying-custom-domains">Applying custom domains</a></li>
    <li><a href="#applying-code-changes">Applying code changes</a></li>
    <li><a href="#getting-exchange-logs">Getting exchange logs</a></li>
  </ol>
</details>

<!-- TABLE OF CONTENTS -->
<details open="open">
  <summary><h2 style="display: inline-block">Advanced Usage</h2></summary>
  <ol>
    <li>
      <a href="#getting-a-backup-and-restore">Getting a backup and restore</a>
    </li>
    <li>
      <a href="#flushing-redis">Flushing Redis</a>
    </li>
    <li>
      <a href="#overriding-config">Overriding Config</a>
    </li>
    <li>
      <a href="#overriding-security-configuration">Overridng Security Configuration</a>
    </li>
    <li>
      <a href="#overriding-activation-code--api-key">Overriding Activation Code & API Key</a>
    </li>
    <li>
      <a href="#connecting-to-database">Connecting to Database</a>
    </li>
    <li>
      <a href="#connecting-to-redis">Connecting to Redis</a>
    </li>
    <li>
      <a href="#installing-specific-version-of-cli">Installing specific version of CLI</a>
    </li>
    <li>
      <a href="#terminating-the-exchange">Terminating the exchange</a>
    </li>
  </ol>
</details>

### Common 
### Setting up the exchange

```
hollaex server --setup
```

Setting up the exchange on the local machine.

```
hollaex server --setup --kube
```

Setting up the exchange on Kubernetes cluster. The `KUBECONFIG` of the Kubernetes cluster should be exposed first.

---

```
hollaex web --setup
```

Setting up the exchange web server. The exchange server itself should be prepared, before setting up the web.

```
hollaex web --setup --kube
```

Setting up the exchange web server on Kubernetes cluster.

### Starting the exchange

```
hollaex server --start
```

Starting the stopped exchange server.

```
hollaex server --start --kube
```

Starting the stopped exchange server on Kubernetes.

---

```
hollaex web --start
```

Starting the stopped exchange web server.


```
hollaex web --start --kube
```

Starting the stopped exchange web server on Kubernetes.

### Stopping the exchange

```
hollaex server --stop
```

Stopping the started exchange server.

```
hollaex server --stop --kube
```

Stopping the started exchange server on Kubernetes.

---

```
hollaex web --stop
```

Stopping the started exchange web server.

```
hollaex web --stop --kube
```

Stopping the started exchange web server on Kubernetes.

### Restarting the exchange

```
hollaex server --restart
```

Restarting the started exchange server.

```
hollaex server --restart --kube
```

Restarting the started exchange server on Kubernetes.

---

```
hollaex web --restart
```

Restarting the started web server.

```
hollaex web --restart --kube
```

Restarting the started web server on Kubernetes.

### Applying custom domains

```
hollaex prod
```

Applying my own custom domains for the exchange. Issuing SSL certificates would be also handled along the process.

```
hollaex prod --kube
```

Applying my own custom domains for the exchange on Kubernetes. Issuing SSL certificates would be also handled along the process.

### Applying code changes

```
hollaex build
```

Building my HollaEx Kit. New code changes will be included to the new build.

```
hollaex apply --repository <MY_REPO> --tag <MY_TAG>
```

Applying the built Docker image to the exchange server.

```
hollaex apply --repository <MY_REPO> --tag <MY_TAG> --kube
```

Applying the built Docker image to the exchange server on Kubernetes.

--- 

```
hollaex web --build
```

Building my HollaEx Kit (`/web` directory). New code changes will be included to the new build.

```
hollaex web --apply --repository <MY_REPO> --tag <MY_TAG>
```

Applying the built Docker image to the exchange web server.

```
hollaex web --apply --repository <MY_REPO> --tag <MY_TAG> --kube
```

Applying the built Docker image to the exchange web server on Kubernetes.

### Getting exchange logs

```
hollaex logs
```

Getting logs from exchange server.

```
hollaex logs --kube
```

Getting logs from exchange server on Kubernetes.

```
hollaex status
```

Getting the exchange server status.

```
hollaex status --kube
```

Getting the exchange server status on Kubernetes.

---

### Advanced 
### Getting a backup and restore

```
hollaex toolbox --backup
```

Getting a exchange database backup. The backup (dump) file will be saved at the `/backups` folder at your HollaEx Kit.

```
hollaex toolbox --backup --kube
```

Getting a exchange database backup on Kubernetes.

```
hollaex toolbox --set_backup_cronjob --kube
```

Setting up a database backup cronjob on Kubernetes. The cronjob will perodically backup the database and push the dumped file on AWS S3.

To restore the backup, please check the [docs](https://docs.bitholla.com/hollaex-kit/advanced/backup-and-restore#restore).

### Flushing Redis

```
hollaex toolbox --flush_redis
```

Flushing the Redis for the exchange server. The exchange server itself should be restarted after the flush. This command would be useful to clean up the Redis data and make the enviornment fresh. 

```
hollaex toolbox --flush_redis --kube
```

Flushing the Redis for the exchange server on Kubernetes.

### Overriding Config

```
hollaex toolbox --set_config
```

Overriding the exchange configuration based on your HollaEx Kit settings. The command would be useful to override the wrongly configured data on your exchange.

```
hollaex toolbox --set_config --kube
```

Overriding the exchange configuration based on your HollaEx Kit settings on Kubernetes.

### Overriding Security Configuration

```
hollaex toolbox --set_security
```

Overriding security configuration (IP whitelist, trusted domain, and Google reCaptcha credentials) based on your HollaEx Kit settings. If you somehow locked up yourself by doing a misconfiguration, this is the way out.

```
hollaex toolbox --set_security --kube
```

Overriding security configuration on Kubernetes.

### Overriding Activation Code & API Key

```
hollaex toolbox --set_activation_code
```

Overriding the exchange activation code and exchange API key based on your HollaEx Kit settings. If your activation code or exchange API key has been changed, you should run this command to apply on your existing exchange.

```
hollaex toolbox --set_activation_code --kube
```

Overriding the exchange activation code and exchange API key on Kubernetes.

### Connecting to database

```
hollaex toolbox --connect_database
```

Opening a interactive shell to your exchange database.

```
hollaex toolbox --connect_database --kube
``` 

Opening a interactive shell to your exchange database on Kubernetes.

### Connecting to Redis

```
hollaex toolbox --connect_redis
```

Opening a interactive shell to your exchange Redis.

```
hollaex toolbox --connect_redis --kube
``` 

Opening a interactive shell to your exchange Redis on Kubernetes.

### Installing specific version of CLI

```
hollaex toolbox --install_cli <VERSION_NUMBER>
```

Installing a specific version of HollaEx CLI. For example, to install 2.0.0 version of HollaEx CLI, run `hollaex toolbox --install_cli 2.0.0`.


### Terminating the exchange

```
hollaex server --terminate
```

Completely terminating the exchange. The terminated exchange can't be recovered. Please think twice before running the command.

```
hollaex server --terminate --kube
```

Completely terminating the exchange on Kubernetes. The terminated exchange can't be recovered. Please think twice before running the command.

```
hollaex web --terminate
```

Completely terminating the exchange web server.

```
hollaex web --terminate --kube
```

Completely terminating the exchange web server on Kubernetes.

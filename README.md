
<!-- PROJECT LOGO -->
<br />
<p align="center">

  <h3 align="center">HollaEx CLI</h3>

  <p align="center">
    CLI tool to run and interact with HollaEx Kit based exchanges.
    <br />
  </p>
</p>

HollaEx CLI is a command-line tool for operating [HollaEx Kit](https://github.com/bitholla/hollaex-kit) with simple commands. Anyone even without deep knowledge on Kubernetes and Docker can play with HollaEx Kit easily with this awesome CLI.

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
      <a href="#terminating-the-exchange">Terminating the exchange</a>
    </li>
  </ol>
</details>

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

### Getting a backup and restore

```
hollaex toolbox --backup
```

Getting a exchange database backup. The backup (dump) file will be saved at the `/backups` folder at your HollaEx Kit.

To restore the backup, please check the [docs](https://docs.bitholla.com/hollaex-kit/advanced/backup-and-restore#restore).

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

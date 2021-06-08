# K3s local cluster

## Table of Contents

- [K3s local cluster](#Readme.md)
  - [Table of Contents](#table-of-contents)
- [Description](#description)
  - [Requirements](#requirements)
  - [Install](#install)
  - [Usage](#usage)
  - [Monitoring](#monitoring)
  - [Troubleshooting](#troubleshooting)
  - [License](#license)

## Description

This repo is to create a full kubernetes cluster using [k3d](https://k3d.io/) with MetalLb, prometheus, certmanager and traefik.

## Requirements

You will need on your computer

* [Docker](https://docs.docker.com/engine/install/ubuntu/)
* [Helm](https://helm.sh/docs/intro/install/#from-script)
* [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-on-linux)
* [K3d](https://k3d.io/)
* [Make](https://tldp.org/HOWTO/Software-Building-HOWTO-3.html)

## Install

Here you should document any install steps required to use this module. You should consider documenting any pre-requisites in this section too.

```console
sudo apt install make
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

## Usage

To create the cluster just run the `make` command.

```sh
make
```

## Troubleshooting

you can use the `--debug` flag to check the commands

## License

![Apache2](https://img.shields.io/github/license/dxas90/k3d-cluster)

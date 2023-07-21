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

You will need it on your computer

* [direnv](https://direnv.net/docs/installation.html)
* [docker](https://docs.docker.com/engine/install/ubuntu/)
* [jq](https://stedolan.github.io/jq/download/)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-on-linux)
* [K3d](https://k3d.io/)
* [task](https://taskfile.dev/installation/)

## Install

Here you should document any install steps required to use this module. You should consider documenting any pre-requisites in this section too.

```console
TASK_VERSION=$(curl -sL https://api.github.com/repos/go-task/task/releases/latest | jq -r ".tag_name")
wget https://github.com/go-task/task/releases/download/${TASK_VERSION}/task_linux_amd64.tar.gz
tar xf task_linux_amd64.tar.gz
install -m 0755 task ~/.local/bin/task
~/.local/bin/task init
sudo ~/.local/bin/task install-docker
task # or task all
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

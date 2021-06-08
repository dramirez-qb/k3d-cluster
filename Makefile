SHELL=/bin/bash -o pipefail
export SELF ?= $(MAKE)
DOCKER := $(shell which docker)
ENVSUBST := $(shell which envsubst)
HELM := $(shell which helm)
K3D := $(shell which k3d)
KUBECTL := $(shell which kubectl)
MKDIR := $(shell which mkdir)

RAND := $(shell date +%s | sha256sum | base64 | head -c 32 ; echo)

export CLUSTER_NAME ?= k3s
export ISSUER_EMAIL ?= yourname@gmail.com
export CURRENT_IP := $(shell hostname -I|cut -d" " -f 1)
export SHARED_PATH := ${HOME}/projects

define assert-set
	@[ -n "$($1)" ] || (echo "$(1) not defined in $(@)"; exit 1)
endef

all: k8s

k8s: create/cluster \
	install/storage \
	install/metallb \
	install/loadbalancer \
	install/monitoring \
	install/certmanager

clean: delete/cluster

create/cluster:
	$(call assert-set,CLUSTER_NAME)
	$(call assert-set,CURRENT_IP)
	$(MKDIR) -p ${SHARED_PATH}
	$(ENVSUBST) < k3d-config.yaml | cat > /tmp/k3d-config.yaml
	$(K3D) cluster create -c /tmp/k3d-config.yaml

delete/cluster: 
	$(call assert-set,CLUSTER_NAME)
	$(K3D) cluster delete ${CLUSTER_NAME}

install/certmanager: create/cluster
	$(call assert-set,HELM)
	$(HELM) repo add jetstack https://charts.jetstack.io
	$(HELM) repo update
	$(HELM) upgrade --install cert-manager jetstack/cert-manager -n infrastructure \
	--create-namespace -f k8s/cert-manager-values.yaml --wait
	$(ENVSUBST) < k8s/02_certmanager-resources.yaml | $(KUBECTL) apply -f -

install/loadbalancer: create/cluster
	$(call assert-set,KUBECTL)
	$(KUBECTL) apply -Rf k8s/03_traefik

install/metallb: create/cluster
	$(call assert-set,KUBECTL)
	$(KUBECTL) apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/namespace.yaml
	$(KUBECTL) apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/metallb.yaml
	$(KUBECTL) get secret -n metallb-system memberlist > /dev/null 2>&1 || $(KUBECTL) create secret generic -n metallb-system memberlist --from-literal=secretkey="$(shell openssl rand -base64 128)" > /dev/null 2>&1
	$(eval export CIDR_RANGE := $(shell $(DOCKER) network inspect k3d-${CLUSTER_NAME} | jq '.[0].IPAM.Config[0].Subnet'|sed 's/0/200/g'| tr -d '"'))
	$(eval export START_RANGE := $(shell echo ${CIDR_RANGE}  |sed 's/200\/24/200/g'))
	$(eval export END_RANGE := $(shell echo ${CIDR_RANGE}  |sed 's/200\/24/254/g'))
	$(ENVSUBST) < k8s/01_metallb.yaml | $(KUBECTL) apply -f -

install/monitoring: create/cluster install/storage
	$(call assert-set,KUBECTL)
	$(KUBECTL) apply -f k8s/monitoring/00_metrics-server.yaml
	$(KUBECTL) apply -f k8s/monitoring/01_monitoring.yaml
	$(KUBECTL) apply -Rf k8s/monitoring/02_kube-state-metrics
	$(KUBECTL) apply -f k8s/monitoring/02_monitoring_prometheus_alertmanager.yaml

install/storage: create/cluster
	$(call assert-set,KUBECTL)
	$(KUBECTL) apply -f k8s/00_local-path-storage.yaml

.PHONY: \
	all 

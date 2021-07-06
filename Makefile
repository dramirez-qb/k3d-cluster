SHELL=/bin/bash -o pipefail
export SELF ?= $(MAKE)
DOCKER := $(shell which docker)
ENVSUBST := $(shell which envsubst)
K3D := $(shell which k3d)
KUBECTL := $(shell which kubectl)
MKDIR := $(shell which mkdir)

RAND := $(shell date +%s | sha256sum | base64 | head -c 32 ; echo)

export CLUSTER_NAME ?= k3s
export ISSUER_EMAIL ?= yourname@gmail.com
export CURRENT_IP := $(shell hostname -I|cut -d" " -f 1)
export SHARED_PATH := /mnt/shared/

define assert-set
	@[ -n "$($1)" ] || (echo "$(1) not defined in $(@)"; exit 1)
endef

all: k8s

k8s: create/cluster \
	install/storage \
	install/metallb \
	install/external \
	install/loadbalancer \
	install/monitoring \
	install/certmanager \
	install/argocd \
	install/loadbalancer-fix
	@echo -e "\\033[1;32mCleanning cluster ${CLUSTER_NAME} events\\033[0;39m"
	@$(KUBECTL) delete events --all --all-namespaces

clean: delete/cluster

create/cluster:
	$(call assert-set,CLUSTER_NAME)
	$(call assert-set,CURRENT_IP)
	$(call assert-set,SHARED_PATH)
	@echo -e "\\033[1;32mCreating cluster ${CLUSTER_NAME} with ${SHARED_PATH} as a shared path\\033[0;39m"
	@$(MKDIR) -p ${SHARED_PATH}
	@$(ENVSUBST) < k3d-config.yaml | cat > /tmp/k3d-config.yaml
	@$(K3D) cluster list --no-headers | grep ${CLUSTER_NAME} > /dev/null 2>&1 || $(K3D) cluster create -c /tmp/k3d-config.yaml

delete/cluster:
	$(call assert-set,CLUSTER_NAME)
	@echo -e "\\033[1;32mDeleting cluster ${CLUSTER_NAME}\\033[0;39m"
	@$(K3D) cluster delete ${CLUSTER_NAME}

install/certmanager: create/cluster
	$(call assert-set,KUBECTL)
	@echo -e "\\033[1;32mInstalling cert-manager\\033[0;39m"
	@$(KUBECTL) apply -f https://github.com/jetstack/cert-manager/releases/download/v1.3.1/cert-manager.yaml --wait ; sleep 30
	@$(ENVSUBST) < k8s/02_certmanager-resources.yaml | $(KUBECTL) apply -f -

install/loadbalancer: create/cluster
	$(call assert-set,KUBECTL)
	@echo -e "\\033[1;32mInstalling traefik\\033[0;39m"
	@$(KUBECTL) apply -Rf k8s/03_traefik

install/loadbalancer-fix: create/cluster
	$(call assert-set,KUBECTL)
	@echo -e "\\033[1;32mFixing traefik deployment\\033[0;39m"
	@$(eval export INGRESSENDPOINT := $(shell $(KUBECTL) get service -n infrastructure traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'))
	@$(KUBECTL) patch deploy traefik -n infrastructure -p '[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--providers.kubernetesingress.ingressendpoint.ip=${INGRESSENDPOINT}"}]' --type json

install/metallb: create/cluster
	$(call assert-set,KUBECTL)
	@echo -e "\\033[1;32mInstalling metallb\\033[0;39m"
	@$(eval export CIDR_RANGE := $(shell $(DOCKER) network inspect k3d-${CLUSTER_NAME} | jq '.[0].IPAM.Config[0].Subnet'|sed 's/0/200/g'| tr -d '"'))
	@$(eval export START_RANGE := $(shell echo ${CIDR_RANGE}  |sed 's/200\/24/200/g'))
	@$(eval export END_RANGE := $(shell echo ${CIDR_RANGE}  |sed 's/200\/24/254/g'))
	@$(ENVSUBST) < k8s/01_metallb.yaml | $(KUBECTL) apply -f -
	@$(KUBECTL) get secret -n metallb-system memberlist > /dev/null 2>&1 || $(KUBECTL) create secret generic -n metallb-system memberlist --from-literal=secretkey="$(shell openssl rand -base64 128)" > /dev/null 2>&1

install/monitoring: create/cluster install/storage
	$(call assert-set,KUBECTL)
	@echo -e "\\033[1;32mInstalling Prometheus, metrics-server and kube-state-metrics\\033[0;39m"
	@$(KUBECTL) apply -f k8s/monitoring/00_metrics-server.yaml
	@$(KUBECTL) apply -f k8s/monitoring/01_monitoring.yaml
	@$(KUBECTL) apply -Rf k8s/monitoring/02_kube-state-metrics
	@$(KUBECTL) apply -f k8s/monitoring/02_monitoring_prometheus_alertmanager.yaml

install/storage: create/cluster
	$(call assert-set,KUBECTL)
	@echo -e "\\033[1;32mInstalling local-path-storage\\033[0;39m"
	@$(KUBECTL) apply -f k8s/00_local-path-storage.yaml

install/external: create/cluster
	$(call assert-set,KUBECTL)
	@echo -e "\\033[1;32mInstalling external stuff\\033[0;39m"
	@$(KUBECTL) apply -f k8s/03_external.yaml

install/argocd: create/cluster
	$(call assert-set,KUBECTL)
	@echo -e "\\033[1;32mInstalling argocd stuff\\033[0;39m"
	@$(KUBECTL) create namespace argocd
	@$(KUBECTL) apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.0.4/manifests/install.yaml
	@$(KUBECTL) apply -f k8s/04_argocd.yaml
	@echo "\\033[1;32mkubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d\\033[0;39m"
	@$(KUBECTL) patch deploy argocd-server -n argocd -p '[{"op": "add", "path": "/spec/template/spec/containers/0/command/-", "value": "--insecure"}]' --type json

.PHONY: \
	all

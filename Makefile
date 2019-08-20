# Cluster management tools.

export CLUSTER_NAME ?= $(shell cat tmp/current 2>/dev/null || echo $$(whoami)-dev)
export DISK_SIZE ?= 100
export MAX_NODES ?= 10

# EKS specific options
export EC2_VM ?= t2.nano
export EC2_REGION ?= eu-west-1

OK_COLOR=\033[32;01m
tmp:
	mkdir tmp

HAS_KUBECTL := $(shell command -v kubectl;)
HAS_AWSCLI := $(shell command -v aws;)
HAS_EKSCTL := $(shell command -v eksctl;)

.PHONY: deps
deps:
	@# Required auth and binaries for EKS
ifndef HAS_AWSCLI
	sudo pip install awscli
endif
	@if [ ! -f ~/.aws/credentials ]; then \
		aws configure; \
	fi
ifndef HAS_EKSCTL
	curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
	sudo mv /tmp/eksctl /usr/local/bin
endif
ifndef HAS_KUBECTL
	curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
	chmod +x ./kubectl
	sudo mv ./kubectl /usr/local/bin/kubectl
endif

.PHONY: create
create: deps
	@# Create an EKS cluster on AWS
	@# Options
	@#     CLUSTER_NAME    :: ${CLUSTER_NAME}
	@#     EC2_VM          :: ${EC2_VM}
	@#     EC2_REGION      :: ${EC2_REGION}
	@#     DISK_SIZE       :: ${DISK_SIZE}
	@#     MAX_NODES       :: ${MAX_NODES}

	eksctl create cluster \
		--name $(CLUSTER_NAME) \
		--asg-access \
		--full-ecr-access \
		--nodes 1 \
		--nodes-min 1 \
		--nodes-max $(MAX_NODES) \
		--node-type $(EC2_VM) \
		--node-volume-size $(DISK_SIZE) \
		--max-pods-per-node 250 \
		--region $(EC2_REGION) \
		--set-kubeconfig-context

.PHONY: delete
delete: deps
	@# Delete an EKS cluster on AWS
	@# Options
	@#     CLUSTER_NAME    :: ${CLUSTER_NAME}
	@#     EC2_REGION      :: ${EC2_REGION}

	eksctl delete cluster \
		--name $(CLUSTER_NAME) \
		--region $(EC2_REGION)

.PHONY: help
help: SHELL := /bin/bash
help:
	@# Output all targets available.
	@ echo "Available targets:"
	@ echo ""
	@ eval "echo \"$$(grep -h -B1 $$'^\t@#' $(MAKEFILE_LIST) \
		| sed 's/@#//' \
		| awk \
			-v NO_COLOR="$(NO_COLOR)" \
			-v OK_COLOR="$(OK_COLOR)" \
			-v RS="--\n" \
			-v FS="\n" \
			-v OFS="@@" \
			'{ split($$1,target,":"); $$1=""; printf "  \x1b[32;01m%-35s\x1b[0m %s\n", target[1], $$0  }' \
		| sort \
		| awk \
			-v FS="@@" \
			-v OFS="\n" \
			'{ CMD=$$1; $$1=""; print CMD $$0 }')\""

.DEFAULT_GOAL := help
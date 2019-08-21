.SILENT:
# COLORS http://invisible-island.net/xterm/xterm.faq.html#other_versions
RED  := $(shell tput -Txterm setaf 1)
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
MAGENTA  := $(shell tput -Txterm setaf 5)
CYAN  := $(shell tput -Txterm setaf 6)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)


###
# K8s Cluster specific options
export CLUSTER_NAME ?= $(shell cat /tmp/current 2>/dev/null || echo $$(whoami)-dev)
export DISK_SIZE ?= 100
export MAX_NODES ?= 2
export MIN_NODES ?= 1
export EC2_VM ?= t2.nano
export EC2_REGION ?= eu-west-1
export PROFILE ?= default

HAS_KUBECTL := $(shell command -v kubectl;)
HAS_AWSCLI := $(shell command -v aws;)
HAS_EKSCTL := $(shell command -v eksctl;)
###

.DEFAULT_GOAL := help

.PHONY : help

## Perpare Machine for EKS 
prepare:
	@# Required auth and binaries for EKS
ifndef HAS_AWSCLI
	pip install awscli
endif
	@if [ ! -f ~/.aws/credentials ]; then \
		aws configure; \
	fi
ifndef HAS_EKSCTL
	curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
	mv /tmp/eksctl /usr/local/bin
endif
ifndef HAS_KUBECTL
	curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
	chmod +x ./kubectl
	mv ./kubectl /usr/local/bin/kubectl
endif

## Show EKS cluster info
info:
	@echo 	CLUSTER_NAME    	:: ${CLUSTER_NAME}
	@echo 	EC2_VM    	     	:: ${EC2_VM}
	@echo 	EC2_REGION      	:: ${EC2_REGION}
	@echo 	DISK_SIZE       	:: ${DISK_SIZE}
	@echo 	MIN_NODES       	:: ${MIN_NODES}
	@echo 	MAX_NODES       	:: ${MAX_NODES}
	@echo 	PROFILE       	    :: ${PROFILE}
## Create an EKS cluster on AWS
create:
	eksctl create cluster \
		--name $(CLUSTER_NAME) \
		--asg-access \
		--full-ecr-access \
		--nodes $(MIN_NODES) \
		--nodes-min $(MIN_NODES) \
		--nodes-max $(MAX_NODES) \
		--node-type $(EC2_VM) \
		--node-volume-size $(DISK_SIZE) \
		--max-pods-per-node 10 \
		--region $(EC2_REGION) \
		--profile $(PROFILE) \
		--set-kubeconfig-context

## Destroy EKS cluster on AWS
destroy:
	eksctl delete cluster \
		--name $(CLUSTER_NAME) \
		--profile $(PROFILE) \
		--region $(EC2_REGION)

################################################################################
# Help
################################################################################

TARGET_MAX_CHAR_NUM=25
## Show help
help:
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "  ${YELLOW}%-$(TARGET_MAX_CHAR_NUM)s${RESET} ${GREEN}%s${RESET}\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST)

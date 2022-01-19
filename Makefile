PROJECT="freeman"
BINARY="freeman"
BUILDTIME=`date '+%Y%m%d%H%M'`
DOCKERDATA="/data/docker/data"
DOCKERNET="docker_net"
DOCKERHUB=""
KUBETARGET=""

LDFLAGS=-ldflags "-w -s -X gitlab.xsjcs.cn/tc-fwk/tcgo/util/version.ReleaseVersion=`git describe --tags --dirty --always` \
	-X gitlab.xsjcs.cn/tc-fwk/tcgo/util/version.GitHash=`git rev-parse HEAD` \
	-X gitlab.xsjcs.cn/tc-fwk/tcgo/util/version.GitBranch=`git rev-parse --abbrev-ref HEAD` \
	-X gitlab.xsjcs.cn/tc-fwk/tcgo/util/version.BuildTime=`date '+%Y-%m-%dT%H:%M:%S'`" -trimpath

swagger: ## Make swagger API doc
	swagger generate spec -o addon/doc/swagger.json
	docker run --rm -it -p 8080:8080 -e SWAGGER_JSON=/app/swagger.json -v ${PWD}/addon/doc:/app swaggerapi/swagger-ui

kube_apply: ## Apply kubernetes kustomization. Args: KUBETARGET=qa
	kubectl apply -k addon/deploy/kube/overlays/${KUBETARGET}

docker_push: ## Push docker image to registry
	DOCKER_BUILDKIT=1 docker build -t ${PROJECT}/${BINARY}:latest -f addon/deploy/Dockerfile .
	docker tag ${PROJECT}/${BINARY}:latest ${DOCKERHUB}/${BINARY}:${BUILDTIME}
	docker push ${DOCKERHUB}/${BINARY}:${BUILDTIME}

docker_build: ## Build docker image
	docker build -t ${PROJECT}/${BINARY}:${BUILDTIME} -f addon/deploy/Dockerfile .

docker_run: ## Run docker image
	docker run --rm -it --network ${DOCKERNET} -p 8000-8003:8000-8003 --name ${PROJECT} \
	    -v ${PWD}/addon/configs/${PROJECT}.yaml:/app/${PROJECT}.yaml \
	    ${PROJECT}/${BINARY}:latest

docker_init: ## Init docker env
	mkdir -p ${DOCKERDATA} && cd ${DOCKERDATA} && mkdir mysql redis consul jaeger prometheus grafana && cd -
	docker network create -d bridge ${DOCKERNET}

docker_prepare: ## Prepare docker services
	docker run -d --network ${DOCKERNET} --name mysql -v ${DOCKERDATA}/mysql:/var/lib/mysql -p 3306:3306 -e MYSQL_ALLOW_EMPTY_PASSWORD=yes -e MYSQL_DATABASE=${PROJECT} -d mysql:5.7
	docker run -d --network ${DOCKERNET} --name redis -v ${DOCKERDATA}/redis:/data -p 6379:6379 redis redis-server --appendonly yes
	docker run -d --network ${DOCKERNET} --name consul -v ${DOCKERDATA}/consul:/consul/data -p 8500:8500 consul agent -server -ui -node=server-1 -bootstrap-expect=1 -client=0.0.0.0
	docker run -d --network ${DOCKERNET} --name jaeger -v ${DOCKERDATA}/jaeger:/badger -p 16686:16686 -p 5775:5775/udp -e SPAN_STORAGE_TYPE=badger -e BADGER_EPHEMERAL=false -e BADGER_DIRECTORY_VALUE=/badger/data -e BADGER_DIRECTORY_KEY=/badger/key -e COLLECTOR_ZIPKIN_HTTP_PORT=9411 jaegertracing/all-in-one:1.18
	docker run -d --network ${DOCKERNET} --name prometheus -v ${DOCKERDATA}/prometheus:/prometheus -p 9090:9090 -v ${PWD}/addon/deploy/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
	docker run -d --network ${DOCKERNET} --name grafana -v ${DOCKERDATA}/grafana:/var/lib/grafana -p 3000:3000 grafana/grafana

docker_clean: ## Clean docker services
	docker kill mysql redis consul jaeger prometheus grafana
	docker rm mysql redis consul jaeger prometheus grafana

run: ## Run
	go run cmd/${BINARY}/main.go

build: ## Build
	GOARCH=amd64 CGO_ENABLED=0 go build ${LDFLAGS} -o bin/${BINARY}.${BUILDTIME} cmd/${BINARY}/main.go

linux_inner: ## Build for linux(inner server)
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build ${LDFLAGS} -o bin/${PROJECT}.${BUILDTIME} cmd/innerserver/main.go

linux_outer: ## Build for linux(outer server)
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build ${LDFLAGS} -o bin/${PROJECT}.${BUILDTIME} cmd/outerserver/main.go

windows_inner: ## Build for windows(inner server)
	GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build ${LDFLAGS} -o bin/${BINARY}.${BUILDTIME}.exe cmd/innerserver/main.go

windows_outer: ## Build for windows
	GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build ${LDFLAGS} -o bin/${BINARY}.${BUILDTIME}.exe cmd/outerserver/main.go

check: test lint vet ## Run tests, lint and vet

test: ## Run tests
	go test -race -v $(shell go list ./... | grep -v /vendor/)

format: ## Format code
	go fmt ./...
	goimports -w .

lint: ## Lint files
	go list ./... | grep -v /vendor/ | xargs -L1 golint -set_exit_status

vet: ## Run the vet tool
	go vet $(shell go list ./... | grep -v /vendor/)

clean: ## Clean up build artifacts
	go clean

help: ## Display this help message
	@cat $(MAKEFILE_LIST) | grep -e "^[a-zA-Z_\-]*: *.*## *" | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help

.SILENT: run build linux_inner linux_outer windows_inner windows_outer  test format lint vet clean help

.PHONY: all test clean run docker build linux_inner windows_outer windows_inner windows_outer

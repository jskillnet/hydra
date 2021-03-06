SHELL=/bin/bash -o pipefail

# Runs full test suite including tests where databases are enabled
.PHONY: test
test:
		docker kill hydra_test_database_mysql || true
		docker kill hydra_test_database_postgres || true
		docker rm -f hydra_test_database_mysql || true
		docker rm -f hydra_test_database_postgres || true
		docker run --rm --name hydra_test_database_mysql -p 3444:3306 -e MYSQL_ROOT_PASSWORD=secret -d mysql:5.7
		docker run --rm --name hydra_test_database_postgres -p 3445:5432 -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=hydra -d postgres:9.6
		make sqlbin
		TEST_DATABASE_MYSQL='root:secret@(127.0.0.1:3444)/mysql?parseTime=true' \
			TEST_DATABASE_POSTGRESQL='postgres://postgres:secret@127.0.0.1:3445/hydra?sslmode=disable' \
			go-acc ./... -- -failfast -timeout=20m
		docker rm -f hydra_test_database_mysql
		docker rm -f hydra_test_database_postgres

# Resets the test databases
.PHONY: test-resetdb
test-resetdb:
		docker kill hydra_test_database_mysql || true
		docker kill hydra_test_database_postgres || true
		docker rm -f hydra_test_database_mysql || true
		docker rm -f hydra_test_database_postgres || true
		docker run --rm --name hydra_test_database_mysql -p 3444:3306 -e MYSQL_ROOT_PASSWORD=secret -d mysql:5.7
		docker run --rm --name hydra_test_database_postgres -p 3445:5432 -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=hydra -d postgres:9.

# Runs tests in short mode, without database adapters
.PHONY: docker
docker:
		GO111MODULE=on GOOS=linux GOARCH=amd64 go build && docker build -t oryd/hydra:latest .
		rm hydra

# Runs tests in short mode, without database adapters
.PHONY: quicktest
quicktest:
		go test -failfast -short ./...

# Formats the code
.PHONY: format
format:
		goreturns -w -local github.com/ory $$(listx .)

# Generates mocks
.PHONY: mocks
mocks:
		mockgen -package oauth2_test -destination oauth2/oauth2_provider_mock_test.go github.com/ory/fosite OAuth2Provider
		mockgen -mock_names Provider=MockConfiguration -package internal -destination internal/configuration_provider_mock.go github.com/ory/hydra/driver/configuration Provider
		mockgen -mock_names Registry=MockRegistry -package internal -destination internal/registry_mock.go github.com/ory/hydra/driver Registry


# Adds sql files to the binary using go-bindata
.PHONY: sqlbin
sqlbin:
		cd client; go-bindata -o sql_migration_files.go -pkg client ./migrations/sql/...
		cd consent; go-bindata -o sql_migration_files.go -pkg consent ./migrations/sql/...
		cd jwk; go-bindata -o sql_migration_files.go -pkg jwk ./migrations/sql/...
		cd oauth2; go-bindata -o sql_migration_files.go -pkg oauth2 ./migrations/sql/...

# Runs all code generators
.PHONY: gen
gen: mocks sqlbin sdk

# Generates the SDKs
.PHONY: sdk
sdk:
		GO111MODULE=on go mod tidy
		GO111MODULE=on go mod vendor
		GO111MODULE=off swagger generate spec -m -o ./docs/api.swagger.json
		GO111MODULE=off swagger validate ./docs/api.swagger.json

		rm -rf ./sdk/go/hydra
		rm -rf ./sdk/js/swagger
		rm -rf ./sdk/php/swagger
		rm -rf ./sdk/java

		mkdir ./sdk/go/hydra

		GO111MODULE=off swagger generate client -f ./docs/api.swagger.json -t sdk/go/hydra -A Ory_Hydra
		java -jar scripts/swagger-codegen-cli-2.2.3.jar generate -i ./docs/api.swagger.json -l javascript -o ./sdk/js/swagger
		java -jar scripts/swagger-codegen-cli-2.2.3.jar generate -i ./docs/api.swagger.json -l php -o sdk/php/ \
			--invoker-package Hydra\\SDK --git-repo-id swagger --git-user-id ory --additional-properties "packagePath=swagger,description=Client for Hydra"
		java -DapiTests=false -DmodelTests=false -jar scripts/swagger-codegen-cli-2.2.3.jar generate \
			--input-spec ./docs/api.swagger.json \
			--lang java \
			--library resttemplate \
			--group-id com.github.ory \
			--artifact-id hydra-client-resttemplate \
			--invoker-package com.github.ory.hydra \
			--api-package com.github.ory.hydra.api \
			--model-package com.github.ory.hydra.model \
			--output ./sdk/java/hydra-client-resttemplate

		cd sdk/go; goreturns -w -i -local github.com/ory $$(listx .)

		rm -f ./sdk/js/swagger/package.json
		rm -rf ./sdk/js/swagger/test
		rm -f ./sdk/php/swagger/composer.json ./sdk/php/swagger/phpunit.xml.dist
		rm -rf ./sdk/php/swagger/test
		rm -rf ./vendor

.PHONY: install-stable
install-stable:
		HYDRA_LATEST=$$(git describe --abbrev=0 --tags)
		git checkout $$HYDRA_LATEST
		GO111MODULE=on go install \
				-ldflags "-X github.com/ory/hydra/cmd.Version=$$HYDRA_LATEST -X github.com/ory/hydra/cmd.Date=`TZ=UTC date -u '+%Y-%m-%dT%H:%M:%SZ'` -X github.com/ory/hydra/cmd.Commit=`git rev-parse HEAD`" \
				.
		git checkout master

.PHONY: install
install:
		GO111MODULE=on go install .

-include .env

# update this to version you want
PLANTUML_VERSION ?= 1.2024.7
LAMBDA_POWER_TOOLS_LAYER_VERSION ?= 78

AWS_ACCT ?= 000000000000
AWS_REGION ?= us-east-1
API_KEY ?= WootWootWoot
LAMBDA_NAME ?= plantuml

JAR_DOWNLOAD_URL = https://github.com/plantuml/plantuml/releases/download/v$(PLANTUML_VERSION)/plantuml-$(PLANTUML_VERSION).jar
S3_BUCKET_NAME = $(LAMBDA_NAME)-lambda-layer
PLATFORM = linux/arm64
LAMBDA_ROLE_NAME = $(LAMBDA_NAME)-role
LAYER_NAME = $(LAMBDA_NAME)-layer

AWS_CMD = aws --no-cli-pager --region $(AWS_REGION)
LAYER_VERSION = $(shell $(AWS_CMD) lambda list-layer-versions --layer-name $(LAYER_NAME) --query 'LayerVersions[0].Version' --output text)
LAMBDA_URL = $(shell $(AWS_CMD) lambda get-function-url-config --function-name $(LAMBDA_NAME) | jq -rc '.FunctionUrl')
LAYER_ARN = $(shell $(AWS_CMD) lambda list-layer-versions --layer-name $(LAYER_NAME) | jq -rc '.LayerVersions[0].LayerVersionArn')
POWERTOOLS_LAYER_ARN=arn:aws:lambda:$(AWS_REGION):017000801446:layer:AWSLambdaPowertoolsPythonV2-Arm64:$(LAMBDA_POWER_TOOLS_LAYER_VERSION)
ZIP_FILE = lambda.zip


.PHONY: deploy
deploy: create-lambda-function

.PHONY: clean
clean:
	rm -f *.zip
	rm -f src/*.zip
	rm -f layer/*.zip
	rm -f test-diagram.svg

.PHONY: delete-lambda-role
delete-lambda-role:
	aws iam detach-role-policy --role-name $(LAMBDA_ROLE_NAME) --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
	aws iam delete-role --role-name $(LAMBDA_ROLE_NAME)

.PHONY: delete-lambda-function build package delete-lambda create-lambda update-lambda get-lambda-url it-again
delete-lambda-function:
	aws lambda delete-function --function-name $(LAMBDA_NAME)

.PHONY: delete-lambda-layer build package delete-lambda create-lambda update-lambda get-lambda-url it-again
delete-lambda-layer:
	aws lambda delete-layer-version --layer-name $(LAYER_NAME) --version-number $(LAYER_VERSION)

.PHONY: delete-lambda
delete-lambda: delete-lambda-function delete-lambda-role

# delete S3 bucket for lambda layer
.PHONY: delete-s3-bucket
delete-s3-bucket:
	aws s3 rb s3://$(S3_BUCKET_NAME) --force

# delete all resources
.PHONY: destroy
destroy: delete-lambda delete-lambda-layer delete-s3-bucket

.PHONY: create-lambda-role
create-lambda-role:
	aws iam create-role --role-name $(LAMBDA_ROLE_NAME) --assume-role-policy-document file://lambda-role-trust-policy.json --no-cli-pager
	aws iam attach-role-policy --role-name $(LAMBDA_ROLE_NAME) --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole --no-cli-pager

# create S3 bucket for lambda layer
.PHONY: create-s3-bucket
create-s3-bucket:
	$(AWS_CMD) s3 mb s3://$(S3_BUCKET_NAME)

# build lambda using docker
.PHONY: clean
build-lambda: clean
	cd src && make

# build lambda layer using docker
.PHONY: build-lambda-layer
build-lambda-layer:
	cd layer && make

# upload layer to S3
.PHONY: update-bucket-layer
update-bucket-layer: build-lambda-layer
	$(AWS_CMD) s3 cp ./layer/java-layer.zip s3://$(S3_BUCKET_NAME)/java-layer.zip

.PHONY: get-lambda-url
get-lambda-url:
	@echo $(LAMBDA_URL)

.PHONY: get-lambda-config
get-lambda-config:
	$(AWS_CMD) lambda get-function-configuration --function-name $(LAMBDA_NAME) | jq

.PHONY: get-lambda-env
get-lambda-env:
	$(AWS_CMD) lambda get-function-configuration --function-name $(LAMBDA_NAME) | jq '.Environment.Variables'

# create new lambda layer version using S3 bucket
.PHONY: create-lambda-layer
create-lambda-layer: update-bucket-layer
	$(AWS_CMD) lambda publish-layer-version \
		--layer-name $(LAYER_NAME) \
		--description "Layer containing OpenJDK JRE and PlantUML" \
		--license-info "Apache-2.0" \
    	--content S3Bucket=$(S3_BUCKET_NAME),S3Key=java-layer.zip \
		--compatible-runtimes python3.10 python3.11 \
		--compatible-architectures arm64

.PHONY: create-lambda-function
create-lambda-function: create-lambda-role update-bucket-layer build-lambda
	$(AWS_CMD) lambda create-function --function-name $(LAMBDA_NAME) \
	  --architectures arm64 \
	  --handler handler.lambda_handler \
	  --zip-file fileb://./src/$(ZIP_FILE) \
	  --runtime python3.11 \
	  --timeout 30 \
	  --memory-size 1024 \
	  --role arn:aws:iam::$(AWS_ACCT):role/$(LAMBDA_ROLE_NAME) \
	  --environment "Variables={LOG_LEVEL=INFO, API_KEY=${API_KEY}}"

	# wait for lambda to be created
	sleep 5

	# add layer to lambda
	$(AWS_CMD) lambda update-function-configuration --function-name $(LAMBDA_NAME) \
		--layers $(LAYER_ARN) $(POWERTOOLS_LAYER_ARN)


	# create function URL config
	$(AWS_CMD) lambda create-function-url-config --function-name $(LAMBDA_NAME) \
		--cors '{"AllowOrigins": ["*"], "AllowMethods": ["POST"], "AllowHeaders": ["X-API-KEY"]}' \
		--auth-type NONE

	# add permission to lambda to allow public url access
	$(AWS_CMD) lambda add-permission \
		--function-name $(LAMBDA_NAME) \
		--function-url-auth-type NONE \
		--statement-id FunctionURLAllowPublicAccess \
		--action lambda:InvokeFunctionUrl \
		--principal '*'

	@echo $(LAMBDA_URL)

# update lambda with new code and layer version
.PHONY: update-lambda-and-layer-version
update-lambda-and-layer-version: update-lambda update-lambda-layer-version

# update lambda with new code
.PHONY: update-lambda
update-lambda: build-lambda
	$(AWS_CMD) lambda update-function-code --function-name $(LAMBDA_NAME) \
	--zip-file fileb://./src/$(ZIP_FILE)

# update lambda with new layer version
.PHONY: update-lambda-layer-version
update-lambda-layer-version: create-lambda-layer
	$(AWS_CMD) lambda update-function-configuration --function-name $(LAMBDA_NAME) \
		--layers $(LAYER_ARN) $(POWERTOOLS_LAYER_ARN)

# post puml to lambda url to get png
.PHONY: post-lambda-url-png
post-lambda-url-png:
	@curl -X POST $(LAMBDA_URL)?format=png \
	-H 'Content-Type: text/plain' \
	-H 'X-API-Key: $(API_KEY)' \
	--data-binary @./test-diagram.puml > test-diagram.png

# post puml to lambda url to get svg
.PHONY: post-lambda-url
post-lambda-url:
	@curl -X POST $(LAMBDA_URL) \
	-H 'Content-Type: text/plain' \
	-H 'X-API-Key: $(API_KEY)' \
	--data-binary @./test-diagram.puml > test-diagram.svg

# post puml to lambda url to get svg
.PHONY: post-lambda-url-c4
post-lambda-url-c4:
	@curl -X POST $(LAMBDA_URL) \
	-H 'Content-Type: text/plain' \
	-H 'X-API-Key: $(API_KEY)' \
	--data-binary @./test-diagram-c4.puml > test-diagram.svg

# post puml to lambda url to get svg
.PHONY: post-lambda-url-aws
post-lambda-url-aws:
	@curl -X POST $(LAMBDA_URL) \
	-H 'Content-Type: text/plain' \
	-H 'X-API-Key: $(API_KEY)' \
	--data-binary @./test-diagram-aws.puml > test-diagram.svg

# post puml to lambda url to get svg
.PHONY: post-lambda-url-icons
post-lambda-url-icons:
	@curl -X POST $(LAMBDA_URL) \
	-H 'Content-Type: text/plain' \
	-H 'X-API-Key: $(API_KEY)' \
	--data-binary @./test-diagram-icons.puml > test-diagram.svg

.PHONY: it-again
it-again: update-lambda update-lambda-layer-version

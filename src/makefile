.PHONY: build clean

# Target platform
PLATFORM ?= linux/arm64

# Name of the Docker image
IMAGE_NAME=plantuml_lambda

# Name of the container used for packaging the layer
CONTAINER_NAME=plantuml_lambda

build: clean
	# Build the Docker image with target platform
	docker build --platform $(PLATFORM) -t $(IMAGE_NAME) .
	# Create a container from the image
	docker create --name $(CONTAINER_NAME) $(IMAGE_NAME)
	# Copy the packaged layer ZIP from the container
	docker cp $(CONTAINER_NAME):/lambda/lambda.zip .
	# Cleanup: Stop and remove the container
	docker rm -f $(CONTAINER_NAME)

clean:
	# Remove the Docker image
	docker rmi -f $(IMAGE_NAME)
	# Remove the local zip file
	rm -f lambda.zip

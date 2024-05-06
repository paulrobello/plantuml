.PHONY: all download_jar build clean

# Target platform
PLATFORM ?= linux/arm64

JAR_DOWNLOAD_URL ?= https://github.com/plantuml/plantuml/releases/download/v1.2024.4/plantuml-1.2024.4.jar

# Name of the Docker image
IMAGE_NAME = plantuml_lambda_layer

# Name of the container used for packaging the layer
CONTAINER_NAME = plantuml_lambda_layer

all: clean build

download_jar:
	if [ ! -f plantuml.jar ]; then \
		curl -L -o plantuml.jar $(JAR_DOWNLOAD_URL); \
	fi

build: download_jar
	# Build the Docker image with target platform
	docker build --platform $(PLATFORM) -t $(IMAGE_NAME) .
	# Create a container from the image
	docker create --name $(CONTAINER_NAME) $(IMAGE_NAME)
	# Copy the packaged layer ZIP from the container
	docker cp $(CONTAINER_NAME):/lambda-layer/java-layer.zip .
	# Cleanup: Stop and remove the container
	docker rm -f $(CONTAINER_NAME)

clean:
	# Remove the Docker image
	docker rmi -f $(IMAGE_NAME)
	# Remove the local zip file
	rm -f java-layer.zip

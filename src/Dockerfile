# Use an Amazon Linux base image that is similar to the Lambda execution environment
FROM amazonlinux:2

RUN yum install -y zip

# Setup the directory structure for the Lambda layer
WORKDIR /lambda

# Add your plantuml.jar or other necessary files
COPY *.py /lambda

# Package the layer
RUN zip -r lambda.zip *

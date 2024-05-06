# Use an Amazon Linux base image that is similar to the Lambda execution environment
FROM amazonlinux:2

RUN yum -y update

# Install OpenJDK 11 JRE
RUN yum install -y zip gzip tar curl find java-11-amazon-corretto-headless && \
    yum install -y make gcc gcc-c++ && \
    yum clean all && \
    rm -rf /var/cache/yum

# Setup the directory structure for the Lambda layer
WORKDIR /lambda-layer

# AWS Lambda expects the runtime in the 'java/lib' folder for Java layers
# Copy the JRE into the layer, adjust paths as necessary
RUN mkdir -p java/lib && cp -rp /usr/lib/jvm/java-11-amazon-corretto/* java/lib/

# Add your plantuml.jar or other necessary files
COPY plantuml.jar /lambda-layer/java/lib/

RUN curl https://gitlab.com/api/v4/projects/4207231/packages/generic/graphviz-releases/11.0.0/graphviz-11.0.0.tar.gz | tar -xz
RUN cd graphviz-11.0.0 && \
    ./configure --enable-static --disable-shared --prefix=/lambda-layer/local && \
    make && make install && \
    cd .. && rm -rf graphviz-11.0.0 && \
    rm -rf /lambda-layer/local/lib
#RUN     find /lambda-layer/ -name 'gvpr' -delete
RUN     find /lambda-layer/ -name 'gvpack' -delete
RUN     find /lambda-layer/ -name '*.la' -delete
RUN     find /lambda-layer/ -name '*.a' -delete
RUN     find /lambda-layer/ -name '*.zip' -delete
RUN     mv /lambda-layer/local/bin/dot_static /lambda-layer/local/bin/dot

# Package the layer
RUN zip -r java-layer.zip . -x "*man/*" "*doc/*" "*legal/*" "*jmods/*" "*include/*" "*share/*"

FROM jenkins/jenkins:lts

USER root

# Installation de bash, docker CLI, curl, git et maven
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    git \
    maven \
    docker-ce-cli \
    openjdk-17-jdk \
 && apt-get clean

USER jenkins

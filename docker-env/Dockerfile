FROM jenkins/jenkins:lts


USER root

RUN apt-get update && apt-get install -y \
    maven \
    git \
    openjdk-17-jdk \
    && apt-get clean


WORKDIR /workspace


RUN java -version && mvn -version && git --version

USER jenkins


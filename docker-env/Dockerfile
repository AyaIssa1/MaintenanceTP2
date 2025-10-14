# Image de base Ubuntu
FROM ubuntu:22.04

# Installer Maven, JDK et Git
RUN apt-get update && apt-get install -y \
    maven \
    openjdk-17-jdk \
    git \
 && apt-get clean

# Creer un repertoire de travail
WORKDIR /workspace

# Verifie les versions
RUN java -version && mvn -version && git --version

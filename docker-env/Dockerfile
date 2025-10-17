# Utiliser l'image Jenkins officielle comme base
FROM jenkins/jenkins:lts

USER root

# Installation des outils nécessaires
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    git \
    maven \
    docker.io \
    openjdk-17-jdk \
 && apt-get clean

# Donner les droits à Jenkins d'utiliser Docker
RUN usermod -aG docker jenkins

USER jenkins


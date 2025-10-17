# Utiliser l'image Jenkins officielle comme base
FROM jenkins/jenkins:lts-jdk17

USER root

# Installation des outils nécessaires
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    git \
    maven \
    docker.io \
 && apt-get clean

# Donner les droits à Jenkins d'utiliser Docker
RUN usermod -aG docker jenkins

USER jenkins

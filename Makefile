# Variables globales
IMG = maintenance-env:base
NAME = maintenance-test

# =====================
# COMMANDES DE BASE
# =====================

# Build l'image Docker
build:
	docker build -t $(IMG) ./docker-env

# Run le conteneur
run:
	docker run -d --name $(NAME) $(IMG) tail -f /dev/null

# Ouvre un shell dans le conteneur
exec:
	docker exec -it $(NAME) bash

# Stoppe et supprime le conteneur
stop:
	- docker stop $(NAME)
	- docker rm $(NAME)

# Test Maven dans le conteneur
test:
	docker run --rm $(IMG) mvn -v

# Restart complet
restart: stop build run

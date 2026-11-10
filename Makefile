# Test container mimicking a G100 login node. The user is read from inventory.local (host "docker").
IMAGE := g100-test
PORT  := 2222
USERNAME = $(shell uv run ansible-inventory --host docker | python3 -c 'import json,sys; print(json.load(sys.stdin)["ansible_user"])')

.PHONY: build up down ping test

build:
	docker build -t $(IMAGE) --build-arg USERNAME=$(USERNAME) docker

up: build
	-docker rm -f $(IMAGE) >/dev/null 2>&1
	docker run -d --name $(IMAGE) -p 127.0.0.1:$(PORT):22 \
		-e AUTHORIZED_KEYS="$$( (ssh-add -L 2>/dev/null; cat ~/.ssh/*.pub) | grep -v -e -cert- )" $(IMAGE)

down:
	docker rm -f $(IMAGE)

ping:
	uv run ansible docker -m ping

# Idempotence: converge twice, the second run must report changed=0 and failed=0
test: up
	uv run ansible-playbook site.yml -l docker
	uv run ansible-playbook site.yml -l docker | tee /dev/stderr | grep -E 'changed=0 .*failed=0' >/dev/null

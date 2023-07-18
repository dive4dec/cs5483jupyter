SHELL:= /bin/bash
activate_conda = source /opt/conda/bin/activate && conda activate jlite
# Registry for docker images
REGISTRY=localhost:32000
# REGISTRY=chungc
# version for tagging image for deployment
VERSION=0.0.2d

python_version := 3.11

nv:
	docker build \
		-t "nv" -f "nv/Dockerfile" .

docker-stacks-foundation-nv: nv
	docker build \
		--build-arg ROOT_CONTAINER="nv" \
		--build-arg PYTHON_VERSION="$(python_version)" \
		-t "docker-stacks-foundation-nv" docker-stacks/docker-stacks-foundation

base-notebook-nv: docker-stacks-foundation-nv
	docker build \
		--build-arg BASE_CONTAINER="docker-stacks-foundation-nv" \
		-t "base-notebook-nv" docker-stacks/base-notebook

minimal-notebook-nv: base-notebook-nv
	docker build \
		--build-arg BASE_CONTAINER="base-notebook-nv" \
		-t "minimal-notebook-nv" docker-stacks/minimal-notebook

scipy-notebook-nv: minimal-notebook-nv
	docker build \
		--build-arg BASE_CONTAINER="minimal-notebook-nv" \
		-t "scipy-notebook-nv" docker-stacks/scipy-notebook

push-%:
	docker tag "$*" "${REGISTRY}/$*:${VERSION}"
	docker push "${REGISTRY}/$*:${VERSION}"

# Support different interfaces such as
# VSCode, remote desktop, retrolab, ...
jupyter-interface:
	docker build --pull \
		-t "jupyter-interface" -f jupyter-interface/Dockerfile .
	docker run --rm -it  -p 8888:8888/tcp -v "$$(pwd)/jupyter-interface/examples":/home/jovyan/work jupyter-interface

# Tools for mathematics
math:
	docker build --pull \
		-t "math" -f math/Dockerfile .
	docker run --rm -it  -p 8888:8888/tcp math


# jupyter-interface programming datamining dev cds;
cs5483nb: scipy-nv
	base="scipy-nv:${VERSION}"; i=0; \
	for module in jupyter-interface; \
	do \
	stage="cs5483nb$$((++i))_$$module:${VERSION}"; \
	docker build --build-arg BASE_CONTAINER="$$base" \
		-t "$$stage" -f "$$module/Dockerfile" .; \
	base="$$stage"; \
	done; \
	docker tag "$$stage" "cs5483nb:${VERSION}"

cs5483nbg: cs5483nb
	cd cs5483-deploy/gpu && \
	docker build --build-arg BASE_CONTAINER="cs5483nb" \
		-t cs5483nbg -f "Dockerfile" .
	docker run --rm -it  -p 8888:8888/tcp cs5483nbg

# jobe: scipy-10
# 	base=scipy-10; i=0; \
# 	for module in jupyter-interface programming jobeinabox; \
# 	do \
# 	stage="jobe$$((++i))_$$module"; \
# 	docker build --build-arg BASE_CONTAINER="$$base" \
# 		-t "$$stage" -f "$$module/Dockerfile" .; \
# 	base="$$stage"; \
# 	done; \
# 	docker tag "$$stage" jobe
# 	docker run --rm -it  -p 8888:8888/tcp jobe

cs5483hub:
	cd cs5483-deploy && \
	docker build --pull \
		-t "cs5483hub" -f Dockerfile .

# cs1302ihub:
# 	cd cs1302-deploy/instructor && \
# 	docker build --pull \
# 		-t "cs1302ihub" -f Dockerfile .

nv:
	docker build \
		-t "nv" -f "nv/Dockerfile" .

scipy-nv: nv
	docker build \
		--build-arg ROOT_CONTAINER="nv" \
		--build-arg PYTHON_VERSION="3.10" \
		-t "docker-stacks-foundation-nv:${VERSION}" docker-stacks/docker-stacks-foundation
	docker build \
		--build-arg BASE_CONTAINER="docker-stacks-foundation-nv:${VERSION}" \
		-t "base-notebook-nv:${VERSION}" docker-stacks/base-notebook
	docker build \
		--build-arg BASE_CONTAINER="base-notebook-nv:${VERSION}" \
		-t "minimal-notebook-nv:${VERSION}" docker-stacks/minimal-notebook
	docker build \
		--build-arg BASE_CONTAINER="minimal-notebook-nv:${VERSION}" \
		-t "scipy-nv:${VERSION}" docker-stacks/scipy-notebook

jl-source: jl-clean-source jl-build-source

jl-release: jl-clean-release jl-build-release jl-page

jl-clean-release:
	rm -rf _release .jupyterlite.doit.db
    
jl-clean-source:
	rm -rf _source .jupyterlite.doit.db

jl-build-release:
	# run jlite twice to get wtc setup
	cd jupyterlite && \
	$(activate_conda) && \
	jupyter lite build --contents=../release && \
	jupyter lite build --contents=../release && \
	python kernel2xeus_python.py && \
	python kernel2pyodide.py && \
	cp -rf _output ../_release

jl-build-source:
	cd jupyterlite && \
	$(activate_conda) && \
	jupyter lite build --contents=../source && \
	python kernel2xeus_python.py && \
	python kernel2pyodide.py && \
	cp -rf _output ../_source
    
jl-page:
	cd release && \
	$(activate_conda) && \
	ghp-import -np ../_release


modules := jobe cs5483nb cs5483nbg cs5483hub main scipy-nv nv programming jupyter-interface push manim jl jl-clean jl-build jl-page release

.PHONY: $(modules)
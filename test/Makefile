docker_base_os           = debian
docker_base_image        = ${docker_base_os}:latest

docker_build_args_extra  = # --no-cache

docker_hub_user          = $(or ${DOCKER_HUB_USER},UNNOWN_DOCKER_HUB_USER)
#^-- override this on the make(1) command line or in the environment

container_name           = provisioning-core

image_tag                = ${docker_hub_user}/${container_name}

##

all :: test

clean ::

t ::

##

build :: Dockerfile
	cd .. && docker build -f test/Dockerfile ${docker_build_args_extra} --tag "${image_tag}" .

test :: build
	docker run "${image_tag}"

push ::
	docker push "${image_tag}"

##

Dockerfile ::
	cat $@.in | perl -pe "s/[@]make:docker_base_image[@]/${docker_base_image}/" > $@

clean ::
	rm -f Dockerfile

##


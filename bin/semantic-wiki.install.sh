#!/bin/bash
## Install a semantic wiki in unattended mode on either Linux or Windows.
## 
## Installs the Bitnami Tomcat stack, Jena Fuseki, MediaWiki, and various MediaWiki extensions.
##

PATH="$(dirname "$(dirname "$0")")/libexec:${PATH}"

source semantic-wiki.installation.functions.sh

: "${technology_stack_installation_root_dpn:?}"

install_semantic_wiki "$@"


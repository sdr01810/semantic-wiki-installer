#!/bin/bash
## Entry point for the Docker container.
##

set -e

function xx() {
	echo "+" "$@"
	"$@"
}

function printenv_sorted() {
	xx printenv | xx env LC_ALL=C sort
}

##

echo
echo "Environment variables:"
xx :
printenv_sorted

xx :
xx pwd

xx :
xx ls -al

xx :
xx ls -al /opt/semantic-wiki-installer

##

case /"$-"/ in
*i*) # interactive
	xx bash -l
	;;
*)
	xx /opt/semantic-wiki-installer/bin/semantic-wiki.install.sh
	;;
esac

##


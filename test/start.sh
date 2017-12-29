#!/bin/sh
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
xx ls -al /opt/provisioning-core

##

case /"$-"/ in
*i*) # interactive
	echo
	echo "Launching a shell..."
	xx :
	xx sh -l
	;;
esac

##


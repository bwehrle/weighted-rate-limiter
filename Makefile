tests: setup
	./pongo run

setup: pongo_install
	./pongo build
	./pongo up

shutdown:
	./pongo down

pongo_install:
	[ -x pongo ] || ./scripts/install_pongo.sh


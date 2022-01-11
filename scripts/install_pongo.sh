#!/bin/sh
git clone https://github.com/Kong/kong-pongo.git ../kongo-pongo
ln -s $(realpath kong-pongo/pongo.sh) pongo

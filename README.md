[![Build Status][badge-travis-image]][badge-travis-url]

Kong Rate Limiter
====================

This repository is a copy of the code from the Kong Rate Limiter repo, modified in the following ways
* Made into external plugin & given new name
* Supports routes having a specific cost against the rate limit (>1)
* Remove support for Cassandra

#Development

This template was designed to work with the [`kong-pongo`](https://github.com/Kong/kong-pongo) system.

Tests are located in the ```spec``` directory and are run via:
```make tests```

## MacOSX
Note that on minikube (macosx), mount points require some manual changes to the Pongo scripts.

In this example, we mount the git directory, from which the github/weighted-rate-limiter is available.

* Add mount
```shell
minikube mount /Users/$username/git/:/host
```

* Change kong-pongo to use this host path
```
# kong-pongo/assets/docker-compose.yml:130
   volumes:
      - /host/github/weighted-rate-limiter:/kong-plugin
``

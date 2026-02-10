# Flowise Docker Hub Image

Starts Flowise from [DockerHub Image](https://hub.docker.com/r/flowiseai/flowise)

## Usage

1. Create `.env` file and specify the `PORT` (refer to `.env.example`)
2. `docker compose up -d`
3. Open [http://localhost:3000](http://localhost:3000)
4. You can bring the containers down by `docker compose stop`

## 🌱 Env Variables

If you like to persist your data (flows, logs, credentials, storage), set these variables in the `.env` file inside `docker` folder:

-   DATABASE_PATH=/root/.flowise
-   LOG_PATH=/root/.flowise/logs
-   SECRETKEY_PATH=/root/.flowise
-   BLOB_STORAGE_PATH=/root/.flowise/storage

Flowise also support different environment variables to configure your instance. Read [more](https://docs.flowiseai.com/configuration/environment-variables)

## Queue Mode:

### Building from source:

You can build the images for worker and main from scratch with:

```
docker compose -f docker-compose-queue-source.yml up -d
```

Monitor Health:

```
docker compose -f docker-compose-queue-source.yml ps
```

### From pre-built images:

You can also use the pre-built images:

```
docker compose -f docker-compose-queue-prebuilt.yml up -d
```

Monitor Health:

```
docker compose -f docker-compose-queue-prebuilt.yml ps
```

## Proxy Configuration

If your environment requires an HTTP/HTTPS (or SOCKS) proxy, you can configure the container by passing proxy-related environment variables when starting the container. Supported variables:

-   `PROXY_TYPE`: `http`, `https`, or `socks5`.
-   `PROXY_IP`: Proxy host (for example `host.docker.internal` when using a proxy on the host machine).
-   `PROXY_PORT`: Proxy port (for example `3128`).
-   `PROXY_USERNAME`: (optional) Username for proxy auth.
-   `PROXY_PASSWORD`: (optional) Password for proxy auth.

Example `docker run` using an HTTP proxy:

```bash
docker run -d --name flowise-cskm \
	-e PROXY_TYPE=http \
	-e PROXY_IP=host.docker.internal \
	-e PROXY_PORT=3128 \
	-p 3000:3000 \
	nexus3.devops.usu.group/kcenter/flowise-cskm:3.0.13
```

If you use `docker-compose`, add the same environment variables under the service's `environment` section.

## Build, Tag and Push

To build the Flowise image locally, tag it for your private registry (USU Nexus - nexus3.devops.usu.group), and push it, run:

```bash
# Build local image
docker build -t flowise-cskm .

# Tag for private registry (replace <TAG> with your tag, e.g. 3.0.13, LATEST)
docker tag flowise-cskm nexus3.devops.usu.group/kcenter/flowise-cskm:<TAG>

# Login to private registry with user musgitlab-build-kcenter
docker login nexus3.devops.usu.group

# Push to private registry (make sure you're logged in)
docker push nexus3.devops.usu.group/kcenter/flowise-cskm:<TAG>
```

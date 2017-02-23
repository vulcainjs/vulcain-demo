#!/bin/bash
set -ex

cluster="demo"
host=${1:-vulcain}

eval $(docker-machine env $host)
hostIp="$(docker-machine ip $host)"

# Set context
echo ">> Initializing swarm cluster as manager"
docker swarm init --advertise-addr $hostIp:2377 || true

docker node update --label-add vulcain.environment=$cluster $host

echo ">> Creating cluster network"
docker network create -d overlay --attachable --opt secure net-$cluster || true

docker stack deploy --compose-file docker-compose.yml vulcain

docker run -d -p 24244:24244 --net=host \
      --name fluentd-agent \
      -e ELASTIC_URL=$hostIp \
      -e ELASTIC_PORT=9200 \
      -e VULCAIN_ENV=$cluster \
      vulcain/fluentd:1.0.0 || true

 docker service create --name statsd-agent --network net-$cluster --mode global \
        --constraint node.labels.vulcain.environment==$cluster \
        --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock  \
        -e ENV=$cluster \
        -e INFLUXDB_SERVERS="'http://influxdb:8086'" \
        -e INFLUXDB_USER="admin" \
        -e INFLUXDB_PASSWORD="vulcain" \
        -p 8125:8125/udp \
        vulcain/telegraf:1.0.0 || true

# Register
docker rm setup || true
docker create --name setup -ti --rm -e hostIp=$hostIp -e cluster=$cluster -e token=ab690d50-e85d-11e6-b767-8f41c48a4483 vulcain/install-demo
docker cp /Users/alain/.docker/machine/machines/nuc/cert.pem setup:/certs/cert.pem
docker cp /Users/alain/.docker/machine/machines/nuc/ca.pem setup:/certs/ca.pem
docker cp /Users/alain/.docker/machine/machines/nuc/key.pem setup:/certs/key.pem
docker start -i setup

echo
echo "Environment $cluster created successfully."
echo

vulcain config --profile demo --token ab690d50-e85d-11e6-b767-8f41c48a4483 --template NodeMicroService --team vulcain-demo --server ${hostIp}:8080

echo Vulcain UI is available at http://$hostIp:8080 user: admin/vulcain

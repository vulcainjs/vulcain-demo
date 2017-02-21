
$cluster="demo"
$host="vulcain"

docker-machine.exe env --shell=powershell dev | Invoke-Expression
$hostIp = docker-machine ip $host

# Set context
Write-Host ">> Initializing swarm cluster as manager"
docker swarm init --advertise-addr $hostIp:2377

docker node update --label-add vulcain.environment=$cluster $host

Write-Host ">> Creating cluster network"
docker network create -d overlay --attachable --opt secure net-$cluster

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
docker run -ti --rm -v $DOCKER_CERT_PATH:/certs vulcain/install-demo $hostIp $cluster
Write-Host
Write-Host "Environment $cluster created successfully."
Write-Host

vulcain config --profile demo --token ab690d50-e85d-11e6-b767-8f41c48a4483 --template NodeMicroService --team vulcain-demo --server $(docker-machine ip vulcain):8080

Write-Host "Vulcain UI is available at http://$hostIp:8080 user: admin/vulcain"

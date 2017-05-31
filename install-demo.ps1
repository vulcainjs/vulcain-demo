param (
	[Parameter(Mandatory=$true)][string]$hostName,
	[string]$cluster = "demo"
)

docker-machine.exe env --shell=powershell $hostName | Invoke-Expression
$hostIp = docker-machine ip $hostName

# Set context
Write-Host ">> Initializing swarm cluster as manager"
docker swarm init --advertise-addr ${hostIp}:2377

docker node update --label-add vulcain.environment=$cluster $hostName

Write-Host ">> Creating cluster network"
docker network create -d overlay --attachable --opt secure net-$cluster

docker stack deploy --compose-file docker-compose.yml vulcain

docker run -d -p 24244:24244 --net=host `
      --name fluentd-agent `
      -e ELASTIC_URL=$hostIp `
      -e ELASTIC_PORT=9200 `
      -e VULCAIN_ENV=$cluster `
      vulcain/fluentd:1.0.0

 docker service create --name statsd-agent --network net-$cluster --mode global `
        --constraint node.labels.vulcain.environment==$cluster `
        --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock  `
        -e ENV=$cluster `
        -e INFLUXDB_SERVERS="'http://influxdb:8086'" `
        -e INFLUXDB_USER="admin" `
        -e INFLUXDB_PASSWORD="vulcain" `
        -p 8125:8125/udp `
        vulcain/telegraf:1.0.0

# Register
docker create --name setup -ti --rm -e hostIp=$hostIp -e cluster=$cluster -e token=ab690d50-e85d-11e6-b767-8f41c48a4483 vulcain/install-demo
docker cp $home\.docker\machine\machines\$hostName\cert.pem setup:/certs/cert.pem
docker cp $home\.docker\machine\machines\$hostName\ca.pem setup:/certs/ca.pem
docker cp $home\.docker\machine\machines\$hostName\key.pem setup:/certs/key.pem
docker start -i setup

Write-Host
Write-Host "Environment $cluster created successfully."
Write-Host

vulcain config --profile demo --token ab690d50-e85d-11e6-b767-8f41c48a4483 --template NodeMicroService --team vulcain-demo --server ${hostIp}:8080

Write-Host "Vulcain UI is available at http://${hostIp}:8080 user: admin/vulcain"

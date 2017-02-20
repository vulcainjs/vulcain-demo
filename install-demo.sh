#!/bin/bash
set -e

mode="init"
certsFolder="~/.docker/machine/certs"
token=ab690d50-e85d-11e6-b767-8f41c48a4483
cluster="demo"
host=vulcain
display_help() {
        echo "--host        docker-machine name (default vulcain)"
        echo "--mode        Docker-machine mode : init or update"
}

while :
do
    case "$1" in
      --host)
	    host="$2"
	    shift 2
	    ;;
      -h | --help)
        display_help
	    exit 0
	    ;;
      --mode)
        mode="$2"
        shift 2
        ;;
      *)  # No more options
	    break
	    ;;
    esac
done

hostIp="$(docker-machine ip $host)"

#normalize
certsFolder=$(eval echo $certsFolder)

initSwarm() {
    sleep 3

    # Set context
    echo ">> Initializing swarm cluster as manager"
    docker swarm init --advertise-addr $hostIp:2377 || true

    docker node update --label-add vulcain.environment=$cluster $host

    echo ">> Creating cluster network"
    docker network create -d overlay --attachable --opt secure net-$cluster || true
}

eval $(docker-machine env $host)
if [ "$mode" == "init"  ]; then
    initSwarm
fi

docker stack deploy --compose-file docker-compose.yml vulcain
docker run -d -p 24244:24244 --net=host \
      --name fluentd-agent \
      -e ELASTIC_URL=$hostIp \
      -e ELASTIC_PORT=9200 \
      -e VULCAIN_ENV=$cluster \
      vulcain/fluentd:1.0.0 || true

# docker service create --name statsd-agent --network net-$cluster --mode global \
#        --constraint node.labels.vulcain.environment==$cluster \
#        --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock  \
#        -e ENV=$cluster \
#        -e INFLUXDB_SERVERS="'http://influxdb:8086'" \
#        -e INFLUXDB_USER="admin" \
#        -e INFLUXDB_PASSWORD="vulcain" \
#        -p 8125:8125/udp \
#        vulcain/telegraf:1.0.0 || true

# Register
if [ "$mode" != "update" ]; then
    echo ">> Waiting for vulcain-ui" 
    until [ $(curl -s -o /dev/null -w "%{http_code}" http://$hostIp:8080/health) = "200" ]; do
        printf '.'
        sleep 2
    done
    echo
    echo ">> Registering cluster on vulcain "

    cert=$(cat $certsFolder/cert.pem | base64) >/dev/null 2>&1
    key="$(cat $certsFolder/key.pem | base64)" >/dev/null 2>&1
    ca="$(cat $certsFolder/ca.pem | base64)" >/dev/null 2>&1

cat >data.json <<-EOF
{
    "action": "Cluster.register",
    "params": {
        "name":"$cluster",
        "type":"swarm",
        "description":"Environment $cluster",
        "internalClusterAddress": "${hostIp}",
        "engine":{
            "__schema":"SwarmDefinition",
            "ip":"${hostIp}:2376",
            "tlsKey":"$key",
            "tlsCert":"$cert",
            "tlsCaCert":"$ca"
        },
        "namings": {
            "logServer": "${hostIp}:9200",
            "configurationServerName": "${hostIp}:8080"
        }
    }
}
EOF
    curl -H "Authorization: ApiKey $token" -XPOST http://$hostIp:8080/api/ \
     -H "Content-Type: application/json" \
     --data "@data.json"

    rm data.json

    echo 
    echo ">> Updating elastic search template"
    ./elastic-template.sh $hostIp

    echo
    echo "Environment $cluster created successfully."
    echo

    vulcain config --profile demo --token ab690d50-e85d-11e6-b767-8f41c48a4483 --template NodeMicroService --team vulcain-demo --server $(docker-machine ip vulcain):8080
fi

echo Vulcain UI is available at http://$hostIp:8080 user: admin/vulcain

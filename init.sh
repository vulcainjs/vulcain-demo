#!/bin/bash
set -e

cluster=$1
token=$2
hostIp=$3

checkRestart() {
    service=$1
    image=$2
    echo "Check container $service"
    status=$(docker inspect $service  -f {{.State.Status}} 2>/dev/null) || true
    if [ "$status" == "running" ]; then
        return 1 # running
    fi
    
    docker rm -f $service || true
    return 0
}

checkService() {
    set +e
    service=$1
    image=$2
    echo "Check service $service"
    img=$(docker service inspect $service -f {{.Spec.TaskTemplate.ContainerSpec.Image}} 2>/dev/null | cut -d '@' -f1) || true

    if [ -z "$img" ]; then
        return 1 # not running
    elif [ "$img" != "$image" ]; then
        return 2 # update
    fi
    return 0 # OK
}

image="mongo:3.4"
checkService mongo $image
flag=$?
if [ $flag == 1 ] ; then
 
     echo "Starting mongo"
     docker volume create --name mongo-data || true
     docker volume create --name mongo-conf || true
 
     docker service create \
         --network net-$cluster \
         --mount type=volume,src=mongo-data,dst=/data/db \
         --mount type=volume,source=mongo-config,target=/data/configdb \
         --name mongo \
         $image 
elif [ $flag == 2 ]; then
     echo "updating mongo"
    docker service update --image $image mongo
fi

image="elasticsearch:2.4"
checkService elastic $image
flag=$?
if [ $flag == 1 ] ; then

    echo "starting elastic search"
    docker service create --name elastic --network net-$cluster \
        -e ES_HEAP_SIZE="1g" \
        --limit-memory 1g \
        -p 9200:9200 \
        $image 
elif [ $flag == 2 ]; then
    echo "updating elastic search"
    docker service update --image $image elastic
fi

image="vulcain/fluentd:1.0.0"
if checkRestart fluentd-agent $image ; then
    echo "starting fluentd agent"
    docker run -d -p 24244:24244 --net=host \
      --name fluentd-agent \
      -e ELASTIC_URL=$hostIp \
      -e ELASTIC_PORT=9200 \
      -e VULCAIN_ENV=$cluster \
      $image
fi

image="vulcain/vulcain-ui:1.1.3"
checkService vulcain-ui $image
flag=$?
if [ $flag == 1 ] ; then
    echo "starting vulcain-ui"
    docker volume create --name data-ui || true

    docker service create  -p 8080:8080 --network net-$cluster \
        -e VULCAIN_TENANT=vulcain -e VULCAIN_ENV=system \
        --mount type=volume,src=data-ui,dst=/app/data \
        --name vulcain-ui  \
        $image
elif [ $flag == 2 ]; then
    echo "updating vulcain-ui"
    docker service update --image $image vulcain-ui
fi

image="vulcain/load-balancer:1.1.25"
checkService load-balancer $image
flag=$?
if [ $flag == 1 ] ; then
    echo "starting load-balancer"
    docker volume create --name Certificates || true

    docker service create --name load-balancer -p 80:80 -p 29000:29000 --network net-$cluster \
        -e VULCAIN_SERVER=vulcain-ui:8080 -e VULCAIN_ENV_MODE=test \
        -e VULCAIN_ENV=$cluster -e VULCAIN_TOKEN=$token \
        -e EXPIRATION_EMAIL=dummy@mail.com \
        --constraint node.labels.vulcain.environment==$cluster \
        --mount type=volume,src=Certificates,dst=/etc/letsencrypt \
        $image 
elif [ $flag == 2 ]; then
    echo "updating load-balancer"
    docker service update --image $image load-balancer
fi

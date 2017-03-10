set -e

echo ">> Waiting for vulcain-ui up" 
until [ $(curl -s -o /dev/null -w "%{http_code}" http://$hostIp:8080/health) = "200" ]; do
    printf '.'
    sleep 2
done
echo
echo ">> Registering cluster on vulcain "

cert=$(cat /certs/cert.pem | base64) >/dev/null 2>&1
key="$(cat /certs/key.pem | base64)" >/dev/null 2>&1
ca="$(cat /certs/ca.pem | base64)" >/dev/null 2>&1

cat >data.json <<-EOF
{
    "action": "Cluster.register",
    "params": {
        "name":"$cluster",
        "type":"swarm",
        "description":"Environment $cluster",
        "address":"${hostIp}:2376",
        "tlsKey":"$key",
        "tlsCert":"$cert",
        "tlsCaCert":"$ca",
        "engine":{
            "__schema":"SwarmDefinition",
            "internalClusterAddress": "${hostIp}"
        },
        "namings": {
            "__schema": "Namings",
            "logServer": "${hostIp}:9200",
            "configurationServerName": "${hostIp}:8080"
        }
    }
}
EOF

echo
curl -H "Authorization: ApiKey $token" -XPOST http://$hostIp:8080/api/ \
    -H "Content-Type: application/json" \
    --data "@data.json"

#rm data.json

echo 
echo ">> Updating elastic search template"
./elastic-template.sh $hostIp

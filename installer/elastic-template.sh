#!/usr/bin/env bash

# Elastic log template
host=$1
echo ">> Waiting for elasticsearch up" 
until [ $(curl -s -o /dev/null -w "%{http_code}" http://$host:9200/_cat/indices?v) = "200" ]; do
    printf '.'
    sleep 2
done  

curl -XPUT $host:9200/_template/vulcain_logs -d '
{
  "template": "logs-demo-*",
    "mappings": {
      "fluentd": {
        "properties": {
          "@timestamp": {
            "type": "date",
            "format": "strict_date_optional_time||epoch_millis"
          },
          "action": {
            "type": "string",
            "index": "not_analyzed"
          },
          "correlationId": {
            "type": "string",
            "index": "not_analyzed"
          },
          "error": {
            "type": "string"
          },
          "kind": {
            "type": "string",
            "index": "not_analyzed"
          },
          "message": {
            "type": "string"
          },
          "service": {
            "type": "string",
            "index": "not_analyzed"
          },
          "source": {
            "type": "string"
          },
          "stack": {
            "type": "string"
          },
          "timestamp": {
            "type": "long"
          },
          "traceId": {
            "type": "string",
            "index": "not_analyzed"
          },
          "version": {
            "type": "string",
            "index": "not_analyzed"
          }
        }
      }
    }
  }'


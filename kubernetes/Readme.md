
prerequisites :
vulcain-ui est installé avec un service pour l epublier
un token est généré
un registry existe

# Creation cluster kubernetes

1. Install cluster az acs kubernetes name location
2. get-credentials

# Creation env
1. register cluster - adresse config=vulcain-ui.default, adresse master=kubernetes:443
2. install load-balancer

# Creation d'une équipe
1. creation d'un secret pour le registry privé 

```bash
kubectl create secret docker-registry <team>-registry-secret \
 --namespace=<env> \
 --docker-server=<private registry> \
 --docker-username=<your-name> --docker-password=<your-pword> --docker-email=<your-email>
```
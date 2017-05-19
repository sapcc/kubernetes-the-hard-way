# Smoke Test

This lab walks you through a quick smoke test to make sure things are working.

## Test

```
kubectl run nginx --image=nginx --port=80 --replicas=3
```

```
kubectl get pods -o wide
```
```
NAME                     READY     STATUS    RESTARTS   AGE       IP             NODE
nginx-2371676037-7f5v2   1/1       Running   0          12s       10.180.132.2   minion0
nginx-2371676037-d6bhh   1/1       Running   0          12s       10.180.131.2   minion1
nginx-2371676037-x7ddv   1/1       Running   0          2h        10.180.133.2   minion2
```


From any master or minion the pod will respond:
```
curl http://10.180.133.2
```

## Externally Expose a Service 

Let's expose the service:

```
kubectl expose deployment nginx --type LoadBalancer --port=80 
```

This will automatically create a load-balancer using the Openstack
cloud-provider.

From any minion the services ClusterIP will respond:
```
kubectl get service nginx
NAME      CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
nginx     10.180.1.66   10.180.0.25   80:31617/TCP   44m

curl http://10.180.1.66
```

### Attach a Floating IP

Let's find the new load-balancer:

```
neutron lbaas-loadbalancer-list
```

```
+--------------------------------------+----------------------------------+-------------+---------------------+------------+
| id                                   | name                             | vip_address | provisioning_status | provider   |
+--------------------------------------+----------------------------------+-------------+---------------------+------------+
| abb068fc-d6ed-4a81-b424-b95a5f775bcc | master                           | 10.180.0.7  | ACTIVE              | f5networks |
| 1efca370-6487-4448-a4b5-e94b20c6a85a | ab7fe37cb3ba111e7a45afa163e30cd4 | 10.180.0.25 | ACTIVE              | f5networks |
+--------------------------------------+----------------------------------+-------------+---------------------+------------+
```

We need to grep its port:
```
neutron port-list | grep abb068fc-d6ed-4a81-b424-b95a5f775bcc
```

```
| 08899903-ca6c-42a0-b210-f8a380dfcd80 | loadbalancer-abb068fc-d6ed-4a81-b424-b95a5f775bcc                                      | fa:16:3e:8b:54:99 | {"subnet_id": "83aab941-87f4-4372-9fbc-9f702092e3cf", "ip_address": "10.180.0.7"}  |
```

And assign a floating IP:

```
neutron floatingip-create FloatingIP-external-monsoon3
neutron floatingip-associate b701ae4f-161a-41ef-bf84-e70a2bf68581 08899903-ca6c-42a0-b210-f8a380dfcd80
````

### Verify

```
curl http://${FLOATING_IP}
```

```
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

## Creating a Persitent Volume

Here we will create a volume claim:

```
cat <<EOF |
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: www 
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
EOF
kubectl create -f -
```

This will auto-provision a cinder volume:

```
kubectl get pv
```
```
NAME                                       CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS    CLAIM         STORAGECLASS   REASON    AGE
pvc-1e8d5024-3baf-11e7-914e-fa163e7d628d   8Gi        RWO           Delete          Bound     default/www   standard                 4m
```

```
cat <<EOF |
apiVersion: v1
kind: Pod 
metadata:
  name: pvcnginx
spec:
  containers:
  - name: server
    image: nginx
    volumeMounts:
      - mountPath: /var/lib/www/html
        name: mypvc
  volumes:
    - name: mypvc
      persistentVolumeClaim:
        claimName:  www 
EOF
kubectl create -f -
```

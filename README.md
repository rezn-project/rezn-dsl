# rezn-dsl

Basic example

```
pod "nginx" {
  image = "nginx:alpine"
  replicas = 2
  ports = [80, 443]
  secure = true
}

service "nginx-service" {
  selector = "nginx"
  port = 80
}

volume "shared-cache" {
  mount = "/cache"
}

enum "env" {
  "dev", "staging", "prod"
}
```

Future example with contracts:

```
pod "auth" {
  image = "ghcr.io/app/auth:latest"
  replicas = 3
  ports = [8080]

  contract {
    pre  = image.exists && env.has("JWT_SECRET")
    post = pod.state == PodState.STATE_RUNNING && all(pod.replicas, r -> r.ready)
    invariant = zone.distributed && ports.unique
  }
}
```

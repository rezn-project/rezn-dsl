# rezn-dsl

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

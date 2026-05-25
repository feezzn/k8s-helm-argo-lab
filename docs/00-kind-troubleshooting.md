# Kind Troubleshooting

## Pare aqui antes do KEDA

Antes de instalar KEDA, Kafka ou qualquer workload, valide o cluster base:

```bash
./scripts/01b-check-cluster-health.sh
```

Nao siga se:

- node esta `NotReady`.
- `kube-proxy` esta em `CrashLoopBackOff`.
- CoreDNS esta `0/1`.

## kube-proxy: too many open files

Se os logs mostram:

```text
command failed err="failed complete: too many open files"
```

O problema nao e Kafka nem KEDA.
O `kube-proxy` nao consegue iniciar, entao a rede de Services do cluster nao fica funcional.

Em Kind, esse erro pode acontecer por dois limites diferentes:

- `nofile`, limite de arquivos por processo/container.
- `inotify`, limite do kernel usado por watchers de arquivos; esse limite vem do host.

Comandos para diagnosticar no host:

```bash
ulimit -n
cat /proc/sys/fs/file-max
cat /proc/sys/fs/nr_open
cat /proc/sys/fs/file-nr
cat /proc/sys/fs/inotify/max_user_watches
cat /proc/sys/fs/inotify/max_user_instances
cat /proc/sys/fs/inotify/max_queued_events
docker info | grep -i -E 'ulimit|nofile|runc|cgroup'
docker inspect keda-lab-control-plane --format '{{json .HostConfig.Ulimits}}'
docker exec keda-lab-control-plane sh -c 'ulimit -n; grep "Max open files" /proc/1/limits'
kubectl -n kube-system get pods -l k8s-app=kube-proxy -o wide
kubectl -n kube-system logs daemonset/kube-proxy --previous --tail=-1
kubectl -n kube-system logs daemonset/kube-proxy --tail=-1
```

Se o limite dentro do container Kind estiver baixo, ajuste o `nofile` padrao do Docker e recrie o cluster.

Exemplo de `/etc/docker/daemon.json`:

```json
{
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Soft": 1048576,
      "Hard": 1048576
    }
  }
}
```

Depois:

```bash
sudo systemctl restart docker
kind delete cluster --name keda-lab
./scripts/01-kind-create.sh
./scripts/01b-check-cluster-health.sh
```

Se voce ja tem um `daemon.json`, faca merge do bloco `default-ulimits` em vez de substituir o arquivo inteiro.

Se o `nofile` ja estiver alto dentro do container Kind, ajuste os limites de `inotify` no host:

```bash
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512
sudo sysctl fs.inotify.max_queued_events=32768
```

Para persistir:

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/99-kind-inotify.conf
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
fs.inotify.max_queued_events = 32768
EOF

sudo sysctl --system
```

Depois recrie o cluster:

```bash
kind delete cluster --name keda-lab
./scripts/01-kind-create.sh
./scripts/01b-check-cluster-health.sh
```

## CoreDNS 503

CoreDNS com readiness `503` logo depois de `kube-proxy` quebrado costuma ser sintoma da rede base incompleta.
Nao ajuste KEDA ainda.

Primeiro resolva:

```bash
kubectl -n kube-system rollout status daemonset/kube-proxy --timeout=120s
kubectl -n kube-system rollout status deployment/coredns --timeout=120s
```

Quando os dois passarem, ai sim volte para:

```bash
./scripts/02-install-keda.sh
```

Se CoreDNS continuar `0/1` depois do `kube-proxy` estabilizar, olhe os logs do CoreDNS:

```bash
kubectl -n kube-system logs deployment/coredns --tail=120
kubectl get endpoints kubernetes -n default -o wide
kubectl get endpoints kube-dns -n kube-system -o wide
kubectl -n kube-system get cm coredns -o yaml
```

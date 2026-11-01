# kubernetes-homelab

GitOps repository for a two-node Talos Linux homelab cluster. Talos machine configuration is managed with [topf](https://github.com/postfinance/topf). Everything inside the cluster is reconciled by [Flux](https://fluxcd.io). Secrets are encrypted with [SOPS](https://github.com/getsops/sops) and age.

## Cluster

| Node     | Role          | Notes                                         |
|----------|---------------|-----------------------------------------------|
| `talos-1`| control-plane | Single control plane, etcd and kube-apiserver |
| `talos-2`| worker        |                                               |

- **OS:** Talos Linux (bare metal), with system extensions defined in `talos/schematics/`: iscsi-tools, util-linux-tools, nfs-utils, amd-ucode, realtek-firmware and tailscale.
- **CNI:** Cilium, installed by Flux. Talos' built-in Flannel is deleted (`talos/all/07-no-flannel.yaml`).
- **Storage:** Longhorn on a dedicated user volume (`talos/all/06-longhorn.yaml`), plus the NFS CSI driver.
- **Access:** nodes run the Tailscale extension, and the kube-apiserver cert includes the `<host>.<tailnet>` MagicDNS name as a SAN.

## Repository layout

```
.
├── talos/                  # Talos machine config, applied with topf
│   ├── topf.yaml           # cluster definition and nodes (SOPS-encrypted fields)
│   ├── secrets.yaml        # Talos secrets bundle (SOPS-encrypted)
│   ├── schematics/         # Image Factory schematics, one per node
│   ├── all/                # config patches for every node
│   ├── control-plane/      # patches for control-plane nodes
│   ├── worker/             # patches for worker nodes
│   └── node/<host>/        # per-node patches (install disk selection)
├── clusters/homelab/       # Flux entrypoint: flux-system and the top-level Kustomizations
├── infrastructure/
│   ├── controllers/        # cilium, longhorn, tailscale, cnpg, garage, operators, ...
│   └── configs/secrets/    # SOPS-encrypted Kubernetes secrets
├── monitoring/             # VictoriaMetrics, VictoriaLogs, Grafana, exporters
├── apps/homelab/           # applications (media server, from its own Git repo)
├── .sops.yaml              # SOPS creation rules
└── .gitlab-ci.yml          # GitLab secret detection
```

Files ending in `.tpl` in `talos/` are Go templates. They are rendered per node using values from `topf.yaml` such as `.Node.Host`, `.Node.Data.lanIP` and `.Data.tailnetName`.

## Flux

`clusters/homelab/` defines these Kustomizations. All of them decrypt with the `sops-age` secret.

| Kustomization               | Path                        | Prune |
|-----------------------------|-----------------------------|-------|
| `infrastructure-controllers`| `./infrastructure/controllers` | yes |
| `infrastructure-configs`    | `./infrastructure/configs`  | yes   |
| `monitoring`                | `./monitoring`              | yes   |
| `apps`                      | `./apps/homelab`            | no    |

## Secrets

SOPS rules are in `.sops.yaml`:

| Path                                | Encrypted fields               |
|-------------------------------------|--------------------------------|
| `infrastructure/configs/secrets/*`  | `data`, `stringData`           |
| `talos/secrets.yaml`                | whole file                     |
| `talos/topf.yaml`                   | `clusterEndpoint`, `ip`, `data`|

You need the age private key to edit them (`SOPS_AGE_KEY_FILE`). For example:

```sh
sops talos/topf.yaml
sops -d infrastructure/configs/secrets/grafana-admin.yaml
```

Never commit plaintext secrets. CI runs GitLab secret detection on every push.

## Operating the cluster

### Talos (topf)

Run these from `talos/` with the age key available. See the topf documentation for the exact commands and flags.

- **Config changes:** edit the patches or `topf.yaml`, then apply with topf.
- **Talos or Kubernetes upgrades:** bump `talosVersion` or `kubernetesVersion` in `topf.yaml`, then run `topf upgrade`.
- **Where topf connects:** each node's `ip` is used for the Talos API. `clusterEndpoint` is used for Kubernetes API access, such as draining nodes. Both must be reachable from where you run topf. If you run it over Tailscale, use the MagicDNS names, not LAN addresses.
- **Control-plane upgrades:** there is a single control plane, so the API is down while `talos-1` reboots. Keep LAN or console access in case the Tailscale extension doesn't come back.

### Flux

Push to `main` and Flux reconciles. To force a sync:

```sh
flux reconcile source git flux-system
flux reconcile kustomization infrastructure-controllers --with-source
flux get kustomizations
```

## Prerequisites

`talosctl`, `topf`, `kubectl`, `flux`, `sops` and `age`.

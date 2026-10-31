apiVersion: v1alpha1
kind: KubeAPIServerConfig
certExtraSANs:
  - {{ .Node.Data.lanIP }}
  - {{ .Node.Host }}.{{ .Data.tailnetName }}

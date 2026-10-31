apiVersion: v1alpha1
kind: HostnameConfig
$patch: delete
---
apiVersion: v1alpha1
kind: HostnameConfig
hostname: {{ .Node.Host }}

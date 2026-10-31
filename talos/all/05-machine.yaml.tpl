machine:
  certSANs:
    - {{ .Node.Host }}.{{ .Data.tailnetName }}
  network:
    interfaces:
      - deviceSelector:
          hardwareAddr: {{ .Node.Data.hardwareAddr }}
        dhcp: false
        addresses:
          - {{ .Node.Data.lanIP }}/24
        routes:
          - network: 0.0.0.0/0
            gateway: 192.168.1.254

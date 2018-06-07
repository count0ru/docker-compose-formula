## Usage example


```
docker-compose:

  composes:

    myservice:
      create_systemd_unit: true       # create systemd unit *
      enabled_systemd_unit: true      # run systemd unit on boot *
      volume_files: myservice_custom  # volume directory in <formula path>/files/composename *
      consul_register_port: 9100      # if defined - service will be registered in consul *
      systemd_ext:                    # additional systemd directives *
        ExecPreStart: /bin/echo OK
      empty_dirs:                     # create empty directory for volume mount *
        - name: data                  
          user: 999
          group: 999
      service_addr:                   # this ip will be up before start compose (in systemd unit) *
        - ip: "172.16.40.1/32"
          dev: "dummy0"
      restart_on_failure: true        # *
      docker-compose-file:            # docker-compose.yml file content
        version: '3'
        services:
          myservice:
            image: "prom/consul-exporter"
            command:
              - "-web.listen-address=172.16.40.1:666"
            network_mode: host
```
parameters with * are optional

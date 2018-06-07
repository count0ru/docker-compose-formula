{% set docker_compose_bin_path = "/usr/local/bin/docker-compose" %}
{% set docker_composes_path = "/opt" %}

{%- if salt['grains.get']('ip4_interfaces:ens3')[0] is defined %}
  {% set service_ip = salt['grains.get']('ip4_interfaces:ens3')[0] %}
{%- elif salt['grains.get']('ip4_interfaces:eth0')[0] is defined %}
  {% set service_ip = salt['grains.get']('ip4_interfaces:eth0')[0] %}
{%- else -%}
  {% set service_ip = "127.0.0.1" %}
{%- endif %} 

{% for compose_name, compose_data in salt['pillar.get']('docker-compose:composes', {}).items() %}

{{ docker_composes_path }}/{{ compose_name }}:
  file.directory:
    - user: root
    - mode: 0755

{{ docker_composes_path }}/{{ compose_name }}/docker-compose.yml:
  file.managed:
    - contents: |
        {{ compose_data['docker-compose-file']|yaml(False)|indent(8) }}


{% if compose_data['volume_files'] is  defined %}

{{ docker_composes_path }}/{{ compose_name }}/volumes:
  file.recurse:
    - source: salt://{{ tpldir }}/files/{{ compose_data['volume_files']['source'] }}
    - makedirs: True
    - include_empty: True
   {%- if compose_data['volume_files']['template'] is defined %}  
    - template: {{ compose_data['volume_files']['template'] }}  
   {%- endif %}
   {%- if compose_data['volume_files']['user'] is defined %} 
    - user: {{ compose_data['volume_files']['user'] }} 
   {%- endif %} 
   {%- if compose_data['volume_files']['group'] is defined %} 
    - group: {{ compose_data['volume_files']['group'] }}
   {%- endif %} 
   {%- if compose_data['volume_files']['file_mode'] is defined %} 
    - file_mode: {{ compose_data['volume_files']['file_mode'] }}
   {%- endif %}
   {%- if compose_data['volume_files']['dir_mode'] is defined %}  
    - dir_mode: {{ compose_data['volume_files']['dir_mode'] }}
   {%- endif %}  
{% endif %}

{% if compose_data['empty_dirs'] is  defined %}
{% for dir in compose_data['empty_dirs'] %}
{{ docker_composes_path }}/{{ compose_name }}/volumes/{{ dir['name'] }}:
  file.directory:
    - makedirs: True
    - include_empty: True
   {%- if dir['user'] is defined %}  
    - user: {{ dir['user'] }}  
   {%- endif %}  
   {%- if dir['group'] is defined %}  
    - group: {{ dir['group'] }}
   {%- endif %}  
   {%- if dir['mode'] is defined %}  
    - mode: {{ dir['mode'] }}
   {%- endif %}
{% endfor %}
{% endif %}

{% if compose_data['create_systemd_unit'] is defined and compose_data['create_systemd_unit']  %}

{% if compose_data['consul_register_port'] is  defined %}

/etc/consul/{{ compose_name }}-register-payload.json:
  file.serialize:
    - dataset:
        ID: "{{ compose_name }}-{{ grains['id'] }}"
        Name: "{{ compose_name }}"
        Address: "{{ service_ip }}"
        Port: {{ compose_data['consul_register_port'] }}
        Tags: ["{{ env }}", "{{ project }}", "{{ servicetype }}", "{{ sla }}", "{{ owner }}"]
        Check: 
          Script: "systemctl status {{ compose_name }}"
          Interval: "30s"
    - formatter: json
{%- endif %} 

/etc/systemd/system/{{ compose_name }}.service:
  file.managed:
    - template: jinja
    - watch_in:
      - cmd: {{ compose_name }}-reload_systemd_configuration
    - contents: |
        [Unit]
        Description={{ compose_name }} 
        [Service] 
        {%- if compose_data['service_addr'] is defined %} 
        {%- for addr in compose_data['service_addr'] %}
        ExecStartPre=/sbin/ip address add {{ addr['ip'] }} dev {{ addr['dev'] }} 
        ExecStopPost=/sbin/ip address del {{ addr['ip'] }} dev {{ addr['dev'] }} 
        {%- endfor %} 
        {%- endif %} 
        {%- if compose_data['consul_register_port'] is  defined %}
        ExecStartPre=/usr/bin/curl --silent -d @/etc/consul/{{ compose_name }}-register-payload.json http://127.0.0.1:8500/v1/agent/service/register
        ExecStopPost=/usr/bin/curl --silent -X PUT http://127.0.0.1:8500/v1/agent/service/deregister/{{ compose_name }}-{{ grains['id'] }}
        {%- endif %} 
        ExecStart={{ docker_compose_bin_path }} -f {{ docker_composes_path }}/{{ compose_name }}/docker-compose.yml up
        ExecStop={{ docker_compose_bin_path }} -f {{ docker_composes_path }}/{{ compose_name }}/docker-compose.yml down
        {%- if compose_data['systemd_ext']  is defined %} 
        {% for key, value in compose_data['systemd_ext'].iteritems() %}
        {{ key }}={{ value }}
        {%- endfor %}
        {%- endif %} 
        [Install]
         WantedBy=default.target

{{ compose_name }}.service:
  service.running:
{% if compose_data['enabled_systemd_unit'] is defined and compose_data['enabled_systemd_unit']== true  %}
    - enable: True   
{% endif %}
    - require:
      - cmd: {{ compose_name }}-reload_systemd_configuration
    - watch:
      - file: /etc/systemd/system/{{ compose_name }}.service
      - file: {{ docker_composes_path }}/{{ compose_name }}/docker-compose.yml


{{ compose_name }}-reload_systemd_configuration:
    cmd.wait:
      - name: systemctl daemon-reload
      - watch:
        - file: /etc/systemd/system/{{ compose_name }}.service
 
{% endif %}
     
{% endfor %}

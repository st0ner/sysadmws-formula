{% if pillar['app'] is defined and pillar['app'] is not none and pillar['app']['docker'] is defined and pillar['app']['docker'] is not none %}
docker_install_00:
  file.directory:
    - name: /etc/docker
    - mode: 700

docker_install_01:
  file.managed:
    - name: /etc/docker/daemon.json
    - contents: |
        {"iptables": false}

docker_install_1:
  pkgrepo.managed:
    - humanname: Docker CE Repository
    - name: deb [arch=amd64] https://download.docker.com/linux/{{ grains['os']|lower }} {{ grains['oscodename'] }} stable
    - file: /etc/apt/sources.list.d/docker-ce.list
    - key_url: https://download.docker.com/linux/{{ grains['os']|lower }}/gpg

docker_install_2:
  pkg.installed:
    - refresh: True
    - reload_modules: True
    - pkgs:
        - docker-ce: '{{ pillar['app']['docker']['docker-ce_version'] }}*'
  {%- if "300" in grains['saltversion']|string %}
        - python3-docker
  {%- else %}
        - python-docker
  {%- endif %}

docker_pip_install:
  pip.installed:
    - name: docker-py >= 1.10
    - reload_modules: True

docker_purge_apparmor:
  pkg.purged:
    - name: apparmor

docker_install_3:
  service.running:
    - name: docker

docker_install_4:
  cmd.run:
    - name: systemctl restart docker
    - onchanges:
        - file: /etc/docker/daemon.json
        - pkg: apparmor

  {%- for net in pillar['app']['docker']['networks'] %}
docker_network_{{ loop.index }}:
  docker_network.present:
    - name: {{ net['name'] }}
    - subnet: {{ net['subnet'] }}
    - gateway: {{ net['gateway'] }}
  {%- endfor %}

  {%- for app_name, app in pillar['app']['docker']['apps'].items() %}
    {%- if not (pillar['app']['docker']['deploy_only'] is defined and pillar['app']['docker']['deploy_only'] is not none) or app_name in pillar['app']['docker']['deploy_only'] %}
docker_app_dir_{{ loop.index }}:
  file.directory:
    - name: {{ app['home'] }}
    - mode: 755
    - makedirs: True

      {%- set i_loop = loop %}
      {%- for bind in app['binds'] %}
docker_app_bind_dir_{{ i_loop.index }}_{{ loop.index }}:
  file.directory:
    - name: {{ bind.split(':')[0] }}
    - mode: 755
    - makedirs: True
      {%- endfor %}

      {%- if app['docker_registry_login'] is defined and app['docker_registry_login'] is not none %}
docker_app_docker_login_{{ loop.index }}:
  cmd.run:
    - name: docker login -u "{{ app['docker_registry_login']['username'] }}" -p "{{ app['docker_registry_login']['password'] }}" "{{ app['docker_registry_login']['registry'] }}"
      {%- endif %}

docker_app_docker_pull_{{ loop.index }}:
  cmd.run:
    - name: docker pull {{ app['image'] }}

docker_app_container_{{ loop.index }}:
  docker_container.running:
    - name: app-{{ app_name }}
    - user: root
    - image: {{ app['image'] }}
    - detach: True
    - restart_policy: unless-stopped
    - publish: {{ app['publish'] }}
    - environment: {{ app['environment'] }}
    - binds: {{ app['binds'] }}
    - networks: {{ app['networks'] }}
    - privileged: {{ app['privileged'] | default(False) }}

      {%- if app['exec_after_deploy'] is defined and app['exec_after_deploy'] is not none %}
docker_app_container_exec_{{ loop.index }}:
  cmd.run:
    - name: docker exec app-{{ app_name }} {{ app['exec_after_deploy'] }}
      {%- endif %}

      {%- if app['cron'] is defined and app['cron'] is not none %}
        {%- set i_loop = loop %}
        {%- for cron in app['cron'] %}
docker_app_container_cron_{{ i_loop.index }}_{{ loop.index }}:
  cron.present:
    - name: docker exec app-{{ app_name }} {{ cron['cmd'] }}
    - identifier: docker-app-{{ app_name }}-{{ loop.index }}
    - user: root
          {%- if cron['minute'] is defined and cron['minute'] is not none %}
    - minute: '{{ cron['minute'] }}'
          {%- endif %}
          {%- if cron['hour'] is defined and cron['hour'] is not none %}
    - hour: '{{ cron['hour'] }}'
          {%- endif %}
          {%- if cron['daymonth'] is defined and cron['daymonth'] is not none %}
    - daymonth: '{{ cron['daymonth'] }}'
          {%- endif %}
          {%- if cron['month'] is defined and cron['month'] is not none %}
    - month: '{{ cron['month'] }}'
          {%- endif %}
          {%- if cron['dayweek'] is defined and cron['dayweek'] is not none %}
    - dayweek: '{{ cron['dayweek'] }}'
          {%- endif %}
          {%- if cron['special'] is defined and cron['special'] is not none %}
    - special: '{{ cron['special'] }}'
          {%- endif %}
        {%- endfor %}
      {%- endif %}
    {%- endif %}
  {%- endfor %}
{% endif %}

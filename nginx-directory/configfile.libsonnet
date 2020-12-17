local k = import 'ksonnet-util/kausal.libsonnet';
{
  local buildHeaders(service, redirect, allowWebsockets, subfilter) =
    if redirect then |||
      return 302 %(url)s;
    ||| % service else |||
      proxy_pass      %(url)s$2$is_args$args;
      proxy_set_header    Host $host;
      proxy_set_header    X-Real-IP $remote_addr;
      proxy_set_header    X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header    X-Forwarded-Proto $scheme;
      proxy_set_header    X-Forwarded-Host $http_host;
      proxy_read_timeout  %(nginx_proxy_read_timeout)s;
      proxy_send_timeout  %(nginx_proxy_send_timeout)s;
    ||| % (service + $._config) + if allowWebsockets then |||
      # Allow websocket connections https://www.nginx.com/blog/websocket-nginx/
      proxy_set_header    Upgrade $http_upgrade;
      proxy_set_header    Connection "Upgrade";
    ||| else '' + if subfilter then |||
      sub_filter 'href="/' 'href="/%(path)s/';
      sub_filter 'src="/' 'src="/%(path)s/';
      sub_filter 'action="/' 'action="/%(path)s/';
      sub_filter 'endpoint:"/' 'endpoint:"/%(path)s/';  # for XHRs.
      sub_filter 'href:"/v1/' 'href:"/%(path)s/v1/';
      sub_filter_once off;
      sub_filter_types text/css application/xml application/json application/javascript;
      proxy_redirect   "/" "/%(path)s/";
    ||| % service else '',

  local buildLocation(service) =
    |||
      location ~ ^/%(path)s(/?)(.*)$ {
    ||| % service +
    buildHeaders(
      service,
      if 'redirect' in service then service.redirect else false,
      if 'allowWebsockets' in service then service.allowWebsockets else false,
      if 'subfilter' in service then service.subfilter else false,
    ) +
    |||
      }
    |||,

  local configMap = k.core.v1.configMap,

  nginx_config_map:
    local vars = {
      location_stanzas: [
        buildLocation(service)
        for service in std.set($._config.admin_services, function(s) s.url)
      ],
      locations: std.join('\n', self.location_stanzas),
      link_stanzas: [
        |||
          <li><a href="/%(path)s%(params)s">%(title)s</a></li>
        ||| % ({ params: '' } + service)
        for service in $._config.admin_services
      ],
      links: std.join('\n', self.link_stanzas),
    };

    configMap.new('nginx-config') +
    configMap.withData({
      'nginx.conf': |||
        worker_processes     5;  ## Default: 1
        error_log            /dev/stderr;
        pid                  /tmp/nginx.pid;
        worker_rlimit_nofile 8192;

        events {
          worker_connections  4096;  ## Default: 1024
        }

        http {
          default_type application/octet-stream;
          log_format   main '$remote_addr - $remote_user [$time_local]  $status '
            '"$request" $body_bytes_sent "$http_referer" '
            '"$http_user_agent" "$http_x_forwarded_for"';
          access_log   /dev/stderr  main;
          sendfile     on;
          tcp_nopush   on;
          resolver     kube-dns.kube-system.svc.%(cluster_dns_suffix)s;
          server {
            listen 80;
            %(locations)s
            location ~ /(index.html)? {
              root /etc/nginx;
            }
          }
        }
      ||| % ($._config + vars),
      'index.html': |||
        <html>
          <head><title>Admin</title></head>
          <body>
            <h1>Admin</h1>
            <ul>
              %(links)s
            </ul>
          </body>
        </html>
      ||| % vars,
    }),
}
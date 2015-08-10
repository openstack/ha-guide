
=============
HAProxy nodes
=============

HAProxy provides a fast and reliable HTTP reverse proxy
and load balancer for TCP and HTTP-based applications.
It is particularly suited for web sites crawling under very high loads
while needing persistence or Layer 7 processing.
Supporting tens of thousands of connections
is clearly realistic with today’s hardware.

[TODO (Add note about using commercial load-balancers]

For detailed instructions about installing HAProxy on your nodes,
see its `official documentation <http://www.haproxy.org/#docs>`_.
Note the following:

- HAProxy should not be a single point of failure;
  you need to ensure its availability by other means,
  such as Pacemaker or Keepalived.

- It is advisable to have multiple HAProxy instances running,
  where the number of these instances is a small odd number like 3 or 5.

- The common practice is to locate an HAProxy instance
  on each OpenStack controller in the environment.

Here is an example :file:`/etc/haproxy/haproxy.cfg` configuration file.
[TODO: Is a copy required on each controller node?]
Note that you must restart the HAProxy service to implement
any changes made to this file.

::

    global
      chroot  /var/lib/haproxy
      daemon
      group  haproxy
      maxconn  4000
      pidfile  /var/run/haproxy.pid
      user  haproxy

    defaults
      log  global
      maxconn  4000
      option  redispatch
      retries  3
      timeout  http-request 10s
      timeout  queue 1m
      timeout  connect 10s
      timeout  client 1m
      timeout  server 1m
      timeout  check 10s

    listen dashboard_cluster
      bind <Virtual IP>:443
      balance  source
      option  tcpka
      option  httpchk
      option  tcplog
      server controller1 10.0.0.1:443 check inter 2000 rise 2 fall 5
      server controller2 10.0.0.2:443 check inter 2000 rise 2 fall 5
      server controller3 10.0.0.3:443 check inter 2000 rise 2 fall 5

    listen galera_cluster
      bind <Virtual IP>:3306
      balance  source
      option  httpchk
      server controller1 10.0.0.4:3306 check port 9200 inter 2000 rise 2 fall 5
      server controller2 10.0.0.5:3306 backup check port 9200 inter 2000 rise 2 fall 5
      server controller3 10.0.0.6:3306 backup check port 9200 inter 2000 rise 2 fall 5

    listen glance_api_cluster
      bind <Virtual IP>:9292
      balance  source
      option  tcpka
      option  httpchk
      option  tcplog
      server controller1 10.0.0.1:9292 check inter 2000 rise 2 fall 5
      server controller2 10.0.0.2:9292 check inter 2000 rise 2 fall 5
      server controller3 10.0.0.3:9292 check inter 2000 rise 2 fall 5

    listen glance_registry_cluster
      bind <Virtual IP>:9191
      balance  source
      option  tcpka
      option  tcplog
      server controller1 10.0.0.1:9191 check inter 2000 rise 2 fall 5
      server controller2 10.0.0.2:9191 check inter 2000 rise 2 fall 5
      server controller3 10.0.0.3:9191 check inter 2000 rise 2 fall 5

    listen keystone_admin_cluster
      bind <Virtual IP>:35357
      balance  source
      option  tcpka
      option  httpchk
      option  tcplog
      server controller1 10.0.0.1:35357 check inter 2000 rise 2 fall 5
      server controller2 10.0.0.2:35357 check inter 2000 rise 2 fall 5
      server controller3 10.0.0.3:35357 check inter 2000 rise 2 fall 5

    listen keystone_public_internal_cluster
      bind <Virtual IP>:5000
      balance  source
      option  tcpka
      option  httpchk
      option  tcplog
      server controller1 10.0.0.1:5000 check inter 2000 rise 2 fall 5
      server controller2 10.0.0.2:5000 check inter 2000 rise 2 fall 5
      server controller3 10.0.0.3:5000 check inter 2000 rise 2 fall 5

    listen nova_ec2_api_cluster
      bind <Virtual IP>:8773
      balance  source
      option  tcpka
      option  tcplog
      server controller1 10.0.0.1:8773 check inter 2000 rise 2 fall 5
      server controller2 10.0.0.2:8773 check inter 2000 rise 2 fall 5
      server controller3 10.0.0.3:8773 check inter 2000 rise 2 fall 5

    listen nova_compute_api_cluster
      bind <Virtual IP>:8774
      balance  source
      option  tcpka
      option  httpchk
      option  tcplog
      server controller1 10.0.0.1:8774 check inter 2000 rise 2 fall 5
      server controller2 10.0.0.2:8774 check inter 2000 rise 2 fall 5
      server controller3 10.0.0.3:8774 check inter 2000 rise 2 fall 5

    listen nova_metadata_api_cluster
      bind <Virtual IP>:8775
      balance  source
      option  tcpka
      option  tcplog
      server controller1 10.0.0.1:8775 check inter 2000 rise 2 fall 5
      server controller2 10.0.0.2:8775 check inter 2000 rise 2 fall 5
      server controller3 10.0.0.3:8775 check inter 2000 rise 2 fall 5

    listen cinder_api_cluster
      bind <Virtual IP>:8776
      balance  source
      option  tcpka
      option  httpchk
      option  tcplog
      server controller1 10.0.0.1:8776 check inter 2000 rise 2 fall 5
      server controller2 10.0.0.2:8776 check inter 2000 rise 2 fall 5
      server controller3 10.0.0.3:8776 check inter 2000 rise 2 fall 5

    listen ceilometer_api_cluster
      bind <Virtual IP>:8777
      balance  source
      option  tcpka
      option  httpchk
      option  tcplog
      server controller1 10.0.0.1:8777 check inter 2000 rise 2 fall 5
      server controller2 10.0.0.2:8777 check inter 2000 rise 2 fall 5
      server controller3 10.0.0.3:8777 check inter 2000 rise 2 fall 5

    listen nova_vncproxy_cluster
      bind <Virtual IP>:6080
      balance  source
      option  tcpka
      option  tcplog
      server controller1 10.0.0.1:6080 check inter 2000 rise 2 fall 5
      server controller2 10.0.0.2:6080 check inter 2000 rise 2 fall 5
      server controller3 10.0.0.3:6080 check inter 2000 rise 2 fall 5

    listen neutron_api_cluster
      bind <Virtual IP>:9696
      balance  source
      option  tcpka
      option  httpchk
      option  tcplog
      server controller1 10.0.0.1:9696 check inter 2000 rise 2 fall 5
      server controller2 10.0.0.2:9696 check inter 2000 rise 2 fall 5
      server controller3 10.0.0.3:9696 check inter 2000 rise 2 fall 5

    listen swift_proxy_cluster
      bind <Virtual IP>:8080
      balance  source
      option  tcplog
      option  tcpka
      server controller1 10.0.0.1:8080 check inter 2000 rise 2 fall 5
      server controller2 10.0.0.2:8080 check inter 2000 rise 2 fall 5
      server controller3 10.0.0.3:8080 check inter 2000 rise 2 fall 5


Note the following:

- The Galera cluster configuration commands indicate
  that two of the three controllers are standby nodes.
  [TODO: be specific about the coding that defines this]
  This ensures that only one node services write requests
  because OpenStack support for multi-node writes is not yet production-ready.

- [TODO: we need more commentary about the contents and format of this file]


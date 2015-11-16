========================================
Overview of highly-available controllers
========================================

OpenStack is a set of multiple services exposed to the end users
as HTTP(s) APIs. Additionally, for own internal usage OpenStack
requires SQL database server and AMQP broker. The physical servers,
where all the components are running are often called controllers.
This modular OpenStack architecture allows to duplicate all the
components and run them on different controllers.
By making all the components redundant it is possible to make
OpenStack highly-available.

In general we can divide all the OpenStack components into three categories:

- OpenStack APIs, these are HTTP(s) stateless services written in python,
  easy to duplicate and mostly easy to load balance.

- SQL relational database server provides stateful type consumed by other
  components. Supported databases are MySQL, MariaDB, and PostgreSQL.
  Making SQL database redundant is complex.

- :term:`Advanced Message Queuing Protocol (AMQP)` provides OpenStack
  internal stateful communication service.

Network components
~~~~~~~~~~~~~~~~~~

[TODO Need discussion of network hardware, bonding interfaces,
intelligent Layer 2 switches, routers and Layer 3 switches.]

The configuration uses static routing without
Virtual Router Redundancy Protocol (VRRP)
or similar techniques implemented.

[TODO Need description of VIP failover inside Linux namespaces
and expected SLA.]

See [TODO link] for more information about configuring networking
for high availability.

Common deployement architectures
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

There are primarily two HA architectures in use today.

One uses a cluster manager such as Pacemaker or Veritas to co-ordinate
the actions of the various services across a set of machines. Since
we are focused on FOSS, we will refer to this as the Pacemaker
architecture.

The other is optimized for Active/Active services that do not require
any inter-machine coordination. In this setup, services are started by
your init system (systemd in most modern distributions) and a tool is
used to move IP addresses between the hosts. The most common package
for doing this is keepalived.

.. toctree::
   :maxdepth: 1

   intro-ha-arch-pacemaker.rst
   intro-ha-arch-keepalived.rst


Database (MySQL/Galera)
~~~~~~~~~~~~~~~~~~~~~~~

MySQL with Galera can be configured
using one of the following strategies:

- Each instance has its own IP address;
  OpenStack services are configured with the list of these IP addresses
  so they can select one of the addresses from those available.

- The MySQL/Galera cluster runs behind HAProxy.
  HAProxy the load balances incoming requests
  and exposes just one IP address for all the clients.

  Galera synchronous replication guarantees a zero slave lag.
  The failover procedure completes once HAProxy detects
  that the active back end has gone down and switches to the backup one,
  which is then marked as 'UP'.
  If no back ends are up (in other words,
  the Galera cluster is not ready to accept connections),
  the failover procedure finishes only when
  the Galera cluster has been successfully reassembled.
  The SLA is normally no more than 5 minutes.

- Use MySQL/Galera in active/passive mode
  to avoid deadlocks on ``SELECT ... FOR UPDATE`` type queries
  (used, for example, by nova and neutron).
  This issue is discussed more in the following:

  - `http://lists.openstack.org/pipermail/openstack-dev/2014-May/035264.html`
  - `http://www.joinfu.com/`
  - `http://www.joinfu.com/`

Memcached back end
~~~~~~~~~~~~~~~~~~

Memcached is a memory cache demon that can be used
by most OpenStack services to store ephemeral data, such as tokens.
Although Memcached does not support
typical forms of redundancy such as clustering,
OpenStack services can use almost any number of instances
by configuring multiple hostnames or IP addresses.
The Memcached client implements hashing
to balance objects among the instances.
Failure of an instance only impacts a percentage of the objects
and the client automatically removes it from the list of instances.
The SLA is several minutes.

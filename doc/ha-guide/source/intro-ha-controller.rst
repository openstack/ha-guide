========================================
Overview of highly-available controllers
========================================

A highly-available OpenStack environment
must have a controller cluster with three or more nodes.
The following components are normally included in the cluster.

[TODO Discuss SLA (Service Level Agreement), if this is the measure we use.
Other possibilities include MTTR (Mean Time To Recover),
RTO (Recovery Time Objective),
and ETR (Expected Time of Repair,]

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

Load balancing (HAProxy)
~~~~~~~~~~~~~~~~~~~~~~~~

HAProxy is a load balancer that runs on each controller in the cluster
but does not synchronize the state.
Each instance of HAProxy configures its frontend to accept connections
only from the Virtual IP (VIP) address and to terminate them
as a list of all instances of the corresponding service under load balancing.
For example, any OpenStack API service.
This makes the instances of HAProxy act independently
and fail over transparently
together with the Network endpoints (VIP addresses) failover
and shares the same SLA.

See [TODO link] for information about configuring HAProxy.

Database (MySQL/Galera)
~~~~~~~~~~~~~~~~~~~~~~~

MySQL with Galera can be configured
using one of the following strategies:

- Each instance has its own IP address;
  OpenStack services are configured with the list of these IP addresses
  so they can select on of the addresses from those available.

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


AMQP (RabbitMQ)
~~~~~~~~~~~~~~~

RabbitMQ nodes fail over both on the application
and the infrastructure layers.
The application layer is controlled by
the ``oslo.messaging`` configuration options
for multiple AMQP hosts. If the AMQP node fails,
the application reconnects to the next one configured
within the specified reconnect interval.
The specified reconnect interval constitutes its SLA.
On the infrastructure layer,
the SLA is the time for which RabbitMQ cluster reassembles.
Several cases are possible.
The Mnesia keeper node is the master
of the corresponding Pacemaker resource for RabbitMQ;
when it fails, the result is a full AMQP cluster downtime interval.
Normally, its SLA is no more than several minutes.
Failure of another node that is a slave
of the corresponding Pacemaker resource for RabbitMQ
results in no AMQP cluster downtime at all.

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

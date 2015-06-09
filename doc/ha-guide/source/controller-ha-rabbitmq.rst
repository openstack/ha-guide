========
RabbitMQ
========

RabbitMQ is the default AMQP server used by many OpenStack services.
Making the RabbitMQ service highly available involves the following steps:

- :ref:`Install RabbitMQ<rabbitmq-install>`

- :ref:`Configure RabbitMQ for HA queues<rabbitmq-configure>`

- :ref:`Configure OpenStack services to use Rabbit HA queues
  <rabbitmq-services>`

.. _rabbitmq-install:

Install RabbitMQ
~~~~~~~~~~~~~~~~

The commands for installing RabbitMQ are specific to the Linux distribution
you are using:

.. list-table:: Install RabbitMQ
   :widths: 15 30
   :header-rows: 1

   * - Distribution
     - Command
   * - Ubuntu, Debian
     - :command:`# apt-get install rabbitmq-server rabbitmq-plugins`
   * - RHEL, Fedora, CentOS
     - :command:`# yum install rabbitmq-server`
   * - openSUSE
     - :command:`# zypper install rabbitmq-server`
   * - SLES 12
     - :command:`# zypper addrepo -f obs://Cloud:OpenStack:Kilo/SLE_12 Kilo`

       [Verify fingerprint of imported GPG key; see below]

       :command:`# zypper install rabbitmq-server`


.. note::

         For SLES 12, the packages are signed by GPG key 893A90DAD85F9316.
         You should verify the fingerprint of the imported GPG key before using it.

         ::

            Key ID: 893A90DAD85F9316
            Key Name: Cloud:OpenStack OBS Project <Cloud:OpenStack@build.opensuse.org>
            Key Fingerprint: 35B34E18ABC1076D66D5A86B893A90DAD85F9316
            Key Created: Tue Oct  8 13:34:21 2013
            Key Expires: Thu Dec 17 13:34:21 2015

For more information,
see the official installation manual for the distribution:

- `Debian and Ubuntu <http://www.rabbitmq.com/install-debian.html>`_
- `RPM based <http://www.rabbitmq.com/install-rpm.html>`_
  (RHEL, Fedora, CentOS, openSUSE)

.. _rabbitmq-configure:

Configure RabbitMQ for HA queues
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

[TODO: This section should begin with a brief mention
about what HA queues are and why they are valuable, etc]

We are building a cluster of RabbitMQ nodes to construct a RabbitMQ broker,
which is a logical grouping of several Erlang nodes.

The following components/services can work with HA queues:

[TODO: replace "currently" with specific release names]

[TODO: Does this list need to be updated?  Perhaps we need a table
that shows each component and the earliest release that allows it
to work with HA queues.]

- OpenStack compute
- OpenStack block storage
- OpenStack networking
- Telemetry

We have to consider that, while exchanges and bindings
survive the loss of individual nodes,
queues and their messages do not
because a queue and its contents are located on one node.
If we lose this node, we also lose the queue.

Mirrored queues in RabbitMQ improve
the availability of service since it is resilient to failures.

Production servers should run (at least) three RabbitMQ servers;
for testing and demonstration purposes,
it is possible to run only two servers.
In this section, we congfigure two nodes,
called `rabbit1` and `rabbit2`.
To build a broker, we need to ensure
that all nodes have the same Erlang cookie file.

[TODO: Should the example instead use a minimum of three nodes?]

To do so, stop RabbitMQ everywhere and copy the cookie
from the first node to each of the other node(s):

.. code-block:: console

   # scp /var/lib/rabbitmq/.erlang.cookie root@NODE:/var/lib/rabbitmq/.erlang.cookie

On each target node, verify the correct owner,
group, and permissions of the file :file:`erlang.cookie`.

.. code-block:: console

   # chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
   # chmod 400 /var/lib/rabbitmq/.erlang.cookie

Start RabbitMQ on all nodes and verify that the nodes are running:

.. code-block:: console

   # rabbitmqctl cluster_status
   Cluster status of node rabbit@NODE...
   [{nodes,[{disc,[rabbit@NODE]}]},
    {running_nodes,[rabbit@NODE]},
    {partitions,[]}]
   ...done.

Run the following commands on each node except the first one:

.. code-block:: console

   # rabbitmqctl stop_app
   Stopping node rabbit@NODE...
   ...done.
   # rabbitmqctl join_cluster rabbit@rabbit1
   # rabbitmqctl start_app
   Starting node rabbit@NODE ...
   ...done.

To verify the cluster status:

.. code-block:: console

   # rabbitmqctl cluster_status
   Cluster status of node rabbit@NODE...
   [{nodes,[{disc,[rabbit@rabbit1]},{ram,[rabbit@NODE]}]}, \
       {running_nodes,[rabbit@NODE,rabbit@rabbit1]}]

If the cluster is working,
you can create usernames and passwords for the queues.

To ensure that all queues except those with auto-generated names
are mirrored across all running nodes,
set the `ha-mode` policy key to all
by running the following command on one of the nodes:

.. code-block:: console

   # rabbitmqctl set_policy ha-all '^(?!amq\.).*' '{"ha-mode": "all"}'

More information is available in the RabbitMQ documentation:

- `Highly Available Queues <http://www.rabbitmq.com/ha.html>`_
- `Clustering Guide <https://www.rabbitmq.com/clustering.html>`_


.. _rabbitmq-services:

Configure OpenStack services to use Rabbit HA queues
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We have to configure the OpenStack components
to use at least two RabbitMQ nodes.

Do this configuration on all services using RabbitMQ:

- RabbitMQ HA cluster host:port pairs:
  [TODO: Add rabbit3 if you agree]

  ::

     rabbit_hosts=rabbit1:5672,rabbit2:5672

- How frequently to retry connecting with RabbitMQ:
  [TODO: document the unit of measure here?  Seconds?]

  ::

     rabbit_retry_interval=1

- How long to back-off for between retries when connecting to RabbitMQ:
  [TODO: document the unit of measure here?  Seconds?]

  ::

     rabbit_retry_backoff=2

- Maximum retries with trying to connect to RabbitMQ (infinite by default):

  ::

     rabbit_max_retries=0

- Use durable queues in RabbitMQ:

  ::

     rabbit_durable_queues=true

- Use HA queues in RabbitMQ (x-ha-policy: all):

  ::

     rabbit_ha_queues=true

.. note::

   If you change the configuration from an old set-up
   that did not use HA queues, you should restart the service:

.. code-block:: console

       # rabbitmqctl stop_app
       # rabbitmqctl reset
       # rabbitmqctl start_app

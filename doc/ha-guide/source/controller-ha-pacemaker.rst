
=======================
Pacemaker cluster stack
=======================

OpenStack infrastructure high availability relies on the
`Pacemaker <http://clusterlabs.org/>`_ cluster stack,
the state-of-the-art high availability and load balancing stack
for the Linux platform.
Pacemaker is storage and application-agnostic,
and is in no way specific to OpenStack.

Pacemaker relies on the
`Corosync <http://corosync.github.io/corosync/>`_ messaging layer
for reliable cluster communications.
Corosync implements the Totem single-ring ordering and membership protocol.
It also provides UDP and InfiniBand based messaging,
quorum, and cluster membership to Pacemaker.

Pacemaker does not inherently (need or want to) understand the
applications it manages. Instead, it relies on resource agents (RAs),
scripts that encapsulate the knowledge of how to start, stop, and
check the health of each application managed by the cluster.

These agents must conform to one of the
`OCF <https://github.com/ClusterLabs/OCF-spec/blob/master/ra/resource-agent-api.md>`_,
`SYS-V <http://refspecs.linux-foundation.org/LSB_3.0.0/LSB-Core-generic/LSB-Core-generic/iniscrptact.html>`_,
Upstart, or Systemd standards.

Pacemaker ships with a large set of OCF agents (such as those managing
MySQL databases, virtual IP addresses, and RabbitMQ), but can also use
any agents already installed on your system and can be extended with
your own (see the
`developer guide <http://www.linux-ha.org/doc/dev-guides/ra-dev-guide.html>`_).

The steps to implement the Pacemaker cluster stack are:

- :ref:`pacemaker-install`
- :ref:`pacemaker-corosync-setup`
- :ref:`pacemaker-corosync-start`
- :ref:`pacemaker-start`
- :ref:`pacemaker-cluster-properties`



.. _pacemaker-install:

Install packages
~~~~~~~~~~~~~~~~

On any host that is meant to be part of a Pacemaker cluster,
you must first establish cluster communications
through the Corosync messaging layer.
This involves installing the following packages
(and their dependencies, which your package manager
usually installs automatically):

- pacemaker (Note that the crm shell should be downloaded separately.)

- crmsh

- corosync

- cluster-glue

- fence-agents (Fedora only;
  all other distributions use fencing agents from cluster-glue)

- resource-agents

.. _pacemaker-corosync-setup:

Set up Corosync
~~~~~~~~~~~~~~~

After installing the Corosync package, you must create
the :file:`/etc/corosync/corosync.conf` configuration file.
Corosync can be configured to work
with either multicast or unicast IP addresses
or to use the votequorum library.

- :ref:`corosync-multicast`
- :ref:`corosync-unicast`
- :ref:`corosync-votequorum`


.. _corosync-multicast:

Set up Corosync with multicast
------------------------------

Most distributions ship an example configuration file
(:file:`corosync.conf.example`)
as part of the documentation bundled with the Corosync package.
An example Corosync configuration file is shown below:

Example Corosync configuration file for multicast (corosync.conf)
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

::

   totem {
         version: 2

         # Time (in ms) to wait for a token (1)
         token: 10000

        # How many token retransmits before forming a new
        # configuration
        token_retransmits_before_loss_const: 10

        # Turn off the virtual synchrony filter
        vsftype: none

        # Enable encryption (2)
        secauth: on

        # How many threads to use for encryption/decryption
        threads: 0

        # This specifies the redundant ring protocol, which may be
        # none, active, or passive. (3)
        rrp_mode: active

        # The following is a two-ring multicast configuration. (4)
        interface {
                ringnumber: 0
                bindnetaddr: 192.168.42.0
                mcastaddr: 239.255.42.1
                mcastport: 5405
        }
        interface {
                ringnumber: 1
                bindnetaddr: 10.0.42.0
                mcastaddr: 239.255.42.2
                mcastport: 5405
        }
   }

   amf {
        mode: disabled
   }

   service {
           # Load the Pacemaker Cluster Resource Manager (5)
           ver:       1
           name:      pacemaker
   }

   aisexec {
           user:   root
           group:  root
   }

   logging {
           fileline: off
           to_stderr: yes
           to_logfile: no
           to_syslog: yes
           syslog_facility: daemon
           debug: off
           timestamp: on
           logger_subsys {
                   subsys: AMF
                   debug: off
                   tags: enter|leave|trace1|trace2|trace3|trace4|trace6
           }}

Note the following:

- The ``token`` value specifies the time, in milliseconds,
  during which the Corosync token is expected
  to be transmitted around the ring.
  When this timeout expires, the token is declared lost,
  and after ``token_retransmits_before_loss_const lost`` tokens,
  the non-responding processor (cluster node) is declared dead.
  In other words, ``token × token_retransmits_before_loss_const``
  is the maximum time a node is allowed to not respond to cluster messages
  before being considered dead.
  The default for token is 1000 milliseconds (1 second),
  with 4 allowed retransmits.
  These defaults are intended to minimize failover times,
  but can cause frequent "false alarms" and unintended failovers
  in case of short network interruptions.
  The values used here are safer, albeit with slightly extended failover times.

- With ``secauth`` enabled,
  Corosync nodes mutually authenticate using a 128-byte shared secret
  stored in the :file:`/etc/corosync/authkey` file,
  which may be generated with the :command:`corosync-keygen` utility.
  When using ``secauth``, cluster communications are also encrypted.

- In Corosync configurations using redundant networking
  (with more than one interface),
  you must select a Redundant Ring Protocol (RRP) mode other than none.
  ``active`` is the recommended RRP mode.

  Note the following about the recommended interface configuration:

  - Each configured interface must have a unique ``ringnumber``,
    starting with 0.

  - The ``bindnetaddr`` is the network address of the interfaces to bind to.
    The example uses two network addresses of /24 IPv4 subnets.

  - Multicast groups (``mcastaddr``) must not be reused
    across cluster boundaries.
    In other words, no two distinct clusters
    should ever use the same multicast group.
    Be sure to select multicast addresses compliant with
    `RFC 2365, "Administratively Scoped IP Multicast"
    <http://www.ietf.org/rfc/rfc2365.txt>`_.

  - For firewall configurations,
    note that Corosync communicates over UDP only,
    and uses ``mcastport`` (for receives)
    and ``mcastport - 1`` (for sends).

- The service declaration for the pacemaker service
  may be placed in the :file:`corosync.conf` file directly
  or in its own separate file, :file:`/etc/corosync/service.d/pacemaker`.

  .. note::

           If you are using Corosync version 2 on Ubuntu 14.04,
           remove or comment out lines under the service stanza,
           which enables Pacemaker to start up.



- Once created, the :file:`corosync.conf` file
  (and the :file:`authkey` file if the secauth option is enabled)
  must be synchronized across all cluster nodes.


.. _corosync-unicast:

Set up Corosync with unicast
----------------------------

For environments that do not support multicast,
Corosync should be configured for unicast.
An example fragment of the :file:`corosync.conf` file
for unicastis shown below:

Corosync configuration file fragment for unicast (corosync.conf)
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

::

   totem {
           #...
           interface {
                   ringnumber: 0
                   bindnetaddr: 192.168.42.0
                   broadcast: yes (1)
                   mcastport: 5405
           }
           interface {
                   ringnumber: 1
                   bindnetaddr: 10.0.42.0
                   broadcast: yes
                   mcastport: 5405
           }
           transport: udpu (2)
   }

   nodelist { (3)
           node {
                   ring0_addr: 192.168.42.1
                   ring1_addr: 10.0.42.1
                   nodeid: 1
           }
           node {
                   ring0_addr: 192.168.42.2
                   ring1_addr: 10.0.42.2
                   nodeid: 2
           }
   }
   #...

Note the following:

- If the ``broadcast`` parameter is set to yes,
  the broadcast address is used for communication.
  If this option is set, the ``mcastaddr`` parameter should not be set.

- The ``transport`` directive controls the transport mechanism used.
  To avoid the use of multicast entirely,
  specify the ``udpu`` unicast transport parameter.
  This requires specifying the list of members
  in the ``nodelist`` directive;
  this could potentially make up the membership before deployment.
  The default is ``udp``.
  The transport type can also be set to ``udpu`` or ``iba``.

- Within the ``nodelist`` directive,
  it is possible to specify specific information
  about the nodes in the cluster.
  The directive can contain only the node sub-directive,
  which specifies every node that should be a member of the membership,
  and where non-default options are needed.
  Every node must have at least the ``ring0_addr`` field filled.

  .. note::

           For UDPU, every node that should be a member
           of the membership must be specified.

  Possible options are:

  - ``ring{X}_addr`` specifies the IP address of one of the nodes.
    {X} is the ring number.

  - ``nodeid`` is optional
    when using IPv4 and required when using IPv6.
    This is a 32-bit value specifying the node identifier
    delivered to the cluster membership service.
    If this is not specified with IPv4,
    the node id is determined from the 32-bit IP address
    of the system to which the system is bound with ring identifier of 0.
    The node identifier value of zero is reserved and should not be used.


.. _corosync-votequorum:

Set up Corosync with votequorum library
---------------------------------------

The votequorum library is part of the corosync project.
It provides an interface to the vote-based quorum service
and it must be explicitly enabled in the Corosync configuration file.
The main role of votequorum library is to avoid split-brain situations,
but it also provides a mechanism to:

- Query the quorum status

- Get a list of nodes known to the quorum service

- Receive notifications of quorum state changes

- Change the number of votes assigned to a node

- Change the number of expected votes for a cluster to be quorate

- Connect an additional quorum device
  to allow small clusters remain quorate during node outages

The votequorum library has been created to replace and eliminate
qdisk, the disk-based quorum daemon for CMAN,
from advanced cluster configurations.

A sample votequorum service configuration
in the :file:`corosync.com` file is:

::

    quorum {
            provider: corosync_votequorum (1)
            expected_votes: 7 (2)
            wait_for_all: 1 (3)
            last_man_standing: 1 (4)
            last_man_standing_window: 10000 (5)
           }

Note the following:

- Specifying ``corosync_votequorum`` enables the votequorum library;
  this is the only required option.

- The cluster is fully operational with ``expected_votes`` set to 7 nodes
  (each node has 1 vote), quorum: 4.
  If a list of nodes is specified as ``nodelist``,
  the ``expected_votes`` value is ignored.

- Setting ``wait_for_all`` to 1 means that,
  When starting up a cluster (all nodes down),
  the cluster quorum is held until all nodes are online
  and have joined the cluster for the first time.
  This parameter is new in Corosync 2.0.

- Setting ``last_man_standing`` to 1 enables
  the Last Man Standing (LMS) feature;
  by default, it is disabled (set to 0).
  If a cluster is on the quorum edge
  (``expected_votes:``set to 7; ``online nodes:`` set to 4)
  for longer than the time specified
  for the ``last_man_standing_window`` parameter,
  the cluster can recalculate quorum and continue operating
  even if the next node will be lost.
  This logic is repeated until the number of online nodes
  in the cluster reaches 2.
  In order to allow the cluster to step down from 2 members to only 1,
  the ``auto_tie_breaker`` parameter needs to be set;
  this is not recommended for production environments.

- ``last_man_standing_window`` specifies the time, in milliseconds,
   required to recalculate quorum after one or most hosts
   have been lost from the cluster.
   To do the new quorum recalculation,
   the cluster must have quorum for at least the interval
   specified for  ``last_man_standing_window``;
   the default is 10000ms.


.. _pacemaker-corosync-start:

Start Corosync
~~~~~~~~~~~~~~

Corosync is started as a regular system service.
Depending on your distribution, it may ship with an LSB init script,
an upstart job, or a systemd unit file.
Either way, the service is usually named corosync:

- :command:`# /etc/init.d/corosync start` (LSB)

- :command:`# service corosync start` (LSB, alternate)

- :command:`# start corosync (upstart)`

- :command:`# systemctl start corosync (systemd)`

You can now check the Corosync connectivity with two tools.

Use the :command:`corosync-cfgtool` utility with the -s option
to get a summary of the health of the communication rings:

::

    # corosync-cfgtool -s
        Printing ring status.
    Local node ID 435324542
    RING ID 0
            id      = 192.168.42.82
            status  = ring 0 active with no faults
    RING ID 1
            id      = 10.0.42.100
            status  = ring 1 active with no faults

Use the :command:`corosync-objctl` utility
to dump the Corosync cluster member list:

::

    # corosync-objctl runtime.totem.pg.mrp.srp.members
        runtime.totem.pg.mrp.srp.435324542.ip=r(0) ip(192.168.42.82) r(1) ip(10.0.42.100)
    runtime.totem.pg.mrp.srp.435324542.join_count=1
    runtime.totem.pg.mrp.srp.435324542.status=joined
    runtime.totem.pg.mrp.srp.983895584.ip=r(0) ip(192.168.42.87) r(1) ip(10.0.42.254)
    runtime.totem.pg.mrp.srp.983895584.join_count=1
    runtime.totem.pg.mrp.srp.983895584.status=joined

You should see a ``status=joined`` entry
for each of your constituent cluster nodes.

[TODO: Should the main example now use corosync-cmapctl and have the note
give the command for Corosync version 1?]

.. note::
         If you are using Corosync version 2,
         use the :command:`corosync-cmapctl` utility
         instead of :command:`corosync-objctl`;
         it is a direct replacement.

.. _pacemaker-start:

Start Pacemaker
~~~~~~~~~~~~~~~

After the Corosync services have been started
and you have verified that the cluster is communicating properly,
you can start :command:`pacemakerd`, the Pacemaker master control process:

- :command:`# /etc/init.d/pacemaker start` (LSB)

- :command:`# service pacemaker start` (LSB, alternate)

- :command:`# start pacemaker` (upstart)

- :command:`# systemctl start pacemaker` (systemd)

After the Pacemaker services have started,
Pacemaker creates a default empty cluster configuration with no resources.
Use the :command:`crm_mon` utility to observe the status of Pacemaker:

::

    ============
    Last updated: Sun Oct  7 21:07:52 2012
    Last change: Sun Oct  7 20:46:00 2012 via cibadmin on node2
    Stack: openais
    Current DC: node2 - partition with quorum
    Version: 1.1.6-9971ebba4494012a93c03b40a2c58ec0eb60f50c
    2 Nodes configured, 2 expected votes
    0 Resources configured.
    ============

    Online: [ node2 node1 ]


.. _pacemaker-cluster-properties:

Set basic cluster properties
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

After you set up your Pacemaker cluster,
you should set a few basic cluster properties
using one of the following methods:

- Start the :command:`crm` shell
  and enter :command:`configure` to change into the configuration menu.
- Type :command:`crm configure` from a shell prompt
  to jump straight into the Pacemaker configuration menu.

Set the following properties:

::

    property no-quorum-policy="ignore" \ #  1
      pe-warn-series-max="1000" \        #  2
      pe-input-series-max="1000" \
      pe-error-series-max="1000" \
      cluster-recheck-interval="5min"    #  3

Note the following:

.. hard-coded numbers are used here because they are essentially footnotes
   to the code block.

1. Production environments should not set the
   `` no-quorum-policy="ignore"`` parameter.

   The`` no-quorum-policy="ignore"`` parameter
   is required in 2-node Pacemaker clusters to disable quorum enforcement.
   if quorum enforcement is enabled and one of the two nodes fails,
   then the remaining node can not establish the majority of quorum votes
   that are necessary to run services.
   This means that it is unable to take over any resources.
   Ignoring loss of quorum in the cluster avoids this problem
   and is appropriate for small configurations used
   for study or demonstration purposes.
   Clusters that ignore lose of quorum are vulnerable to split-brain
   because, if both nodes remain online but lose communication with each other,
   either node may become active.

2. Setting the ``pe-warn-series-max``, ``pe-input-series-max``
   and ``pe-error-series-max`` parameters to 1000
   instructs Pacemaker to keep a longer history of the inputs processed
   and errors and warnings generated by its Policy Engine.
   This history is useful if you need to troubleshoot the cluster.

3. Pacemaker uses an event-driven approach to cluster state processing.
   The ``cluster-recheck-interval`` parameter (which defaults to 15 minutes)
   defines the interval at which certain Pacemaker actions occur.
   It is usually prudent to reduce this to a shorter interval,
   such as 5 or 3 minutes.

After you make these changes, you may commit the updated configuration.


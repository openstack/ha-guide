
==============
Hardware setup
==============

The standard hardware requirements:

- `Neutron <http://docs.openstack.org/juno/install-guide/install/apt/content/ch_overview.html#example-architecture-with-neutron-networking-hw>`_
- `Nova-network <http://docs.openstack.org/juno/install-guide/install/apt/content/ch_overview.html#example-architecture-with-legacy-networking-hw>`_

However, OpenStack does not require a significant amount of resources
and the following minimum requirements should support
a proof-of-concept high availability environment
with core services and several instances:

[TODO: Verify that these numbers are good]

+-------------------+------------+----------+---------+
| Node type         | Processor  | Memory   | Storage |
+===================+============+==========+=========+
| Controller node   | 3          | 2 GB     | 5 GB    |
+-------------------+------------+----------+---------+
| Network node      | 3          | 512 MB   | 5 GB    |
+-------------------+------------+----------+---------+
| Compute node      | 3          | 2 GB     | 10 GB   |
+-------------------+------------+----------+---------+


For demonstrations and studying,
you can set up a test environment on virtual machines (VMs).
This has the following benefits:

- One physical server can support multiple nodes,
  each of which supports almost any number of network interfaces.

- Ability to take periodic "snap shots" throughout the installation process
  and "roll back" to a working configuration in the event of a problem.

However, running an OpenStack environment on VMs
degrades the performance of your instances,
particularly if your hypervisor and/or processor lacks support
for hardware acceleration of nested VMs.

.. note::

   When installing highly-available OpenStack on VMs,
   be sure that your hypervisor permits promiscuous mode
   and disables MAC address filtering on the external network.


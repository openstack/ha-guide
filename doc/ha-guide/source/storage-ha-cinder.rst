.. highlight: ini
   :linenothreshold: 5

==================================
Highly available Block Storage API
==================================

Making the Block Storage API service (cinder) highly available
in active/passive mode involves:

- :ref:`ha-cinder-pacemaker`
- :ref:`ha-cinder-configure`
- :ref:`ha-cinder-services`

.. _ha-cinder-pacemaker:

Add Block Storage API resource to Pacemaker
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You must first download the resource agent to your system:

.. code-block:: console

   # cd /usr/lib/ocf/resource.d/openstack
   # wget https://git.openstack.org/cgit/openstack/openstack-resource-agents/plain/ocf/cinder-api
   # chmod a+rx *

You can now add the Pacemaker configuration
for Block Storage API resource.
Connect to the Pacemaker cluster
with the :command:`crm configure` command
and add the following cluster resources:

::

   primitive p_cinder-api ocf:openstack:cinder-api \
      params config="/etc/cinder/cinder.conf"
      os_password="secretsecret"
      os_username="admin" \
      os_tenant_name="admin"
      keystone_get_token_url="http://192.168.42.103:5000/v2.0/tokens" \
      op monitor interval="30s" timeout="30s"

This configuration creates ``p_cinder-api``,
a resource for managing the Block Storage API service.

The command :command:`crm configure` supports batch input,
so you may copy and paste the lines above
into your live pacemaker configuration and then make changes as required.
For example, you may enter ``edit p_ip_cinder-api``
from the :command:`crm configure` menu
and edit the resource to match your preferred virtual IP address.

Once completed, commit your configuration changes
by entering :command:`commit` from the :command:`crm configure` menu.
Pacemaker then starts the Block Storage API service
and its dependent resources on one of your nodes.

.. _ha-cinder-configure:

Configure Block Storage API service
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Edit the :file:`/etc/cinder/cinder.conf` file:

.. code-block:: ini
   :linenos:

   # We have to use MySQL connection to store data:
   sql_connection = mysql://cinder:password@192.168.42.101/cinder
   # Alternatively, you can switch to pymysql,
   # a new Python 3 compatible library and use
   # sql_connection = mysql+pymysql://cinder:password@192.168.42.101/cinder
   # and be ready when everything moves to Python 3.
   # Ref: https://wiki.openstack.org/wiki/PyMySQL_evaluation

   # We bind Block Storage API to the VIP:
   osapi_volume_listen = 192.168.42.103

   # We send notifications to High Available RabbitMQ:
   notifier_strategy = rabbit
   rabbit_host = 192.168.42.102


.. _ha-cinder-services:

Configure OpenStack services to use highly available Block Storage API
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Your OpenStack services must now point their
Block Storage API configuration to the highly available,
virtual cluster IP address
rather than a Block Storage API server’s physical IP address
as you would for a non-HA environment.

You must create the Block Storage API endpoint with this IP.

If you are using both private and public IP addresses,
you should create two virtual IPs and define your endpoint like this:

.. code-block:: console

   $ keystone endpoint-create --region $KEYSTONE_REGION \
      --service-id $service-id \
      --publicurl 'http://PUBLIC_VIP:8776/v1/%(tenant_id)s' \
      --adminurl 'http://192.168.42.103:8776/v1/%(tenant_id)s' \
      --internalurl 'http://192.168.42.103:8776/v1/%(tenant_id)s'



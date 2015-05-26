
=================
Configure the VIP
=================

You must select and assign a virtual IP address (VIP)
that can freely float between cluster nodes.

This configuration creates `p_ip_api`,
a virtual IP address for use by the API node (192.168.42.103):

::

    primitive p_api-ip ocf:heartbeat:IPaddr2 \
    params ip="192.168.42.103" cidr_netmask="24" \
    op monitor interval="30s"

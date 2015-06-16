
=======================
Database (Galera/MySQL)
=======================

The first step is installing the database that sits at the heart of the
cluster. To implement High Availability, run an instance of the database on
each controller node, using Galera for synchronous multi-master replication.
The Galera Cluster plug-in is a multi-master cluster based on synchronous
replication. It is a high availability service that provides high system
uptime, no data loss, and scalability for growth.

High Availability for the OpenStack database
can be achieved in many different ways,
depending on the type of database
that is used in a particular installation.
Galera can be used with any of the following:

- MySQL is the most common choice;
  the next section tells how to configure Galera/MySQL.
- `MariaDB Galera Cluster <https://mariadb.org/>`_
  is supported for environments based on Red Hat distributions;
  configuration instructions are in :ref:`maria-db-ha`.
- `Percona XtraDB Cluster <http://www.percona.com/>`_
  works with Galera.
- You can also use PostgreSQL, which has its own replication,
  or another database HA option.

[TODO: the structure of the MySQL and MariaDB sections should be made parallel]

Install the MySQL database on the primary database server
---------------------------------------------------------

Install a version of MySQL patched for wsrep (Write Set REPlication)
from `https://launchpad.net/codership-mysql`.
The wsrep API supports synchronous replication
and so is suitable for configuring MySQL High Availability in OpenStack.

You can find additional information about installing and configuring
Galera/MySQL in:

- `wsrep readme file <https://launchpadlibrarian.net/66669857/README-wsrep>`_
- `Galera Getting Started guide <http://galeracluster.com/documentation-webpages/gettingstarted.html>`_

#.  Install the software properties, the key, and the repository;
    For Ubuntu 14.04 "trusty", the command sequence is:

    [TODO: provide instructions for SUSE and Red Hat]

    ::

      # apt-get install software-properties-common
      # apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
      # add-apt-repository 'deb http://ams2.mirrors.digitalocean.com/mariadb/repo/5.5/ubuntu trusty main'

    .. note ::

       You can choose a different mirror from the list at
       `downloads.mariadb.org <https://downloads.mariadb.org>`_

#. Update your system and install the required packages:

    ::

      # apt-get update
      # apt-get install mariadb-galera-server

    .. note ::

       The galara package is now called galera-3 and is already a dependency
       of mariadb-galera-server. Therefore it should not be specified on the
       command line.


    .. warning ::

       If you have already installed MariaDB, installing Galera will purge all privileges;
       you must re-apply all the permissions listed in the installation guide.

#. Adjust the configuration by making the following changes to the
   :file:`/etc/mysql/my.cnf` file:

   ::

     query_cache_size=0
     binlog_format=ROW
     default_storage_engine=innodb
     innodb_autoinc_lock_mode=2
     innodb_doublewrite=1

#. Create the :file:`/etc/mysql/conf.d/wsrep.cnf` file;
   paste the following lines into this file:

   ::

     [mysqld]
     wsrep_provider=/usr/lib/galera/libgalera_smm.so
     wsrep_cluster_name="Openstack"
     wsrep_sst_auth=wsrep_sst:wspass
     wsrep_cluster_address="gcomm://{PRIMARY_NODE_IP},{SECONDARY_NODE_IP},{TERTIARY_NODE_IP}"
     wsrep_sst_method=rsync
     wsrep_node_address="{PRIMARY_NODE_IP}"
     wsrep_node_name="{NODE_NAME}"

   - Replace (PRIMARY_NODE_IP}, {SECONDARY_NODE}, and (TERTIARY__NODE_IP}
     with the IP addresses of your servers.

   - Replace {NODE_NAME} with the hostname of the server.
     This is set for logging.

   - Copy this file to all other databases servers and change
     the value of wsrep_cluster_address and wsrep_node_name accordingly.

#. Start :command:`mysql` as root and execute the following queries:

   ::

     mysql> SET wsrep_on=OFF; GRANT ALL ON *.* TO wsrep_sst@'%' IDENTIFIED BY 'wspass';

   Remove user accounts with empty user names because they cause problems:

   ::

    mysql> SET wsrep_on=OFF; DELETE FROM mysql.user WHERE user='';

#. Verify that the nodes can access each other through the firewall.
   On Red Hat, this means adjusting :manpage:`iptables(8)`, as in:

   ::

     # iptables --insert RH-Firewall-1-INPUT 1 --proto tcp \
       --source <my IP>/24 --destination <my IP>/32 --dport 3306 \
       -j ACCEPT
     # iptables --insert RH-Firewall-1-INPUT 1 --proto tcp \
       --source <my IP>/24 --destination <my IP>/32 --dport 4567 \
       -j ACCEPT


   You may also need to configure any NAT firewall between nodes to allow direct connections.
   You may need to disable SELinux
   or configure it to allow :command:`mysqld` to listen to sockets at unprivileged ports.
   See the `Firewalls and default ports
   <http://docs.openstack.org/kilo/config-reference/content/firewalls-default-ports.html>`_
   section of the Configuration Reference.

Configure the database on other database servers
------------------------------------------------

Next, you need to copy the database configuration to the other database
servers. Before doing this, make a backup copy of this file that you can use
to recover from an error:

  ::

     cd /etc/mysql
     cp debian.cnf debian.cnf.bak

#. Be sure that SSH root access is established for the other database servers.
   Then copy the :file:`debian.cnf` file to each other server
   and reset the file permissions and owner to reduce the security risk.
   Do this by issuing the following commands on the primary database server:

     ::

        # scp /etc/mysql/debian.cnf root@{IP-address}:/etc/mysql
        # ssh root@{IP-address} chmod 640 /etc/mysql/debian.cnf
        # ssh root@{IP-address} chown root /etc/mysql/debian.cnf

#. Use the following command after the copy to verify that all files are
   identical:

     ::

        # md5sum debian.cnf


#. You need to get the database password from the :file:`debian.cnf` file.
   You can do this with the following command:

     ::

        # cat /etc/mysql/debian.cnf

   The result will be similar to this:

     ::

       [client]
       host = localhost
       user = debian-sys-maint
       password = FiKiOY1Lw8Sq46If
       socket = /var/run/mysqld/mysqld.sock
       [mysql_upgrade]
       host = localhost
       user = debian-sys-maint
       password = FiKiOY1Lw8Sq46If
       socket = /var/run/mysqld/mysqld.sock
       basedir = /usr

   Alternately, you can run the following command to print out just the `password` line:

     ::

        # grep password /etc/mysql/debian.cnf

#. Now run the following query on each server other than the primary database
   node. This will ensure that you can restart the database again. You will
   need to supply the password you got in the previous step:

     ::

       mysql> GRANT SHUTDOWN ON *.* TO ‘debian-sys-maint’@’localhost' IDENTIFIED BY '<debian.cnf {password}>';
       mysql> GRANT SELECT ON `mysql`.`user` TO ‘debian-sys-maint’@’localhost' IDENTIFIED BY '<debian.cnf {password}>';

#. Stop all the mysql servers and start the first server with the following
   command:

     ::

       # service mysql start --wsrep-new-cluster

#. Start all the other nodes with the following command:

     ::

       # service mysql start

#. Verify the wsrep replication by logging in as root under mysql and running
   the following command:

     ::

       mysql> SHOW STATUS LIKE ‘wsrep%’;
       +------------------------------+--------------------------------------+
       | Variable_name                | Value                                |
       +------------------------------+--------------------------------------+
       | wsrep_local_state_uuid       | d6a51a3a-b378-11e4-924b-23b6ec126a13 |
       | wsrep_protocol_version       | 5                                    |
       | wsrep_last_committed         | 202                                  |
       | wsrep_replicated             | 201                                  |
       | wsrep_replicated_bytes       | 89579                                |
       | wsrep_repl_keys              | 865                                  |
       | wsrep_repl_keys_bytes        | 11543                                |
       | wsrep_repl_data_bytes        | 65172                                |
       | wsrep_repl_other_bytes       | 0                                    |
       | wsrep_received               | 8                                    |
       | wsrep_received_bytes         | 853                                  |
       | wsrep_local_commits          | 201                                  |
       | wsrep_local_cert_failures    | 0                                    |
       | wsrep_local_replays          | 0                                    |
       | wsrep_local_send_queue       | 0                                    |
       | wsrep_local_send_queue_avg   | 0.000000                             |
       | wsrep_local_recv_queue       | 0                                    |
       | wsrep_local_recv_queue_avg   | 0.000000                             |
       | wsrep_local_cached_downto    | 1                                    |
       | wsrep_flow_control_paused_ns | 0                                    |
       | wsrep_flow_control_paused    | 0.000000                             |
       | wsrep_flow_control_sent      | 0                                    |
       | wsrep_flow_control_recv      | 0                                    |
       | wsrep_cert_deps_distance     | 1.029703                             |
       |riaDB with Galera (Red Hat-based platforms) wsrep_apply_oooe             | 0.024752                             |
       | wsrep_apply_oool             | 0.000000                             |
       | wsrep_apply_window           | 1.024752                             |
       | wsrep_commit_oooe            | 0.000000                             |
       | wsrep_commit_oool            | 0.000000                             |
       | wsrep_commit_window          | 1.000000                             |
       | wsrep_local_state            | 4                                    |
       | wsrep_local_state_comment    | Synced                               |
       | wsrep_cert_index_size        | 18                                   |
       | wsrep_causal_reads           | 0                                    |
       | wsrep_cert_interval          | 0.024752                             |
       | wsrep_incoming_addresses     | <first IP>:3306,<second IP>:3306     |
       | wsrep_cluster_conf_id        | 2                                    |
       | wsrep_cluster_size           | 2                                    |
       | wsrep_cluster_state_uuid     | d6a51a3a-b378-11e4-924b-23b6ec126a13 |
       | wsrep_cluster_status         | Primary                              |
       | wsrep_connected              | ON                                   |
       | wsrep_local_bf_aborts        | 0                                    |
       | wsrep_local_index            | 1                                    |
       | wsrep_provider_name          | Galera                               |
       | wsrep_provider_vendor        | Codership Oy <info@codership.com>    |
       | wsrep_provider_version       | 25.3.5-wheezy(rXXXX)                 |
       | wsrep_ready                  | ON                                   |
       | wsrep_thread_count           | 2                                    |
       +------------------------------+--------------------------------------+


.. _maria-db-ha:

MariaDB with Galera (Red Hat-based platforms)
---------------------------------------------

MariaDB with Galera provides synchronous database replication in an
active-active, multi-master environment. High availability for the data itself
is managed internally by Galera, while access availability is managed by
HAProxy.

This guide assumes that three nodes are used to form the MariaDB Galera
cluster. Unless otherwise specified, all commands need to be executed on all
cluster nodes.

Procedure 6.1. To install MariaDB with Galera
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#.  Distributions based on Red Hat include Galera packages in their
    repositories. To install the most current version of the packages, run the
    following command:

    ::

       # yum install -y mariadb-galera-server xinetd rsync

#. (Optional) Configure the :file:`clustercheck` utility.

   [TODO: Should this be moved to some other place?]

   If HAProxy is used to load-balance client access to MariaDB
   as described in the HAProxy section of this document,
   you can use the :command:`clustercheck` utility to improve health checks.

   - Create the :file:`etc/sysconfig/clustercheck` file with the following
     contents:

     ::

        MYSQL_USERNAME="clustercheck"
        MYSQL_PASSWORD={PASSWORD}
        MYSQL_HOST="localhost"
        MYSQL_PORT="3306"

     .. warning ::

                   Be sure to supply a sensible password.

   - Configure the monitor service (used by HAProxy) by creating
     the :file:`/etc/xinetd.d/galera-monitor` file with the following contents:

     ::

       service galera-monitor
       {
          port = 9200
          disable = no
          socket_type = stream
          protocol = tcp
          wait = no
          user = root
          group = root
          groups = yes
          server = /usr/bin/clustercheck
          type = UNLISTED
          per_source = UNLIMITED
          log_on_success =
          log_on_failure = HOST
          flags = REUSE
       }

    - Create the database user required by :command:`clustercheck`:

      ::

        # systemctl start mysqld
        # mysql -e "CREATE USER 'clustercheck'@'localhost' IDENTIFIED BY 'PASSWORD';"
        # systemctl stop mysqld

    - Start the :command:`xinetd` daemon required by :command:`clustercheck`:

      ::

        # systemctl daemon-reload
        # systemctl enable xinetd
        # systemctl start xinetd

#. Configure MariaDB with Galera.

   - Create the :file:`/etc/my.cnf.d/galera.cnf` configuration file
     with the following content:

     ::

       [mysqld]
       skip-name-resolve=1
       binlog_format=ROW
       default-storage-engine=innodb
       innodb_autoinc_lock_mode=2
       innodb_locks_unsafe_for_binlog=1
       max_connections=2048
       query_cache_size=0
       query_cache_type=0
       bind_address=NODE_IP
       wsrep_provider=/usr/lib64/galera/libgalera_smm.so
       wsrep_cluster_name="galera_cluster"
       wsrep_cluster_address="gcomm://PRIMARY_NODE_IP, SECONDARY_NODE_IP, TERTIARY_NODE_IP"
       wsrep_slave_threads=1
       wsrep_certify_nonPK=1
       wsrep_max_ws_rows=131072
       wsrep_max_ws_size=1073741824
       wsrep_debug=0
       wsrep_convert_LOCK_to_trx=0
       wsrep_retry_autocommit=1
       wsrep_auto_increment_control=1
       wsrep_drupal_282555_workaround=0
       wsrep_causal_reads=0
       wsrep_notify_cmd=
       wsrep_sst_method=rsync

   - Open the firewall ports used for MariaDB and Galera communications:

     ::

         # firewall-cmd --add-service=mysql
         # firewall-cmd --add-port=4444/tcp
         # firewall-cmd --add-port=4567/tcp
         # firewall-cmd --add-port=4568/tcp
         # firewall-cmd --add-port=9200/tcp
         # firewall-cmd --add-port=9300/tcp
         # firewall-cmd --add-service=mysql --permanent
         # firewall-cmd --add-port=4444/tcp --permanent
         # firewall-cmd --add-port=4567/tcp --permanent
         # firewall-cmd --add-port=4568/tcp --permanent
         # firewall-cmd --add-port=9200/tcp --permanent
         # firewall-cmd --add-port=9300/tcp --permanent

   - Start the MariaDB cluster:

     - On node 1, run the following command:

       ::

         # sudo -u mysql /usr/libexec/mysqld --wsrep-cluster-address='gcomm://' &

     - On nodes 2 and 3, run the following command:

       ::

         systemctl start mariadb

     - After the output from the :command:`clustercheck` command is 200 on all nodes,
       restart the MariaDB on node 1 with the following command sequence:

       [TODO: is the kill command necessary here?]

       ::

         # kill <mysql PIDs>
         # systemctl start mariadb

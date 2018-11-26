=================================
OpenStack High Availability Guide
=================================

Abstract
~~~~~~~~

This guide describes how to install and configure OpenStack for high
availability. It supplements the Installation Guides
and assumes that you are familiar with the material in those guides.

.. warning::

   This guide is a work-in-progress and changing rapidly while we
   continue to test and enhance the guidance.  There are open TODO
   items throughout the guide which will be tracked on
   `the ha-guide Storyboard site
   <https://storyboard.openstack.org/#!/project/openstack/ha-guide>`_.
   There is also a `bug list corresponding to the old version of the
   guide
   <https://bugs.launchpad.net/openstack-manuals?field.tag=ha-guide>`_
   which need to be triaged, as some of those bugs may still be
   relevant in which case they need to be ported over to Storyboard.
   Please help where you are able.

.. toctree::
   :maxdepth: 1

   common/conventions.rst
   overview.rst
   intro-ha.rst
   intro-os-ha.rst
   control-plane.rst
   networking-ha.rst
   storage-ha.rst
   compute-node-ha.rst
   monitoring.rst
   testing.rst
   ref-arch-examples.rst
   ha-community.rst
   common/appendix.rst

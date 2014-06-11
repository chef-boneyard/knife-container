ohai Cookbook CHANGELOG
=======================
This file is used to list changes made in each version of the ohai cookbook.


v2.0.1 (2014-06-07)
-------------------
* [COOK-4683] Remove warnings about reopening resource

Please note, this changes the name of a remote_directory resource. It is not expected that anyone would be explicitly notifying this resource but, please review [PR #16](https://github.com/opscode-cookbooks/ohai/pull/16/files) for more info.


v2.0.0 (2014-02-25)
-------------------
'[COOK-3865] - create lwrp ohai_hint'


v1.1.12
-------
- Dummy release due to a Community Site upload failure

v1.1.10
-------
### Bug
- **[COOK-3091](https://tickets.opscode.com/browse/COOK-3091)** - Fix checking `Chef::Config[:config_file]`

v1.1.8
------
- [COOK-1918] - Ohai cookbook to distribute plugins fails on windows
- [COOK-2096] - Ohai cookbook sets unix-only default path attribute

v1.1.6
------
- [COOK-2057] - distribution from another cookbok fails if ohai attributes are loaded after the other cookbook

v1.1.4
------
- [COOK-1128] - readme update, Replace reference to deprecated chef cookbook with one to chef-client

v1.1.2
------
- [COOK-1424] - prevent plugin_path growth to infinity

v1.1.0
------
- [COOK-1174] - custom_plugins is only conditionally available
- [COOK-1383] - allow plugins from other cookbooks

v1.0.2
------
- [COOK-463] ohai cookbook default recipe should only reload plugins if there were updates

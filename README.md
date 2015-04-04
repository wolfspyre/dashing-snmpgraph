#Dashing-SnmpGraph

This aims to be a [Dashing](http://shopify.github.io/dashing/#overview) job and sample dashboard for visualizing SNMP data from your devices

##Installation

-	Clone [the repository](https://github.com/wolfspyre/dashing-snmpgraph)
-	Run the `scripts/deploy.sh` shell script, which will perform the needed actions to install this widget.
  - `./scripts/deploy.sh /home/pi/dashing-plugins/dashing-snmpgraph parent_dir_of_install dashboard_install_dir`
- Create `snmpgraph_whatever.yaml` file(s) in the `conf.d` directory. It is recommended to create one file per device, but that's completely arbitrary.
  - model this file from the example_snmpgraph_interfaces.yaml file in the `conf.d` directory. It will not be symlinked into your dashboard's `conf.d` directory, and is intended to provide an example of how to use this plugin.
-	Restart Dashing to pick up the new changes.
-	Navigate to the newly installed snmpgraph dashboard in your browser, and revel in the dashboardy goodness.

###Required Widgets

The graphs depend on [Jason Walton's Rickshawgraph plugin](https://gist.github.com/jwalton/6614023). The process for installation is pretty straightforward. You should review the installation instructions contained within the repo, as they may supersede these; but this should get you going. There are two ways to do it.

-	Manual Installation

	-	Create a `rickshawgraph` directory in the `widgets` directory of your dashboard installation.
	-	Place the [rickshawgraph.coffee](https://gist.github.com/jwalton/6614023/raw/07c3a382845fbc27e0523d7f2de43e43e0904c4b/rickshawgraph.coffee), [rickshawgraph.html](https://gist.github.com/jwalton/6614023/raw/da626313b868c685e515db19bfd98c68db13d649/rickshawgraph.html), and [rickshawgraph.scss](https://gist.github.com/jwalton/6614023/raw/8d1fbd74b4915b3b96b899b7c723cf078cf53fc9/rickshawgraph.scss) file, the Inside the newly created `widgets\rickshawgraph` directory
	-	Restart Dashing.

-	Automatic Installation

	-	from within your dashboard directory; install the gist with the `dashing install` command:
		-	`dashing install 6614023`
	-	Restart Dashing.

---

##Configuration

The `snmpgraph-defaults.yaml` file tunes the behavior of the job. it is meant to provide you an example configuration of the configurable parameters. You are meant to create an `snmpgraph-overrides.yaml` file in the `conf.d` directory with your overrides to these settings. This permits you to update the default configuration file automatically, while simultaneously maintaining a custom local configuration. You are additionally meant to create as many `snmpgraph_something_here.yaml`  files as you wish. The job will consume poll them.

It is important to note that the job will read any file matching `conf.d/snmpgraph_.*.yaml` and turn that into graph elements.

###Configuration Parameters

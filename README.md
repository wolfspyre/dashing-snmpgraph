#Dashing-SnmpGraph

This aims to be a [Dashing](http://shopify.github.io/dashing/#overview) widget, with a job and sample dashboard for visualizing SNMP data from your devices

##Installation

-	Clone [the repository](https://github.com/wolfspyre/dashing-snmpgraph)
-	Run the `scripts/deploy.sh` shell script, which will perform the needed actions to install this widget.
  - `./scripts/deploy.sh /home/pi/dashing-plugins/dashing-snmpgraph parent_dir_of_install dashboard_install_dir`
- Create `snmpgraph_whatever.yaml` file(s) in the `conf.d` directory just outside your `dashboard_install_dir`. It is recommended to create one file per device, but that's only to ease management.
  - model this file from the example_snmpgraph_interfaces.yaml file in the `conf.d`. It will not be symlinked into your dashboard's `conf.d` directory, and is intended to provide an example of how to use this plugin.
-	Restart Dashing to pick up the new changes.
-	Navigate to the newly installed snmpgraph dashboard in your browser, and revel in the dashboardy goodness.

###Required Widgets

The graphs depend on [Jason Walton's Rickshawgraph plugin](https://gist.github.com/jwalton/6614023).

It is important to note that as of 5/11/2015 the `bgcolor` support is only hacked in via [my fork of this plugin](https://gist.github.com/wolfspyre/0d03e9bcb63f6fac2541) Hopefully this (or something like it) will get merged in.

The process for installation is pretty straightforward. You should review the installation instructions contained within the repo, as they may supersede these; but this should get you going. There are two ways to do it.

-	Manual Installation of the Rickshawgraph plugin

	-	Create a `rickshawgraph` directory in the `widgets` directory of your dashboard installation.
	-	Place the [rickshawgraph.coffee](https://gist.github.com/jwalton/6614023/raw/07c3a382845fbc27e0523d7f2de43e43e0904c4b/rickshawgraph.coffee), [rickshawgraph.html](https://gist.github.com/jwalton/6614023/raw/da626313b868c685e515db19bfd98c68db13d649/rickshawgraph.html), and [rickshawgraph.scss](https://gist.github.com/jwalton/6614023/raw/8d1fbd74b4915b3b96b899b7c723cf078cf53fc9/rickshawgraph.scss) file, the Inside the newly created `widgets\rickshawgraph` directory
	-	Restart Dashing.

-	Automatic Installation of the Rickshawgraph plugin

	-	from within your dashboard directory; install the gist with the `dashing install` command:
		-	`dashing install 6614023`
	-	Restart Dashing.

---

##Configuration

We recommend using the [SafeYAML](https://github.com/dtao/safe_yaml) gem versus the builtin

The `snmpgraph-defaults.yaml` file tunes the behavior of the job. it is meant to provide you an example configuration of the configurable parameters. You are meant to create an `snmpgraph-overrides.yaml` file in the `conf.d` directory with your overrides to these settings. This permits you to update the default configuration file automatically, while simultaneously maintaining a custom local configuration. You are additionally meant to create as many `snmpgraph_device_you_are_polling.yaml`  files as you wish. The job will inspect these files when Dashing starts, and schedule polling jobs for them.

It is important to note that the job will read any file matching `conf.d/snmpgraph_.*.yaml` and turn that into graph elements. It will only evaluate these files when Dashing starts.

###Configuration Parameters



The value of the first element in your yamlfile(s) should be the nice name for dashboard set. It is recommended to have one yaml file per dashboard, unless you are displaying the data element on multiple dashboards.

The sub attributes of your graph are as follows:

`name`       - The name of this data source. This corresponds to the `data-id` attribute in your dashboard template.
`address`    - The IP address, or fqdn of the host being polled.
`community`  - The SNMP community to use when polling.
`connection` - What version of the SNMP protocol to use. `v2c` is recommended.
`depth`      - The number of elements to cap the timeseries array at. There seems to be a limit of 99. I am uncertain of why this is at this time.
`display-value-in-legend` - Whether or not to display the last value as well as the name in the legend. This may be enabled at a graph level, or an element level.
`bgcolor`    - **experimental** This is only functional with my fork of jwalton's module. I am not certain that it should remain in it's current implementation, and may be removed.
`entities`  - A Hash of oids you're going to poll:
The first element will be the nice name of the thing you are graphing. This will be displayed in the graph legend (if it is enabled)
There should be at least one sub element. the `oid` key. You must specify an OID to poll in order to actually get something from snmp. :)

Additional supported options are:
`color`
`mode` - 



    ## conf.d/snmpgraph_firewall.yaml
    myfw:
        - name: 'myfw_igb1'
          address: '10.1.8.1'
          community: 'example'
          connection: 'v2c'
          depth: 99
          bgcolor: '#9ad99b'
          entities:
            Err_In:
              oid: '1.3.6.1.2.1.2.2.1.14.2'
              color: '#082B08'
              invert: false
            Err_Out:
              oid: '1.3.6.1.2.1.2.2.1.20.2'
              color: '#186B19'
              invert: true
              mode: 'default'
            Kbps_Down:
              oid: '1.3.6.1.2.1.2.2.1.10.2'
              color: '#2DA62F'
              invert: true
              mode: 'octets_to_Kbps'
            kBps_Up:
              oid: '1.3.6.1.2.1.2.2.1.16.2'
              color: '#59CA5B'
              invert: false
              mode: 'octets_to_Kbps'

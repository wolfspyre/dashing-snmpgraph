#snmp_datarator.rb
#
require 'snmp'
require 'yaml'
require 'pry'
##############################################
# Load configuration
##############################################
SNMPGRAPH_CONFIG_DIR = File.join(File.expand_path('..'), "conf.d")
# should get inserted into graph_data by loading
#CONFIG_MAIN_FILE = File.join(SNMPGRAPH_CONFIG_DIR, "snmpgraph_devices.yaml")
SNMPGRAPH_GRAPH_DATA_FILE  = File.join(SNMPGRAPH_CONFIG_DIR, "snmpgraph-defaults.yaml")
#CONFIG_OVERRIDE_FILE = File.join(SNMPGRAPH_CONFIG_DIR, "snmp_interfaces_override.yaml")
#snmp_config = YAML.load_file(CONFIG_MAIN_FILE)
graph_data = YAML.load_file(SNMPGRAPH_GRAPH_DATA_FILE)
#if File.exists?(CONFIG_OVERRIDE_FILE)
#  snmp_config = snmp_config.merge(YAML.load_file(CONFIG_OVERRIDE_FILE))
#end

#
#shove all the files containing things to graph into a single element for
#iteration. TODO: should we do this differently?
Dir[File.join(SNMPGRAPH_CONFIG_DIR, "snmpgraph_*.yaml")].each do |graph_file|
  graph_data['graphs'] << YAML.load_file(graph_file)
end
@snmpgraph_depth_max=99
@snmpgraph_poll_interval=graph_data['polling_options']['interval']
@snmpgraph_history_file=graph_data['history']['file']
@snmpgraph_history_enable=graph_data['history']['enable']
@snmpgraph_history_frequency=graph_data['history']['write_frequency']
warn "SNMPGraph: Poll interval: #{@snmpgraph_poll_interval}"
warn "SNMPGraph: History file: #{@snmpgraph_history_file}"
warn "SNMPGraph: History enable: #{@snmpgraph_history_enable}"
warn "SNMPGraph: History frequency: #{@snmpgraph_history_frequency}"
if @snmpgraph_history_enable
  warn   "SnmpGraph: History enabled"
  snmpGraphHistoryFile=@snmpgraph_history_file
  if File.exists?(snmpGraphHistoryFile)
    warn   "SnmpGraph: History file exists"
    snmpgraph_history = YAML.load_file(snmpGraphHistoryFile)
  else
    warn   "SnmpGraph: New history file initialized"
    snmpGraph_history=Hash.new
    snmpGraph_history.to_yaml
#    warn   "SnmpGraph: History: #{snmpGraph_history}"
    File.open(snmpGraphHistoryFile, "w") { |f|
      f.write snmpGraph_history
    }
  end
end
graph_data['graphs'].each do |data_view|
  #iterate through each top element of the graphs array. Each element should
  #have a slew of graphs for which to poll a collection of snmp devices
  if data_view.is_a?(Array)
    _view=data_view[0]
    data_view.each do |data_view_graph|
      if data_view_graph.is_a?(Array)
        #this should be the data which should be used to generate one specific
        #graph. This should correspond to the 'example_graph_0' entity in the
        #example file
        data_view_graph.each do |this_graph|
          if this_graph.is_a?(Hash)
            #this should be the graph elements
            #create the SNMP request
            this_graph['entities'].each do |polled_entity|
              _name = polled_entity[0]
              _oid  = polled_entity['oid']
              #fetch or initialize the time series array
              if @snmpgraph_history_enable
                if snmpGraph_history["#{_name}_#{_oid}_datapoints"] && !snmpGraph_history["#{_name}_#{_oid}_datapoints"].empty?
                  warn "SnmpGraph: History enabled. Populating "#{_name}_#{_oid}_datapoints" from file."
                  instance_variable_set("@#{_name}_#{_oid}_datapoints", snmpGraph_history["#{_name}_#{_oid}_datapoints"])
                else
                  warn "SnmpGraph: History enabled but #{_name}_#{_oid}_datapoints nonexistent or empty. Creating"
                  instance_variable_set("@#{_name}_#{_oid}_datapoints", Array.new)
                  snmpGraph_history["#{_name}_#{_oid}_datapoints"]=Array.new
                end
              else
                #warn "SnmpGraph: History disabled. Initializing #{_name}_#{_oid}_datapoints data"
                instance_variable_set("@#{_name}_#{_oid}_datapoints", Array.new)
              end
            end
            SCHEDULER.every "#{@snmpgraph_poll_interval}s", first_in: 0 do
              #create the job
              warn "SNMPGraph: Starting"
              job_graphite = []
              this_graph['entities'].each do |polled_entity|
                warn "SNMPGraph: #{polled_entitiy}"
                manager = SNMP::Manager.new(:host => this_graph['address'], :community => this_graph['community'])
                _name   = polled_entity[0]
                _oid    = polled_entity['oid']
                _data   = manager.get_value(_oid).to_i
                now     = Time.now.to_i
                job_now = [_data,now]
                warn "SNMPGraph: #{_now} Name: #{_name} OID: #{_oid} Value: #{_data}"
                _foo = instance_variable_get("@#{_name}_#{_oid}_datapoints")
                _foo << job_now
                instance_variable_set("@#{_name}_#{_oid}_datapoints", _foo)
                _entity_hash = Hash.new
                _entity_hash['target'] = _name
                _entity_hash['datapoints'] = _foo
                job_graphite << _entity_hash
              end#polled entity for this job
            end#this graph job
          end
        end#this_graph iterator
      end#data_view iterator
    end#dashboard entity
  end#dashboard array iterator
end#graph_data['graphs'] iterator
SCHEDULER.every "#{@snmpgraph_history_frequency}s", first_in: 0 do
  if @snmpgraph_history_enable
#    warn "SnmpGraph: History Job enabled"
    snmpGraph_history.each_pair do |k,v|
      if v.length >= @snmpgraph_graph_depth.to_i
#        warn "SnmpGraph: History depth: #{k}: #{v.length} Trimming"
        snmpGraph_history[k]= v.drop(1)
#        warn "SnmpGraph: History depth: now #{octoprint_history[k].length}"
      else
#        warn "SnmpGraph: History depth: #{k}: #{v.length} "
      end
    end
#      warn "SnmpGraph: History job Writing #{snmpGraph_history} to #{@history_file}"
    warn "SnmpGraph: History job Writing to #{@snmpgraph_history_file}"
    File.open(@snmpgraph_history_file, 'w'){|f|
      f.write snmpGraph_history.to_yaml
    }
  else
    warn "SnmpGraph: History disabled"
  end
end

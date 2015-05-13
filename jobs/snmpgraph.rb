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
#TODO: this should be a per graph tunable
@snmpgraph_graph_depth=99
@snmpgraph_poll_interval=graph_data['polling_options']['interval']
@snmpgraph_history_file=graph_data['history']['file']
@snmpgraph_history_enable=graph_data['history']['enable']
@snmpgraph_history_frequency=graph_data['history']['write_frequency']
@bgcolor_enable=graph_data['graph_options']['bgcolor_enable']
@bgcolor_default=graph_data['graph_options']['bgcolor']
#warn "SNMPGraph: Graph Datafile: #{SNMPGRAPH_GRAPH_DATA_FILE}"
#warn "SNMPGRAPH: Graph data: #{graph_data}"
#warn "SNMPGraph: Poll interval: #{@snmpgraph_poll_interval}"
#warn "SNMPGraph: History file: #{@snmpgraph_history_file}"
#warn "SNMPGraph: History enable: #{@snmpgraph_history_enable}"
#warn "SNMPGraph: History frequency: #{@snmpgraph_history_frequency}"
#warn "SNMPGraph: Graph Depth: #{@snmpgraph_graph_depth}"

def octetsToXps(last_octet_count,last_unixtime,current_octet_count,current_unixtime,output='mbps')
  if last_unixtime == current_unixtime
    xps_out = 0
  else
    octets  = current_octet_count - last_octet_count
    seconds = current_unixtime - last_unixtime
    #octets (bytes) -> bits
    bits = octets * 8
    bps = bits / seconds
    case output
      #http://www.matisse.net/bitcalc/
    when 'bps'
      xps_out = bps.to_f
    when 'kbps'
      xps = (bps/1024)
      xps_out = xps.to_f
    when 'mbps'
      xps = (bps/1024000)
      xps_out = xps.to_f
    else
      #assume mbps
      xps = (bps/1024000)
      xps_out= xps.to_f
    end
    #warn "SNMPGraph octetsToXps: octets: #{octets} seconds: #{seconds} bits: #{bits} bps: #{bps} #{output}: #{xps_out}"
  end
#  warn "SNMPGraph: #{octets} #{bits} #{seconds} #{bps} #{xps_out}"
 xps_out
end

if @snmpgraph_history_enable
  warn   "SnmpGraph: History enabled"
  snmpGraphHistoryFile=@snmpgraph_history_file
  if File.exists?(snmpGraphHistoryFile)
    warn   "SnmpGraph: History file exists"
    snmpGraph_history = YAML.load_file(snmpGraphHistoryFile)
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
  #warn "SNMPGraph: Data View: #{data_view}"
  #iterate through each top element of the graphs array. Each element should
  #have a slew of graphs for which to poll a collection of snmp devices
  if data_view.is_a?(Hash)
    #warn "SNMPGraph: data_view is a Hash"
    _view=data_view[0]
    data_view.each do |data_view_iterator|
      if data_view_iterator.is_a?(Array)
        #warn "SNMPGraph: data_view_iterator is an Array"
        data_view_iterator.each do |data_view_graph|
          #warn "SNMPGraph: data_view_graph: #{data_view_graph}"
          if data_view_graph.is_a?(Array)
            #warn "SNMPGraph: data_view_graph is an array"
            #this should be the data which should be used to generate one specific
            #graph. This should correspond to the 'example_graph_0' entity in the
            #example file
            data_view_graph.each do |this_graph|
              #warn "SNMPGraph: this_graph: #{this_graph}"
              if this_graph.is_a?(Hash)
                #warn "SNMPGraph: this_graph is a Hash."
                #warn "SNMPGraph: this_graph: #{this_graph}"
                #this should be the graph elements
                #create the SNMP request
                _num_entities = this_graph['entities'].count
                this_graph['entities'].each do |polled_entity|
                  #warn "SNMPGraph: polled_entity: #{polled_entity}"
                  if !polled_entity[1]['oid']
                    warn "SNMPGraph: #{polled_entity[0]} Skipping. no OID found."
                  else
                    _name = polled_entity[0]
                    _oid  = polled_entity[1]['oid'].to_i
                    #fetch or initialize the time series array
                    if @snmpgraph_history_enable
                      if snmpGraph_history["#{this_graph['name']}_#{_name}_datapoints"] && !snmpGraph_history["#{this_graph['name']}_#{_name}_datapoints"].empty?
                        #warn "SnmpGraph: History enabled. Populating #{this_graph['name']}_#{_name}_datapoints from file."
                        instance_variable_set("@#{this_graph['name']}_#{_name}_datapoints", snmpGraph_history["#{this_graph['name']}_#{_name}_datapoints"])
                      else
                        warn "SnmpGraph: History enabled but #{this_graph['name']}_#{_name}_datapoints nonexistent or empty. Creating"
                        instance_variable_set("@#{this_graph['name']}_#{_name}_datapoints", Array.new)
                        snmpGraph_history["#{this_graph['name']}_#{_name}_datapoints"]=Array.new
                      end
                    else
                      #warn "SnmpGraph: History disabled. Initializing #{this_graph['name']}_#{_name}_datapoints data"
                      instance_variable_set("@#{this_graph['name']}_#{_name}_datapoints", Array.new)
                    end
                  end
                end
                SCHEDULER.every "#{@snmpgraph_poll_interval}s", first_in: 0 do
                  #create the job
                  #warn "SNMPGraph: Starting job for #{this_graph['name']}"
                  job_graphite = []
                  lowest   = 0
                  now      = Time.now.to_i
                  if this_graph['bgcolor']
                    bgcolor = this_graph['bgcolor']
                  else
                    bgcolor = @bgcolor_default
                  end
                  _num_colors   = 0
                  _graph_colors = ''
                  this_graph['entities'].each do |polled_entity|
                    if !polled_entity[1]['oid']
                      warn "SNMPGraph: #{this_graph['name']}: #{polled_entity[0]} Skipping. no OID found."
                    else
                      #warn "SNMPGraph: #{this_graph['name']}: #{polled_entity[0]}"
                      manager  = SNMP::Manager.new(:host => this_graph['address'], :community => this_graph['community'])
                      _name    = polled_entity[0]
                      _oid     = polled_entity[1]['oid']
                      #TODO: work with jwalton to get this supported.
                      #if polled_entity[1]['renderer']
                      #  _renderer = polled_entity[1]['renderer']
                      #else
                      #  #todo set default dynamically
                      #  _renderer = 'area'
                      #end
                      if polled_entity[1]['color'] and polled_entity[1]['color'] != 'undef'
                        _num_colors = _num_colors + 1
                        if _graph_colors.bytesize > 0
                          _graph_colors = "#{_graph_colors}:#{polled_entity[1]['color']}"
                        else
                          _graph_colors = "#{polled_entity[1]['color']}"
                        end
                      end
                      _rawdata = manager.get_value(_oid).to_i
                      manager.close
                      if polled_entity[1]
                        mode   = polled_entity[1]['mode']
                      else
                        mode   = 'default'
                      end
                      #store and convert if necessary for the mode and item.
                      case mode
                      when 'octets_to_Mbps', 'octets_to_Kbps', 'octets_to_bps'
                        case mode
                        when 'octets_to_Mbps'
                          _output='mbps'
                        when 'octets_to_Kbps'
                          _output='kbps'
                        when 'octets_to_bps'
                          _output=bps
                        end
                        #we need to fetch the last timeseries data so that we can
                        #calculate Mbps from octets
                        if instance_variable_defined?("@#{this_graph['name']}_#{_name}_last")
                          last = instance_variable_get("@#{this_graph['name']}_#{_name}_last")
                          olddata = instance_variable_get("@#{this_graph['name']}_#{_name}_datapoints")
                          if !olddata.empty? && olddata.last[1]
                            lasttime = olddata.last[1]
                          else
                            #warn "SnmpGraph: #{this_graph['name']}_#{_name}: Couldn't fetch lasttime. using #{now}"
                            lasttime = now
                          end
                          #warn "SnmpGraph: Setting #{this_graph['name']}_#{_name}_last to #{_rawdata}. Was #{last}"
                          instance_variable_set("@#{this_graph['name']}_#{_name}_last", _rawdata)
                        else
                          #warn "SnmpGraph: #{this_graph['name']}_#{_name}: #{this_graph['name']}_#{_name}_last not set. Setting this datapoint to current"
                          instance_variable_set("@#{this_graph['name']}_#{_name}_last", _rawdata)
                          last = _rawdata
                          lasttime = now
                        end
                        #warn "SnmpGraph: #{this_graph['name']}_#{_name}: Last: #{last} LastTime: #{lasttime} Current: #{_rawdata}, now: #{now}"
                        _pre_invert_data = octetsToXps(last,lasttime,_rawdata,now,_output)
                        #_data = octetsToXps(last,lasttime,_rawdata,now,_output)
                      when 'default'
                        _pre_invert_data = _rawdata
                        #_data = _rawdata
                      else
                        _pre_invert_data = _rawdata
                        #_data = _rawdata
                      end
                      if polled_entity[1]['invert']
                        #figure out the floor
                        olddata = instance_variable_get("@#{this_graph['name']}_#{_name}_datapoints")
                        if instance_variable_defined?("@#{this_graph['name']}_lowest_val")
                          lowest      = instance_variable_get("@#{this_graph['name']}_lowest_val")
                          lowest_date = instance_variable_get("@#{this_graph['name']}_lowest_time")
                        else
                          lowest = 0
                          lowest_date = 0
                        end
                        olddata.each do |val,time|
                          if val < lowest then
                            instance_variable_set("@#{this_graph['name']}_lowest_val", val)
                            instance_variable_set("@#{this_graph['name']}_lowest_time", time)
                            lowest      = val
                            lowest_date = time
                          end
                        end
                        if _pre_invert_data > 0 then
                          _data = -_pre_invert_data;
                          #we have to set the invert max so we can pass data-min
                          if instance_variable_defined?("@#{this_graph['name']}_lowest_val")
                            lowest      = instance_variable_get("@#{this_graph['name']}_lowest_val")
                            lowest_date = instance_variable_get("@#{this_graph['name']}_lowest_time")
                            if lowest > _data
                              instance_variable_set("@#{this_graph['name']}_lowest_val", _data)
                              instance_variable_set("@#{this_graph['name']}_lowest_time", now)
                              lowest      = _data
                              lowest_date = now
                            end
                          else
                            lowest      = _data
                            lowest_date = now
                            instance_variable_set("@#{this_graph['name']}_lowest_val", _data)
                            instance_variable_set("@#{this_graph['name']}_lowest_time", now)
                          end
                        else
                          _data = _pre_invert_data
                        end
                      else
                        _data = _pre_invert_data
                      end
                      if instance_variable_defined?("@#{this_graph['name']}_lowest_val")
                        lowest = instance_variable_get("@#{this_graph['name']}_lowest_val")
                      else
                        lowest = 0
                      end
                      #warn "SnmpGraph: #{this_graph['name']}_#{_name}: Current: #{_data}, now: #{now} lowest: #{lowest}"
                      job_now = [_data,now]
                      #warn "SNMPGraph: #{this_graph['name']}: #{now} Name: #{_name} OID: #{_oid} Value: #{_data} job_now: #{job_now} "
                      _foo = instance_variable_get("@#{this_graph['name']}_#{_name}_datapoints")
                      #warn "SNMPGraph: #{this_graph['name']}: #{this_graph['name']}_#{_name} _foo set: #{_foo}"
                      if _foo.length >= @snmpgraph_graph_depth.to_i
                        #warn "SNMPGraph: #{this_graph['name']}_#{_name}_datapoints: graph_depth reached (#{_foo.length}). Dropping"
                        _foo = _foo.drop(_foo.length - @snmpgraph_graph_depth.to_i + 1)
                        #warn "SNMPGraph: #{this_graph['name']}_#{_name}_datapoints: graph_depth now (#{_foo.length})."
                      end
                      _foo << job_now
                      #warn "SNMPGraph: #{this_graph['name']}: #{this_graph['name']}_#{_name} _foo appended: #{_foo}"
                      instance_variable_set("@#{this_graph['name']}_#{_name}_datapoints", _foo)
                      #_bar = instance_variable_get("@#{this_graph['name']}_#{_name}_datapoints")
                      #warn "SNMPGraph: #{this_graph['name']}: #{this_graph['name']}_#{_name} _bar now: #{_bar}"
                      #warn "SNMPGraph: #{this_graph['name']}: #{this_graph['name']}_#{_name} _bar now: #{_bar.length} deep"
                      _entity_hash = Hash.new
                      _entity_hash['target'] = "#{_name}: #{_pre_invert_data}"
                      _entity_hash['datapoints'] = _foo
                      #TODO: Implement me
                      #_entity_hash['renderer'] = _renderer
                      job_graphite << _entity_hash
                      if @snmpgraph_history_enable
                        #warn "SNMPGraph: History enabled. appending to #{this_graph['name']}_#{_name}_datapoints object"
                        snmpGraph_history["#{this_graph['name']}_#{_name}_datapoints"] << job_now
                      end
                    end
                  end#polled entity for this job
                  #warn "SNMPGraph: Sending Event: job_graphite: #{this_graph['name']}  #{job_graphite}"
                  if @bgcolor_enable
                    #I can't guarantee my current implementation will be accepted as a PR, so giving us
                    #an option to not use this
                    if _num_entities == _num_colors
                      send_event(this_graph['name'], bgcolor: bgcolor, series: job_graphite, min: lowest, colors: _graph_colors)
                    else
                      #warn "SNMPGraph: #{this_graph['name']}: Got #{_num_colors} colors from yaml, but found #{_num_entities} elements. Not declaring colors. Colors assembled: #{_graph_colors}"
                      send_event(this_graph['name'], bgcolor: bgcolor, series: job_graphite, min: lowest )
                    end
                  end
                  if _num_entities == _num_colors
                    send_event(this_graph['name'], series: job_graphite, min: lowest, colors: _graph_colors)
                  else
                    send_event(this_graph['name'], series: job_graphite, min: lowest )
                    #warn "SNMPGraph: #{this_graph['name']}: Got #{_num_colors} colors from yaml, but found #{_num_entities} elements. Not declaring colors. Colors assembled: #{_graph_colors}"
                  end
                end#this graph job
              end
            end#this_graph iterator
          #else
          #warn "SNMPGraph: data_view_iterator is not an Array"
          end#data_view_iterator array
        end#data_view iterator
      end#data_view
    end#dashboard entity
  end#dashboard array iterator
end#graph_data['graphs'] iterator
SCHEDULER.every "#{@snmpgraph_history_frequency}s", first_in: 0 do
  if @snmpgraph_history_enable
#    warn "SnmpGraph: History Job enabled"
    snmpGraph_history.each_pair do |k,v|
      if v.length >= @snmpgraph_graph_depth.to_i
#        warn "SnmpGraph: History depth: #{k}: #{v.length} Trimming"
        snmpGraph_history[k]= v.drop(v.length - @snmpgraph_graph_depth.to_i + 1)
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

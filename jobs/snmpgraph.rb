#snmp_datarator.rb
#
require 'snmp'
#require 'yaml'
require 'safe_yaml'
require 'pry'
#
SafeYAML::OPTIONS[:default_mode] = :safe
SafeYAML::OPTIONS[:deserialize_symbols] = true
SafeYAML::OPTIONS[:raise_on_unknown_tag] = true

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
@snmpgraph_bgcolor_enable=graph_data['graph_options']['bgcolor_enable']
@snmpgraph_bgcolor_default=graph_data['graph_options']['bgcolor']
@snmpgraph_display_value_in_legend=graph_data['graph_options']['display-value-in-legend']
@snmpgraph_data_title=graph_data['graph_options']['data-title']

#warn "SNMPGraph: Graph Datafile: #{SNMPGRAPH_GRAPH_DATA_FILE}"
#warn "SNMPGRAPH: Graph data: #{graph_data}"
#warn "SNMPGraph: Poll interval: #{@snmpgraph_poll_interval}"
#warn "SNMPGraph: History file: #{@snmpgraph_history_file}"
#warn "SNMPGraph: History enable: #{@snmpgraph_history_enable}"
#warn "SNMPGraph: History frequency: #{@snmpgraph_history_frequency}"
#warn "SNMPGraph: Graph Depth: #{@snmpgraph_graph_depth}"

def counterToXps(last_count,last_unixtime,current_count,current_unixtime,output='mbps',input='octets')
  if last_unixtime == current_unixtime
    xps_out = 0
  else
    count  = current_count - last_count
    seconds = current_unixtime - last_unixtime
    #warn "SNMPGraph: counterToXps: count: #{count} Seconds: #{seconds}"
    #octets (bytes) -> bits
    case input

      #convert everything into 'units per second'.
      #leave ticks alone
      #convert octets to bits (units)
      #leave bits alone (unuts)
    when 'ticks'
      if output != 'ticks'
        #warn "SNMPGraph: counterToXps: cannot convert ticks to anything other than ticks. You asked me to convert ticks to #{output}. returning 0"
        units=0
      else
        units = count / seconds
      end
    when 'octets'
      units = (bytesTo(count,'bits')) / seconds
    when 'bits'
      units = count / seconds
    else
      warn "SNMPGraph: counterToXps: cannot convert #{input} to #{output}"
    end


    case output
      #http://www.matisse.net/bitcalc/
    when 'bps', 'ticks'
      xps_out = units
    when 'kbps'
      xps_out = bitsTo(units,'kilobits')
    when 'mbps'
      xps_out = bitsTo(units,'megabites')
    when 'Bps'
      xps_out = bitsTo(units,'bytes')
    when 'kBps', 'KBps'
      xps_out = bitsTo(units,'kilobytes')
    when 'mBps', 'MBps'
      xps_out = bitsTo(units,'megabytes')
    when 'gBps', 'GBps'
      xps_out = bitsTo(units,'gigabytes')
    when 'gBps', 'GBps'
      xps_out = bitsTo(units,'terabytes')
    else
      warn "SNMPGraph: counterToXps: cannot convert #{units} to #{output}"
    end
    #warn "SNMPGraph counterToXps: octets: #{octets} seconds: #{seconds} bits: #{bits} bps: #{bps} #{output}: #{xps_out}"
  end
#  warn "SNMPGraph: #{octets} #{bits} #{seconds} #{bps} #{xps_out}"
#display as float if    > 0.1 and < 10
if xps_out < 10  && xps_out > 0.1
   xps_out.to_f
 else
   xps_out.to_i
 end
end

def bytesTo(bytes,output='megabytes')
  case output
  when 'bits','units'
    _bytesToOutput = (bytes*8)
  when 'kilobytes'
    _bytesToOutput = (bytes/1000)
  when 'kilobits'
    _bytesToOutput = ((bytes/1000)*8)
  when 'megabytes'
    _bytesToOutput = (bytes/1000000)
  when 'megabits'
    _bytesToOutput = ((bytes/1000000)*8)
  when 'gigabytes'
    _bytesToOutput = (bytes/1000000000)
  when 'gigabits'
      _bytesToOutput = ((bytes/1000000000)*8)
  when 'terabytes'
    _bytesToOutput = (bytes/1000000000000)
  when 'terabytes'
    _bytesToOutput = ((bytes/1000000000000)*8)
  end
  _bytesToOutput
end

def bitsTo(bits,output='megabit')
  case output
  when 'bytes'
    _bitsToOutput = (bits/8)
  when 'kilobits'
    _bitsToOutput = (bits/1000)
  when 'kilobytes'
    _bitsToOutput = ((bits/1000)/8)
  when 'megabits'
    _bitsToOutput = (bits/1000000)
  when 'megabytes'
    _bitsToOutput = ((bits/1000000)/8)
  when 'gigabits'
    _bitsToOutput = (bits/1000000000)
  when 'gigabytes'
    _bitsToOutput = ((bits/1000000000)/8)
  when 'terabits'
    _bitsToOutput = (bits/1000000000000)
  when 'terabytes'
    _bitsToOutput = ((bits/1000000000000)/8)
  end
  _bitsToOutput
end

if @snmpgraph_history_enable
  warn   "SnmpGraph: History enabled"
  snmpGraphHistoryFile=@snmpgraph_history_file
  if File.exists?(snmpGraphHistoryFile)
    warn   "SnmpGraph: History file exists"
    snmpGraph_history = YAML.load_file(snmpGraphHistoryFile)
    if !snmpGraph_history
      warn "SNMPGraph: But YAML.load_file couldn't load it for some reason. Reinitializing"
      snmpGraph_history=Hash.new
      snmpGraph_history.to_yaml
  #    warn   "SnmpGraph: History: #{snmpGraph_history}"
      File.open(snmpGraphHistoryFile, "w") { |f|
        f.write snmpGraph_history
      }
    end
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
                      #warn "SNMPGraph: #{this_graph['name']}_#{_name}_datapoints"
                      if snmpGraph_history and snmpGraph_history["#{this_graph['name']}_#{_name}_datapoints"] and !snmpGraph_history["#{this_graph['name']}_#{_name}_datapoints"].empty?
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
                _poll_interval = this_graph['interval'] ? this_graph['interval'] : @snmpgraph_poll_interval
                _data_title = this_graph['data-title'] ? this_graph['data-title'] : @snmpgraph_data_title
                display_value_in_legend = this_graph['display-value-in-legend'] ? this_graph['display-value-in-legend'] : @snmpgraph_display_value_in_legend
                SCHEDULER.every "#{_poll_interval}s", first_in: 0 do
                  #create the job
                  #warn "SNMPGraph: Starting job for #{this_graph['name']}"
                  job_graphite = []
                  lowest   = 0
                  now      = Time.now.to_i
                  if this_graph['bgcolor']
                    bgcolor = this_graph['bgcolor']
                  else
                    bgcolor = @snmpgraph_bgcolor_default
                  end
                  _num_colors   = 0
                  _num_invert   = 0
                  _floor        = 0
                  _graph_colors = ''
                  manager  = SNMP::Manager.new(:host => this_graph['address'], :community => this_graph['community'])
                  this_graph['entities'].each do |polled_entity|
                    #calculate how many inverted elements we have
                    #do this so we can approximate that the "floor" should be the lowest number recieved by any inverted
                    #data sources multiplied by the number of inverted data sources.
                    if polled_entity[1]['invert']
                      _num_invert = _num_invert +1
                    end
                  end
                  #warn "SNMPGraph: #{this_graph['name']}: inverted data sources: #{_num_invert}"
                  this_graph['entities'].each do |polled_entity|
                    if !polled_entity[1]['oid']
                    warn "SNMPGraph: #{this_graph['name']}: #{polled_entity[0]} Skipping. no OID found."
                    else
                      #warn "SNMPGraph: #{this_graph['name']}: #{polled_entity[0]}"
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
                      #warn "SNMPGraph:  #{this_graph['name']}: #{_name} #{_oid} #{_rawdata}"

                      mode = ( polled_entity[1] || polled_entity[1]['mode'] ) ? polled_entity[1]['mode'] : 'default'
#                      if polled_entity[1]
#                        mode   = polled_entity[1]['mode']
#                      else
#                        mode   = 'default'
#                      end
                      #store and convert if necessary for the mode and item.
                      case mode
                      when 'octets_to_Mbps', 'octets_to_Kbps', 'octets_to_bps', 'bits_per_second', 'bytes_per_second','ticks_per_second'
                        case mode
                        when 'octets_to_Mbps'
                          _output='mbps'
                          _input = 'octets'
                        when 'octets_to_Kbps'
                          _output='kbps'
                          _input = 'octets'
                        when 'octets_to_bps'
                          _output='bps'
                          _input = 'octets'
                        when 'bits_per_second'
                          _output = 'bps'
                          _input = 'bits'
                          #we have to convert bits to bytes to use our
                        when 'bytes_per_second'
                          _output = 'Bps'
                          _input = 'octets'
                        when 'ticks_per_second'
                          _output = 'ticks'
                          _input = 'ticks'
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
                        case mode
                        when  'octets_to_Mbps', 'octets_to_Kbps', 'octets_to_bps','ticks_per_second'
                          #we should call counterToXps here
                          _pre_invert_data = counterToXps(last,lasttime,_rawdata,now,_output,_input)
                        #_data = counterToXps(last,lasttime,_rawdata,now,_output)
                        end
                      when 'bytes_to_MB', 'bytes_to_kB', 'bytes_to_megabytes', 'bytes_to_kilobytes'
                        case mode
                        when 'bytes_to_MB', 'bytes_to_megabytes'
                          _pre_invert_data = bytesTo(_rawdata,'megabytes')
                          #warn "SnmpGraph: #{this_graph['name']}_#{_name} bytes_to_MB: Current: #{_rawdata} _pre_invert_data: #{_pre_invert_data} now: #{now}"
                        when 'bytes_to_kB', 'bytes_to_kilobytes'
                          _pre_invert_data = bytesTo(_rawdata,'kilobytes')
                          #warn "SnmpGraph: #{this_graph['name']}_#{_name} bytes_to_kB: Current: #{_rawdata} _pre_invert_data: #{_pre_invert_data} now: #{now}"
                        end
                      when 'default'
                        _pre_invert_data = _rawdata
                      else
                        _pre_invert_data = _rawdata
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
                          #warn "SNMPGraph: #{this_graph['name']}_#{_name}: val: #{val} lowest: #{lowest}"
                          if val && lowest && val < lowest then
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
                            lowest      = instance_variable_defined?("@#{this_graph['name']}_lowest_val") ? instance_variable_get("@#{this_graph['name']}_lowest_val") : 0
                            lowest_date = instance_variable_defined?("@#{this_graph['name']}_lowest_val") ? instance_variable_get("@#{this_graph['name']}_lowest_time") : now
                            if lowest && lowest > _data
                              instance_variable_set("@#{this_graph['name']}_lowest_val", _data)
                              instance_variable_set("@#{this_graph['name']}_lowest_time", now)
                              lowest      = _data
                              lowest_date = now
                            end
                          else
                            lowest      = _data
                            lowest_date = now
                            instance_variable_set("@#{this_graph['name']}_lowest_val", lowest)
                            instance_variable_set("@#{this_graph['name']}_lowest_time", now)
                          end
                        else
                          _data = _pre_invert_data
                        end
                      else
                        _data = _pre_invert_data
                      end
                      if _num_invert > 0
                        lowest = instance_variable_defined?("@#{this_graph['name']}_lowest_val") ? instance_variable_get("@#{this_graph['name']}_lowest_val") : 0
                        #it's unlikely that all inverted entities are likely to be the peak lowest value
                        # assuming that the average is 75%. This is arbitrary
                        _floor = ((lowest * _num_invert) * 0.75)
                      else
                        #we have no inverted elements. Floor should be 0
                        _floor = 0
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
                      _entity_hash['target'] = _display_value_in_legend ? "#{_name}" : "#{_name}: #{_pre_invert_data}"
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
                  manager.close
                  #warn "SNMPGraph: Sending Event:  #{this_graph['name']} min: #{_floor} ( #{lowest} * #{_num_invert}) "
                  if @snmpgraph_bgcolor_enable
                    #I can't guarantee my current implementation will be accepted as a PR, so giving us
                    #an option to not use this
                    if _num_entities == _num_colors
                      send_event(this_graph['name'], bgcolor: bgcolor, series: job_graphite, min: _floor, colors: _graph_colors)
                    else
                      #warn "SNMPGraph: #{this_graph['name']}: Got #{_num_colors} colors from yaml, but found #{_num_entities} elements. Not declaring colors. Colors assembled: #{_graph_colors}"
                      send_event(this_graph['name'], bgcolor: bgcolor, series: job_graphite, min: _floor )
                    end
                  end
                  if _num_entities == _num_colors
                    send_event(this_graph['name'], series: job_graphite, min: _floor, colors: _graph_colors)
                  else
                    send_event(this_graph['name'], series: job_graphite, min: _floor )
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

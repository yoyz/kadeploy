#-*- coding: utf-8 -*-

require 'cmdctrl'
require 'socket'
require 'karate/config'

include CmdCtrl::Commands
include Karate

module Karate
  # Handle  one deployment  and  store its  informations, like  failed
  # nodes, elapsed time and also the deployment ID
  class Deployment
    attr_reader :nodes, :duration, :log, :failed_nodes, :kadeploy_cmd, :config, :id_deploy, :id_test

    def initialize(config, nodes, first_node, last_node, id_test=1,
                   nb_deploys=1, id_deploy=1)
      @config = config
      @nodes = nodes
      @id_test = id_test
      @nb_deploys = nb_deploys
      @first_node = first_node
      @last_node = last_node
      @id_deploy = id_deploy
      @deploy_finished = false

      if #{@config.fast_kernel_reboot}
          @kadeploy_cmd = "/usr/local/bin/kadeploy -d #{@config.device} -p #{@config.partition} -m #{@nodes.join(' -m ')} -dl 0 -e #{@config.environment} -fkr"
      else
          @kadeploy_cmd = "/usr/local/bin/kadeploy -d #{@config.device} -p #{@config.partition} -m #{@nodes.join(' -m ')} -dl 0 -e #{@config.environment}"
      end
      if not @config.ssh_hostname.nil?
        # Call  kadeploy  on  a  host  with an  old  version  of  ruby
        # installed, therefore  launch the script on  another host and
        # then execute on the target host
        @kadeploy_cmd = ("ssh -o BatchMode=yes -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t #{@config.ssh_hostname} #{@kadeploy_cmd}")
      end

      hostname = (@config.ssh_hostname.nil? and Socket.gethostname or @config.ssh_hostname)
      @log = "#{@config.output_dir}/kadeploy-#{hostname}-#{@config.started_date}-t#{@id_test}-#{@nb_deploys}d-#{@first_node}to#{@last_node}"
    end

    # Only the final report of kadeploy  is parsed in order to get the
    # errors
    def get_errors_from_log
      @failed_nodes = {}
      f = File::open("#{@log}.stdout")

      begin
        while line = f.gets
          # Get the errors
          if line =~ K_LOG_REGEX
            if @nodes.include?($1)
              # Store the error message
              @failed_nodes[$1] = $3 if $2 == 'error'
            else
              STDERR.puts "The node #{$1} shouldn't be in deployment ##{@id_deploy} " + 
                "(#{@nb_deploys} concurrent deployments), test ##{@id_test} (kadeploy bug)"
            end
          end
        end
      rescue
        raise
      ensure
        f.close unless f.nil?
      end
    end

    # Launch the deployment 
    def run
      tstart = Time::now

      # Run kadeploy and save stdout and stderr to a specific deployment
      # file
      @c = CommandBufferer::new(InteractiveCommand::new(@kadeploy_cmd))

      # Debug purpose: write the executed command line
      File::open("#{@log}.cmd", "w") { |f| f.puts(@kadeploy_cmd) }

      # This block is called when kadeploy is finished
      @c.on_exit do
        @duration = Time::now - tstart
        @c.save_stdout("#{@log}.stdout")
        @c.save_stderr("#{@log}.stderr")
        @deploy_finished = true
      end
      @c.run
    end

    # Wait for  the end of  the deployment process and  close properly
    # the logs
    def wait
      @c.wait_on_exit
      @c.close_fd
      get_errors_from_log
    end

    def get_nodes_h
      nodes_h = Hash::new
      @nodes.each { |node| nodes_h[node] = (@failed_nodes.key?(node) and @failed_nodes[node] or "") }
      nodes_h
    end

    def to_h
      { "id"       => @id_deploy,
        "duration" => @duration.to_i,
        "log"      => @log,
        "nodes"    => get_nodes_h }
    end

    # Display informations concerning a deployment
    def display_infos(sep="", depth=0)
      raise "This deployment isn't finished yet" unless @deploy_finished

      puts "#{sep * depth}Deployment ##{@id_deploy} (#{@duration.to_i}s)"
      puts "#{sep * (depth + 1)}Logs basename: #{@log}"
      puts "#{sep * (depth + 1)}Node(s) involved:"

      get_nodes_h.each do |node, err|
        print "#{sep * (depth + 2)}> #{node} "
        print " (Failed: #{@failed_nodes[node]})" unless err.empty?
        print "\n"
      end
    end

    private :get_errors_from_log, :get_nodes_h
  end
end

# Debug purpose
if $0 == __FILE__
  if ARGV.length < 3
    puts "Usage: ruby deployment.rb environment partition nodes"
    exit(1)
  end

  config = GlobalConfig::new
  config.environment = ARGV[0]
  config.partition = ARGV[1]
  nodes = ARGV[2, ARGV.length - 1]

  d = Deployment::new(config, nodes, 1, nodes.length)
  d.run
  d.wait
  d.display_infos
end

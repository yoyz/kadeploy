#-*- coding: utf-8 -*-

require 'karate/deployment'
require 'karate/config'

include Karate

module Karate
  # Launch ``nb_deploys'' deployments at the same time
  class ConcurrentDeployments
    attr_reader :nodes, :nb_deploys, :deploys, :duration, :id_test

    def initialize(config, nodes, nb_deploys, id_test=1)
      @config = config
      @nodes = nodes
      @nb_deploys = nb_deploys

      if @nb_deploys == 0
        raise "Invalid number of deployments"        
      elsif @nb_deploys > @nodes.length
        raise "#{@nb_deploys} node(s) are required for #{@nb_deploys} deployment(s), found #{@nodes.length} node(s)"
      end

      @id_test = id_test
      @deploys = Array::new
    end

    def run
      # Number of nodes for one deployment
      nb = @nodes.length / @nb_deploys
      first_node = 0
      started_date = Time::now

      @nb_deploys.times do |i|
        last_node = first_node + nb
 
        # Run a deployment and saves its output to the log file
        deploy = Deployment::new(@config, @nodes[first_node...last_node],
                                 first_node + 1, last_node, @id_test,
                                 @nb_deploys, i + 1)
        
        @deploys << deploy
        first_node += nb
      end

      # Run each deployment
      @deploys.each do |d|
        d.run

        # Workaround for kadeploy which may generate the same ID for
        # two concurrent deployments 
        sleep(K_SLEEP_WORKAROUND)
      end

      # Wait until all the deployments are over before starting the
      # next test with a different number of concurrent deployments
      @deploys.each { |d| d.wait }

      @duration = Time::now - started_date
    end

    def to_h
      raise "Call run before this method" if @deploys.empty?

      { "nb_deploys" => @nb_deploys,
        "duration"   => @duration.to_i,
        "deploys"    => @deploys.collect { |d| d.to_h } }
    end

    # Display informations about the concurrent deployments
    def display_infos(sep="", depth=0)
      raise "Use run before displaying informations" if @deploys.empty?

      puts "#{sep * depth}Ran #{@nb_deploys} simultaneous deployment(s) (#{@duration.to_i}s)"
      @deploys.each { |d| d.display_infos(sep, depth + 1) }
    end
  end
end

# DEBUG purpose
if $0 == __FILE__
  if ARGV.length < 4
    puts "Usage: ruby concurrent_deployments.rb environment partition nb_deploys nodes"
    exit(1)
  end

  config = GlobalConfig::new
  config.environment = ARGV[0]
  config.partition = ARGV[1]

  nb_deploys = ARGV[2].to_i
  nodes = ARGV[3, ARGV.length - 1]

  c = ConcurrentDeployments::new(config, nodes, nb_deploys)
  c.run
  c.display_infos
end

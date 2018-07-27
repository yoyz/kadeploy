#-*- coding: utf-8 -*-

require 'karate/concurrent_deployments'
require 'karate/config'

include Karate

module Karate
  # Launch  a  set of  deployments,  e.g.  run consecutive  concurrent
  # deployments
  class ConcurrentDeploymentsSet
    attr_reader :nodes, :cdeploys, :id_test, :cds

    def initialize(config, nodes, id_test=1)
      @config = config
      @nodes = nodes
      @id_test = id_test
      @cds = Array::new
    end

    def run
      # Number of deployments  running at the same time,  a maximum of
      # 2^MAX_CONCURRENT_DEPLOY can be started  if the number of nodes
      # allow it
      nb_concur = 1

      started_date = Time::now

      while nb_concur <= [@nodes.length, MAX_CONCURRENT_DEPLOY].min
        c = ConcurrentDeployments::new(@config, @nodes, nb_concur, @id_test)
        @cds << c

        c.run
        nb_concur *= 2
      end

      @duration = Time::now - started_date - K_SLEEP_WORKAROUND
    end

    def to_h
      raise "Call run before this method" if @cds.empty?

      { "id"           => @id_test,
        "duration"     => @duration.to_i,
        "test_deploys" => @cds.collect { |cd| cd.to_h } }
    end

    def display_infos(sep="", depth=0)
      raise "Use run before displaying informations" if @cds.empty?

      puts "#{sep * depth}Test ##{@id_test} (#{@duration.to_i}s)"
      @cds.each { |cd| cd.display_infos(sep, depth + 1) }
    end
  end
end

# DEBUG purpose
if $0 == __FILE__
  if ARGV.length < 3
    puts "Usage: ruby concurrent_deployments_set.rb environment partition nodes"
    exit(1)
  end

  config = GlobalConfig::new
  config.environment = ARGV[0]
  config.partition = ARGV[1]

  nodes = ARGV[2, ARGV.length - 1]

  c = ConcurrentDeploymentsSet::new(config, nodes)
  c.run
  c.display_infos
end

#-*- coding: utf-8 -*-

require 'karate/concurrent_deployments_set'
require 'karate/config'

include Karate

module Karate
  # ``nb_tests''  tests  are  launched,  a test  includes  consecutive
  # concurrent deployments
  class StressTests
    attr_reader :nodes, :nb_tests, :config
    
    def initialize(config, nodes)
      @config = config
      @nodes = nodes
      @sts = Array::new
    end

    def run
      started_date = Time::now

      @config.nb_tests.times do |i|
        c = ConcurrentDeploymentsSet::new(@config, @nodes, i + 1)
        @sts << c
        c.run
      end

      @duration = Time::now - started_date - K_SLEEP_WORKAROUND
    end

    # Compute the standard deviation from a list of values
    def standard_deviation(values)
      avg = average(values)
      stddev = 0
      values.each { |value| stddev += (value - avg) ** 2 }
      stddev = (1 / values.length.to_f) * stddev
      Math::sqrt(stddev.abs)
    end

    # Compute the average from a list of values
    def average(values)
      values.inject { |sum, i| sum + i } / values.length.to_f
    end

    # Get   the  stats  which   are  going   to  be   displayed  using
    # ``display_stats''
    def get_stats
      # Store   informations  about   the  duration   of  deployments,
      # dictionnary indexed by the number of concurrent deployments
      stats_nodes = Hash::new

      # Store  informations about  the  nodes which  failed for  every
      # tests,  dictionnary  indexed   by  the  number  of  concurrent
      # deployments
      stats_failures = Hash::new

      # Indexed by node and contains a list of errors
      failed_nodes = Hash::new

      @sts.each do |c|
        c.cds.each do |cd|
          n = cd.nb_deploys

          if not stats_failures.key?(n)
            stats_failures[n] = {'nb_nodes' => 0, 'nodes' => Array::new }
          end

          if not stats_nodes.key?(n)
            stats_nodes[n] = {'nb_nodes' => 0, 'durations' => Array::new }
          end

          cd.deploys.each do |d|
            stats_nodes[n]['nb_nodes'] = d.nodes.length
            stats_nodes[n]['durations'] << d.duration.to_i

            stats_failures[n]['nodes'] << d.failed_nodes.length
            stats_failures[n]['nb_nodes'] = d.nodes.length

            d.failed_nodes.each do |node, err|
              failed_nodes[node] = Array::new unless failed_nodes.key?(node)
              failed_nodes[node] << "#{err} (test ##{cd.id_test}, #{cd.nb_deploys} deployment(s), id: ##{d.id_deploy})"
            end
          end
        end
      end

      stats_nodes = stats_nodes.sort
      stats_failures = stats_failures.sort

      # Sort the  failed_nodes dictionnary depending on  the number of
      # errors
      failed_nodes = failed_nodes.to_a.sort { |node, errors| errors[1].length <=> node[1].length }   

      [stats_nodes, stats_failures, failed_nodes]
    end

    def display_failed_nodes(failed_nodes)
      failed_nodes.each do |node, errors|
        puts "+ #{node}"
        errors.each { |error| puts "  - #{error}" }
        puts
      end
    end

    def display_stats_nodes(stats_nodes)
      fmt = "%-15s%-10s%-10s%-10s%-10s\n"
      printf fmt, "conc. depl.", "min", "avg", "max", "stddev"

      stats_nodes.each do |nb_deploys, infos|
        durations, nb_nodes = infos['durations'], infos['nb_nodes']

        min = durations.min.to_i
        avg = average(durations).to_i
        max = durations.max.to_i
        stddev = "%.2f" % standard_deviation(durations)

        printf fmt, "#{nb_deploys} (#{nb_nodes}n * #{nb_deploys})", min, avg, max, stddev
      end
    end

    def display_stats_failures(stats_failures)
      fmt = "%-15s%-10s%-10s%-10s%-10s%-10s\n"
      printf fmt, "conc. depl.", "min", "avg", "max", "stddev", "nodes"

      stats_failures.each do |nb_deploys, infos|
        errors = infos['nodes']

        min = errors.min
        avg = "%.2f" % average(errors).to_f
        max = errors.max
        stddev = "%.2f" % standard_deviation(errors)
        pc = "%.2f%" % ((avg.to_f / infos['nb_nodes']) * 100)

        printf fmt, "#{nb_deploys} (#{infos['nb_nodes']}n * #{nb_deploys})", min, avg, max, stddev, pc
      end
    end

    def display_stats
      stats_nodes, stats_failures, failed_nodes = get_stats

      puts "*" * 20
      puts "Summary (ran #{@config.nb_tests}):"

      if not failed_nodes.empty?
        puts "* The following nodes failed"
        display_failed_nodes(failed_nodes)
      end
      
      puts '* Deployments duration per number of concurrents deployments (seconds)'
      display_stats_nodes(stats_nodes)
      puts

      puts "* Failures per number of concurrents deployments"
      display_stats_failures(stats_failures)
    end

    def to_h
      raise "Call run before this method" if @sts.empty?

      { "nb_tests" => @config.nb_tests,
        "duration" => @duration.to_i,
        "tests"    => @sts.collect { |cds| cds.to_h } }
    end

    # Display informations for each test which ran ``n'' deployments
    def display_infos(sep="", depth=0)
      raise "Use run before displaying informations" if @sts.empty?

      puts "#{sep * depth}Ran #{@config.nb_tests} test(s) (#{@duration.to_i}s)"
      @sts.each { |cds| cds.display_infos(sep, depth + 1)}
    end

    private :standard_deviation, :average, :display_failed_nodes, :display_stats_nodes, :display_stats_failures
  end
end

# DEBUG
if $0 == __FILE__
  if ARGV.length < 4
    puts "Usage: ruby stress_tests.rb environment partition nb_tests nodes"
    exit(1)
  end

  config = GlobalConfig::new
  config.environment = ARGV[0]
  config.partition = ARGV[1]
  config.nb_tests = ARGV[2].to_i

  nodes = ARGV[3, ARGV.length - 1]

  c = StressTests::new(config, nodes)
  c.run
  c.display_infos
end

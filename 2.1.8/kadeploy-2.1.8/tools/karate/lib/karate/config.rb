#-*- coding: utf-8 -*-

K_SLEEP_WORKAROUND = 10

# Modify this regex in order to get errors from the log
K_LOG_REGEX = /(^\w*\.\w*\.grid5000.fr)\s*(error|deployed)\s*(.*)\n/

# Number of concurrent deployments
MAX_CONCURRENT_DEPLOY = 8

module Karate
  # Store global configuration used by all the classes of the module
  class GlobalConfig
    attr_accessor :environment, :device, :partition, :ssh_hostname, :debug, :nb_tests, :started_date, :output_dir, :yaml, :fast_kernel_reboot
    
    def initialize
      @environment = @device = @partition = @ssh_hostname = nil
      @output_dir = "."
      @debug = @fast_kernel_reboot = false
      @nb_tests = 1
      @started_date = DateTime::now.strftime("%Y%m%d%H%M%S")
      @yaml = false
    end
  end
end

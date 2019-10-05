#!/usr/bin/env puma
require 'socket'

environment 'production'
daemonize false
pidfile '/run/isutrain/puma.pid'

# Use "path" as the file to store the server info state. This is
# used by "pumactl" to query and control the server.
#
# state_path '/u/apps/lolcat/tmp/pids/puma.state'

# Redirect STDOUT and STDERR to files specified. The 3rd parameter
# ("append") specifies whether the output is appended, the default is
# "false".
stdout_redirect '/tmp/isu-rack.log', '/tmp/isu-rack.log', true

threads 6,6
workers 6

bind 'unix:///run/isutrain/puma.sock'

# before_fork do
#   puts "Starting workers..."
# end

# on_worker_boot do
#   puts 'On worker boot...'
# end

# on_worker_shutdown do
#   puts 'On worker shutdown...'
# end

# Code to run in the master right before a worker is started. The worker's
# on_worker_fork do
#   puts 'Before worker fork...'
# end
# after_worker_fork do
#   puts 'After worker fork...'
# end

# Allow workers to reload bundler context when master process is issued
# a USR1 signal. This allows proper reloading of gems while the master
# is preserved across a phased-restart. (incompatible with preload_app)
# (off by default)
# prune_bundler

# Preload the application before starting the workers; this conflicts with
# phased restart feature. (off by default)
preload_app!

tag 'isutrain'

# worker_timeout 60
# worker_boot_timeout 60

activate_control_app 'unix:///run/isutrain/pumactl.sock'

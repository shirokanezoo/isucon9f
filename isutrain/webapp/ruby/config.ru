require 'sinatra'
require 'stackprof'
require 'rack-timeout'
require './app.rb'

use Rack::Timeout, service_timeout: 5
use StackProf::Middleware, enabled: true, raw: true, mode: :cpu, interval: 250, save_every: 5, path: ENV['LOCAL'] ? '/tmp/stackprof/' : '/run/isutrain/stackprof/'

run Isutrain::App

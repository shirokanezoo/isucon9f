#!/bin/bash -x
export PATH=/home/isucon/ruby/bin:$PATH
#export RUBYOPT='--enable=jit --jit-warnings'

if [[ "$#" -lt 1 ]]; then
  exec bundle exec puma -C ./puma.rb
else
  exec "$@"
fi

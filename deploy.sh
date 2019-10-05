#!/bin/bash -ex
selfsum="$(openssl dgst -sha256 "$0")"
#export PATH=/home/isucon/local/ruby/bin:$PATH
#
cd ~/git/
git pull --rebase
if [ "_${selfsum}" != "_$(openssl dgst -sha256 "$0")" ]; then
  exec $0
fi

(
  cd ~/git/isutrain/webapp/ruby
  bundle exec stackprof --d3-flamegraph app.rb /run/isutrain/stackprof/* > ~isucon/public_html/stackprof.html
) || :

sudo cp ~/git/systemd/* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl restart isutrain.service

sudo cp ~/git/nginx.conf /etc/nginx/nginx.conf

sudo nginx -t
sudo nginx -s reload || :

(
  cd ~/git/isutrain/webapp/ruby
  source ~/env.secret.sh
  source ~/git/env.sh
  export RACK_ENV=production
  export NEW_RELIC_LICENSE_KEY
  bundle exec newrelic deployment -r "$(git rev-parse HEAD)"
) || :

sudo bash -c 'cp /var/log/nginx/access.log /var/log/nginx/access.log.$(date +%s) && echo > /var/log/nginx/access.log; echo > /tmp/isu-query.log; echo > /tmp/isu-rack.log; echo > /tmp/isu-params.log; test -d /tmp/stackprof && rm -f /tmp/stackprof/*; echo > /var/lib/mysql/mysql-slow.log; chown isucon:isucon /tmp/isu*.log'

require 'redis'
$stdout.sync = true

@redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost'))
payment_api = ENV['PAYMENT_API'] || 'https://payment041.isucon9.hinatan.net/'
uri = URI.parse("#{payment_api}/payment/_bulk")

loop do
  payment_ids = @redis.multi do |m|
    m.lrange('isutrain:cancel_queue', 0, -1)
    m.del('isutrain:cancel_queue')
  end[0]

  payload = {
    payment_id: payment_ids,
  }.to_json
  puts payload

  req = Net::HTTP::Post.new(uri)
  req.body = payload
  req['Content-Type'] = 'application/json'

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  res = http.start { http.request(req) }

  puts res.body
  res.value

  sleep 1
end

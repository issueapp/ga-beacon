require 'cuba'
require 'logger'
require 'mote'
require 'http'
require 'securerandom'

Log = Logger.new(
  File.exist?('app.log') ? 'app.log' : STDOUT
)

BeaconURL = "http://www.google-analytics.com/collect"
Cid = 'cid'

Cuba.define do
  def log ua, ip, cid, params
    response = HTTP.headers(
      'User-Agent' => ua,
    ).post(BeaconURL, form: params)

    Log.info "GA collector status: #{response.code}, cid: #{cid}, ip: #{ip}, body: #{response.body}"
  end

  def logHit ua, ip, cid, account, page
    payload = {
      v: '1',
      t: 'pageview',
      tid: account,
      cid: cid,
      dp: page,
      uip: ip,
    }
    log(ua, ip, cid, payload)
  end

  def generateUUID
    SecureRandom.uuid
  end

  def get_or_set_cid
    @cid = req.cookies[Cid]

    if @cid.nil? || @cid.empty?
      @cid = generateUUID
      res.set_cookie(Cid, "#{@cid}; path=/")
    end

    @cid
  end

  on ':account/(.+)' do |account, page|
    cid = get_or_set_cid
    logHit(req.user_agent, req.ip, cid, account, page)

    res['Cache-Control'] = 'no-cache'
    res['CID'] = cid
    res.status = 204
  end

  on ':account' do |account|
    vars = {
      account: account,
      referer: req.referer,
    }
    content = IO.read('./page.html')
    template = Mote.parse(content, self, vars.keys)
    res.write template.call(vars)
  end

  on root do
    res.redirect 'https://github.com/issueapp/ga-beacon'
  end
end

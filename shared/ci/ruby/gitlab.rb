##[>] 🤖🤖
require 'net/http'
require 'openssl'
require 'json'
require 'cgi'

module CrossRepo
  # Gitlab is the retrying REST client every cross-repo script reads the API through.
  module Gitlab
    API = 'https://gitlab.com/api/v4'
    TRANSIENT_ERRORS = [Net::OpenTimeout, Net::ReadTimeout, Errno::ETIMEDOUT, Errno::ECONNRESET, Errno::ECONNREFUSED,
                        Errno::EHOSTUNREACH, SocketError, EOFError, OpenSSL::SSL::SSLError, IOError].freeze
    TRANSIENT_STATUSES = %w[429 500 502 503 504].freeze
    RETRY_ATTEMPTS = 5
    RETRY_BASE_PAUSE = 2

    def self.transient_status?(code)
      TRANSIENT_STATUSES.include?(code.to_s)
    end

    # Retries +label+ with exponential backoff over transient errors and statuses.
    def self.with_retry(label, attempts: RETRY_ATTEMPTS, pause: RETRY_BASE_PAUSE, sleeper: method(:sleep))
      (1..attempts).each do |attempt|
        failure = begin
          res = yield
          return res unless res.is_a?(Net::HTTPResponse) && transient_status?(res.code)

          "status #{res.code}"
        rescue *TRANSIENT_ERRORS => e
          "#{e.class}: #{e.message}"
        end
        raise "#{label}: gave up after #{attempts} attempts, last failure: #{failure}" if attempt == attempts

        warn "#{label}: #{failure}, attempt #{attempt}/#{attempts}, retrying"
        sleeper.call(pause * (2**(attempt - 1)))
      end
    end

    def self.get(url, job_token: true)
      req = Net::HTTP::Get.new(URI(url))
      automation = ENV['AUTOMATION_GITLAB_TOKEN'].to_s
      job = ENV['CI_JOB_TOKEN'].to_s
      if !automation.empty?
        req['PRIVATE-TOKEN'] = automation
      elsif job_token && !job.empty?
        req['JOB-TOKEN'] = job
      end
      with_retry("GET #{req.uri.path}") do
        Net::HTTP.start(req.uri.host, req.uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { |http| http.request(req) }
      end
    end

    # Reads one file at +ref+, nil when the project or path does not exist.
    def self.file(project, path, ref: 'main')
      res = get("#{API}/projects/#{CGI.escape(project)}/repository/files/#{CGI.escape(path)}/raw?ref=#{ref}")
      return res.body.force_encoding('UTF-8') if res.is_a?(Net::HTTPSuccess)
      return nil if res.is_a?(Net::HTTPNotFound)

      raise "#{project} #{path}: unexpected status #{res.code} #{res.body}"
    end

    def self.projects(group)
      res = get("#{API}/groups/#{group}/projects?include_subgroups=true&per_page=100", job_token: false)
      raise "group listing failed: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body).map { |p| p['path_with_namespace'].delete_prefix("#{group}/") }
    end
  end
end
##[<] 🤖🤖

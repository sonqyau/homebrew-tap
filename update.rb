#!/usr/bin/env ruby
require "json"
require "net/http"
require "digest"
require "fileutils"
require "set"

module Update
  GITHUB_TOKEN = ENV["GITHUB_TOKEN"]
  API_BASE = "https://api.github.com"
  PARALLEL_LIMIT = 8
  TIMEOUT = 15
  class << self
    def http_client
      @http ||= begin
          http = Net::HTTP.new("api.github.com", 443)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.read_timeout = TIMEOUT
          http.open_timeout = TIMEOUT
          http.keep_alive_timeout = 30
          http.start
          http
        end
    end

    def api_request(path)
      uri = URI("#{API_BASE}#{path}")
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{GITHUB_TOKEN}" if GITHUB_TOKEN
      req["Accept"] = "application/vnd.github+json"
      req["X-GitHub-Api-Version"] = "2022-11-28"
      req["User-Agent"] = "homebrew-tap-updater"
      response = http_client.request(req)
      return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess) && response.body
      nil
    rescue => e
      warn "API Error: #{e.message}"
      nil
    end

    def extract_repo_info(homepage)
      return nil unless homepage&.include?("github.com")
      match = homepage.match(%r{github\.com/([^/]+/[^/]+)})
      match ? match[1] : nil
    end

    def get_release_data(repo_path)
      return nil unless repo_path
      @release_cache ||= {}
      @release_cache[repo_path] ||= api_request("/repos/#{repo_path}/releases/latest")
    end

    def find_asset_digest(release_data, url_pattern, version)
      return nil unless release_data&.dig("assets")
      release_data["assets"].find do |asset|
        next unless asset["name"] && asset["browser_download_url"]
        url_pattern.gsub('#{version}', version).include?(asset["name"]) ||
        url_pattern.gsub('#{version}', version).include?(asset["browser_download_url"])
      end&.dig("digest")&.sub(/^sha256:/, "")
    end

    def calculate_sha256(url)
      return nil unless url
      temp_file = "/tmp/brew-#{Process.pid}-#{Time.now.to_f}"
      begin
        result = system("curl", "-fsSL", "--max-time", "10", "-o", temp_file, url, out: File::NULL, err: File::NULL)
        return nil unless result
        sha256 = Digest::SHA256.file(temp_file).hexdigest
        sha256
      ensure
        File.delete(temp_file) if File.exist?(temp_file)
      end
    rescue => e
      warn "SHA256 calculation failed: #{e.message}"
      nil
    end

    def update_file(file_path, version, sha256)
      content = File.read(file_path)
      updated = content.dup
      updated.gsub!(/version\s+"[^"]+"/, "version \"#{version}\"")
      updated.gsub!(/sha256\s+"[^"]+"/, "sha256 \"#{sha256}\"")
      updated.gsub!(/(url\s+["'][^"']*?)\#{version}([^"']*["'])/, "\\1#{version}\\2")
      updated.gsub!(/(url\s+["'][^"']*v)[\d\.]+([^"']*["'])/, "\\1#{version}\\2")
      return false if updated == content
      File.write(file_path, updated)
      true
    end

    def process_cask(cask_name)
      file_path = "Casks/#{cask_name}.rb"
      return false unless File.exist?(file_path)
      content = File.read(file_path)
      version_match = content.match(/version\s+"([^"]+)"/)
      url_match = content.match(/url\s+"([^"]+)"/)
      homepage_match = content.match(/homepage\s+"([^"]+)"/)
      return false unless version_match && url_match && homepage_match
      current_version = version_match[1]
      url_pattern = url_match[1]
      homepage = homepage_match[1]
      repo_path = extract_repo_info(homepage)
      return false unless repo_path
      release_data = get_release_data(repo_path)
      return false unless release_data
      latest_version = release_data["tag_name"]&.sub(/^v/, "")
      return false unless latest_version && latest_version != current_version
      new_url = url_pattern.gsub('#{version}', latest_version)
      new_sha256 = find_asset_digest(release_data, url_pattern, latest_version) || calculate_sha256(new_url)
      return false unless new_sha256
      return false unless update_file(file_path, latest_version, new_sha256)
      commit_sha = api_request("/repos/#{repo_path}/commits/#{release_data["tag_name"]}")&.dig("sha")&.to_s&.[](0, 7) || "unknown"
      File.write(".update_#{cask_name}", "#{repo_path}|#{commit_sha}|casks|#{cask_name}")
      true
    rescue => e
      warn "Failed to process #{cask_name}: #{e.message}"
      false
    end

    def process_formula(formula_name)
      file_path = "Formula/#{formula_name}.rb"
      return false unless File.exist?(file_path)
      content = File.read(file_path)
      version_match = content.match(/version\s+"([^"]+)"/)
      homepage_match = content.match(/homepage\s+"([^"]+)"/)
      return false unless version_match && homepage_match
      current_version = version_match[1]
      homepage = homepage_match[1]
      repo_path = extract_repo_info(homepage)
      return false unless repo_path
      release_data = get_release_data(repo_path)
      return false unless release_data
      latest_version = release_data["tag_name"]&.sub(/^v/, "")
      return false unless latest_version && latest_version != current_version
      new_sha256 = nil
      release_data["assets"]&.each do |asset|
        next unless asset["name"] && asset["digest"]
        new_sha256 = asset["digest"].sub(/^sha256:/, "")
        break
      end
      return false unless new_sha256
      return false unless update_file(file_path, latest_version, new_sha256)
      commit_sha = api_request("/repos/#{repo_path}/commits/#{release_data["tag_name"]}")&.dig("sha")&.to_s&.[](0, 7) || "unknown"
      File.write(".update_#{formula_name}", "#{repo_path}|#{commit_sha}|formula|#{formula_name}")
      true
    rescue => e
      warn "Failed to process #{formula_name}: #{e.message}"
      false
    end

    def run_updates
      target = ENV["TARGET"] || ""
      updated_files = []
      if target.empty?
        casks = Dir.glob("Casks/*.rb").map { |f| File.basename(f, ".rb") }
        formulas = Dir.glob("Formula/*.rb").map { |f| File.basename(f, ".rb") }
        threads = []
        [casks, formulas].flatten.each_slice(PARALLEL_LIMIT) do |batch|
          batch.each do |name|
            threads << Thread.new do
              if casks.include?(name)
                updated_files << name if process_cask(name)
              else
                updated_files << name if process_formula(name)
              end
            end
          end
          threads.each(&:join)
          threads.clear
        end
      else
        if File.exist?("Casks/#{target}.rb")
          updated_files << target if process_cask(target)
        elsif File.exist?("Formula/#{target}.rb")
          updated_files << target if process_formula(target)
        end
      end
      updated_files
    ensure
      @http_client&.finish rescue nil
    end
  end
end

updated_files = Update.run_updates

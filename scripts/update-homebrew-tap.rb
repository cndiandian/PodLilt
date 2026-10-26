#!/usr/bin/env ruby
# Publish the exact DMG checksum to the dedicated Homebrew tap.
require "base64"
require "digest"
require "json"
require "open3"

version, dmg_path = ARGV
abort "Usage: ruby scripts/update-homebrew-tap.rb VERSION DMG_PATH" unless
  version && version.match?(/\A\d+\.\d+\.\d+\z/) && dmg_path && File.file?(dmg_path)

checksum = Digest::SHA256.file(dmg_path).hexdigest
cask = <<~CASK
  cask "podlilt" do
    version "#{version}"
    sha256 "#{checksum}"

    url "https://github.com/cndiandian/PodLilt/releases/download/v\#{version}/PodLilt-v\#{version}.dmg"
    name "PodLilt"
    desc "Lightweight floating player for Apple Podcasts"
    homepage "https://github.com/cndiandian/PodLilt"

    depends_on macos: :sonoma

    app "PodLilt.app"
  end
CASK

if ENV["TAP_DRY_RUN"] == "1"
  puts cask
  exit
end

abort "GH_TOKEN is required" if ENV.fetch("GH_TOKEN", "").empty?
endpoint = "repos/cndiandian/homebrew-tap/contents/Casks/podlilt.rb"
output, error, result = Open3.capture3("gh", "api", endpoint)
existing = nil
if result.success?
  existing = JSON.parse(output)
elsif !error.include?("HTTP 404")
  abort "Unable to read tap: #{error}"
end

if existing && Base64.decode64(existing.fetch("content")) == cask
  puts "Homebrew cask is already up to date."
  exit
end

# Do not let an older release overwrite a newer cask.
if existing
  previous = Base64.decode64(existing.fetch("content"))[/version "(\d+\.\d+\.\d+)"/, 1]
  if previous && (previous.split(".").map(&:to_i) <=> version.split(".").map(&:to_i)) == 1
    abort "Refusing to downgrade Homebrew cask from #{previous} to #{version}."
  end
end

payload = {
  message: "chore(cask): 更新 PodLilt 至 #{version} / Update PodLilt to #{version}",
  content: Base64.strict_encode64(cask)
}
payload[:sha] = existing.fetch("sha") if existing
output, error, result = Open3.capture3(
  "gh", "api", "--method", "PUT", endpoint, "--input", "-",
  stdin_data: JSON.generate(payload)
)
abort "Unable to update tap: #{error}" unless result.success?
puts "Published PodLilt #{version} to cndiandian/homebrew-tap."

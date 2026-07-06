#!/usr/bin/env ruby
# frozen_string_literal: true

MARKER = "REPLACE_BEFORE_RELEASE"
SOURCE_FILES = %w[
  COPYRIGHT
  LICENSE
  SECURITY.md
].freeze
DEPLOYMENT_FILES = %w[
  PRIVACY.md
  web/legal.html
].freeze

mode = ARGV.first || "--source"
unless %w[--source --deployment].include?(mode)
  warn "Usage: ruby scripts/check_release_metadata.rb [--source|--deployment]"
  exit 2
end

files = SOURCE_FILES + (mode == "--deployment" ? DEPLOYMENT_FILES : [])
incomplete = files.select do |path|
  !File.file?(path) || File.read(path, encoding: "UTF-8").include?(MARKER)
end

unless incomplete.empty?
  warn "#{mode.delete_prefix('--').capitalize} publication metadata is incomplete:"
  incomplete.each { |path| warn "- #{path}" }
  warn "Replace every #{MARKER} marker required for this publication mode."
  exit 1
end

puts "#{mode.delete_prefix('--').capitalize} publication metadata is complete."

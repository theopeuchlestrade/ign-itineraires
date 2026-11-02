#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "digest"

root = ARGV.first || "build/web"
base_href = ARGV[1] || "/"
index_path = File.join(root, "index.html")
bootstrap_path = File.join(root, "flutter_bootstrap.js")
legal_path = File.join(root, "legal.html")

abort "Missing web release files" unless [index_path, bootstrap_path, legal_path].all? { |path| File.file?(path) }

index = File.read(index_path, encoding: "UTF-8")
bootstrap = File.read(bootstrap_path, encoding: "UTF-8")
legal = File.read(legal_path, encoding: "UTF-8")

abort "Unexpected base href" unless index.include?(%(<base href="#{base_href}">))
abort "Release loader missing" unless index.include?('src="app_loader.js"')
release = JSON.parse(File.read(File.join(root, "release.json")))
bootstrap_name = release.fetch("bootstrap")
abort "Invalid versioned bootstrap name" unless bootstrap_name.match?(/\Aflutter_bootstrap\.[0-9a-f]{64}\.js\z/)
abort "Bootstrap fingerprint mismatch" unless bootstrap_name == "flutter_bootstrap.#{Digest::SHA256.hexdigest(bootstrap)}.js"
abort "Versioned bootstrap differs" unless File.read(File.join(root, bootstrap_name)) == bootstrap
main_name = bootstrap[/"mainJsPath":"(main\.[0-9a-f]{64}\.dart\.js)"/, 1]
abort "Versioned entrypoint missing" unless main_name
abort "Entrypoint fingerprint mismatch" unless main_name == "main.#{Digest::SHA256.file(File.join(root, main_name)).hexdigest}.dart.js"
loader_settings = bootstrap[/_flutter\.loader\.load\(\{.*\z/m] || ""
abort "Legacy caching worker is still enabled" if loader_settings.include?("serviceWorkerSettings:")
worker = File.read(File.join(root, "flutter_service_worker.js"))
abort "Worker retirement missing" unless worker.include?("self.registration.unregister()") && worker.include?("self.skipWaiting()")
abort "CanvasKit is not configured locally" unless bootstrap.include?(%("useLocalCanvasKit":true))
abort "Local CanvasKit asset missing" unless File.file?(File.join(root, "canvaskit", "canvaskit.wasm"))
abort "Google Fonts reference found" if bootstrap.include?("fonts.gstatic.com")
abort "Local font fallback missing" unless bootstrap.include?("fontFallbackBaseUrl: 'font-fallback/'")
abort "Legal return link must be relative" unless legal.include?(%(<a href="./">Retour))
abort "French document language missing" unless index.include?(%(<html lang="fr">))
abort "Viewport metadata missing" unless index.include?(%(name="viewport"))
expected_network_boundary = "connect-src 'self' https://data.geopf.fr"
abort "Unexpected web network boundary" unless index.include?(expected_network_boundary)

puts "Web release is self-contained for #{base_href}."

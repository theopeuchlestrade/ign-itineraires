#!/usr/bin/env ruby
# frozen_string_literal: true

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

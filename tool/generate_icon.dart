/// Script to generate app icons with DSFR colors
/// Run with: dart run tool/generate_icon.dart

import 'dart:io';
import 'dart:math';
import 'package:image/image.dart';

void main() {
  // Create a 1024x1024 image
  final image = Image(width: 1024, height: 1024);
  
  // Bleu Marianne (#000091) - RGB: 0, 0, 145
  final bleuMarianne = ColorRgb8(0, 0, 145);
  final blanc = ColorRgb8(255, 255, 255);
  final rougeMarianne = ColorRgb8(225, 0, 15);
  
  // Fill with Bleu Marianne
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixel(x, y, bleuMarianne);
    }
  }
  
  // Draw a cross (route symbol) in white
  _drawThickLine(image, 300, 300, 724, 724, blanc, 120);
  _drawThickLine(image, 724, 300, 300, 724, blanc, 120);
  
  // Draw center circle in white (radius 180)
  _drawFilledCircle(image, 512, 512, 180, blanc);
  
  // Draw inner circle in Rouge Marianne (radius 120)
  _drawFilledCircle(image, 512, 512, 120, rougeMarianne);
  
  // Save as PNG
  final pngBytes = encodePng(image);
  File('assets/branding/map_icon.png').writeAsBytesSync(pngBytes);
  
  // Web icons
  final icon192 = copyResize(image, width: 192, height: 192);
  File('web/icons/Icon-192.png').writeAsBytesSync(encodePng(icon192));
  File('web/icons/Icon-maskable-192.png').writeAsBytesSync(encodePng(icon192));
  
  final icon512 = copyResize(image, width: 512, height: 512);
  File('web/icons/Icon-512.png').writeAsBytesSync(encodePng(icon512));
  File('web/icons/Icon-maskable-512.png').writeAsBytesSync(encodePng(icon512));
  
  // Favicon (32x32)
  final favicon32 = copyResize(image, width: 32, height: 32);
  File('web/favicon.png').writeAsBytesSync(encodePng(favicon32));
  
  // Android launcher icons
  _generateAndroidIcons(image);
  
  // iOS app icons
  _generateIOSIcons(image);
  
  print('✅ All icons generated successfully with DSFR colors!');
  print('   - App icon: assets/branding/map_icon.png (1024x1024)');
  print('   - Web icons: Icon-192, Icon-512, Icon-maskable-*');
  print('   - Favicon: web/favicon.png');
  print('   - Android: ic_launcher.png for all densities');
  print('   - iOS: All AppIcon sizes');
}

void _drawThickLine(Image image, int x1, int y1, int x2, int y2, Color color, int thickness) {
  final distance = sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)).toDouble();
  final steps = (distance / 2).ceil();
  
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    final x = (x1 + (x2 - x1) * t).round();
    final y = (y1 + (y2 - y1) * t).round();
    _drawFilledCircle(image, x, y, (thickness / 2).round(), color);
  }
}

void _drawFilledCircle(Image image, int cx, int cy, int radius, Color color) {
  final radiusSquared = radius * radius;
  for (var y = cy - radius; y <= cy + radius; y++) {
    for (var x = cx - radius; x <= cx + radius; x++) {
      if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy <= radiusSquared) {
          image.setPixel(x, y, color);
        }
      }
    }
  }
}

void _generateAndroidIcons(Image source) {
  final androidIcons = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  
  for (final entry in androidIcons.entries) {
    final size = entry.value;
    final resized = copyResize(source, width: size, height: size);
    final dirPath = 'android/app/src/main/res/${entry.key}';
    final filePath = '$dirPath/ic_launcher.png';
    
    // Create directory if it doesn't exist
    Directory(dirPath).createSync(recursive: true);
    File(filePath).writeAsBytesSync(encodePng(resized));
  }
}

void _generateIOSIcons(Image source) {
  final iosIcons = {
    // 1x scale
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-83.5x83.5@2x.png': 83,  // Will be scaled to 167x167@2x
    // 2x scale
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-60x60@2x.png': 60,
    'Icon-App-76x76@2x.png': 152,
    // 3x scale
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@3x.png': 228,
    // Large icons
    'Icon-App-512x512@2x.png': 1024,
    'Icon-App-1024x1024@1x.png': 1024,
  };
  
  final basePath = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  Directory(basePath).createSync(recursive: true);
  
  for (final entry in iosIcons.entries) {
    final size = entry.value;
    final resized = copyResize(source, width: size, height: size);
    final filePath = '$basePath/${entry.key}';
    File(filePath).writeAsBytesSync(encodePng(resized));
  }
}



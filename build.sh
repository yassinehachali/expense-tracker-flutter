#!/bin/bash

# Exit on error
set -e

echo "Installing Flutter..."

# Clone Flutter if it doesn't exist
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable
else
  # Optional: update flutter if you want to ensure latest stable
  # cd flutter && git pull && cd ..
  echo "Flutter directory already exists"
fi

# Add flutter to PATH temporarily for this script
export PATH="$PATH:`pwd`/flutter/bin"

echo "Flutter version:"
flutter --version

echo "Enabling web..."
flutter config --enable-web

echo "Building for web..."
flutter build web --release --no-tree-shake-icons

echo "Build complete."

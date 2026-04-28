#!/bin/bash
# Run this ONCE in a Terminal on your Mac to allow SSH builds to sign code
# It grants codesign access to your login keychain without GUI prompts
echo "Enter your macOS login password:"
read -rs PASS
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s -k "$PASS" \
  ~/Library/Keychains/login.keychain-db \
  && echo "Done — SSH builds can now sign code."

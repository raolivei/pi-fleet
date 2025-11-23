#!/bin/bash
# Toggle showing hidden files in Finder

if [ "$1" = "on" ] || [ "$1" = "true" ] || [ "$1" = "1" ]; then
    defaults write com.apple.finder AppleShowAllFiles -bool true
    killall Finder
    echo "✅ Hidden files are now visible in Finder"
elif [ "$1" = "off" ] || [ "$1" = "false" ] || [ "$1" = "0" ]; then
    defaults write com.apple.finder AppleShowAllFiles -bool false
    killall Finder
    echo "✅ Hidden files are now hidden in Finder"
else
    CURRENT=$(defaults read com.apple.finder AppleShowAllFiles 2>/dev/null || echo "false")
    if [ "$CURRENT" = "1" ] || [ "$CURRENT" = "true" ]; then
        echo "Hidden files are currently: ON"
        echo "To turn off: $0 off"
    else
        echo "Hidden files are currently: OFF"
        echo "To turn on: $0 on"
    fi
fi


appname=$(find /Applications -maxdepth 2 -type d -name "*.app" -printf '%f\n' | sed -e 's/\.app$//' | /Applications/kies.app/Contents/MacOS/kies -p "run:")
if [ -n "$appname" ]; then
  open -a "$appname"
fi

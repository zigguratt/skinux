#!/bin/sh
#
# ~/.xinitrc
#
# Executed by startx (run your window manager from here)

if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

# Set up cursor and xterm theme
xrdb -merge ~/.Xresources

# Make QT look like GTK
export QT_QPA_PLATFORMTHEME=gtk2

# Start our window manager
exec openbox-session

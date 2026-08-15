#!/usr/bin/env bash
# Attach if a session exists, else create a new named one
if tmux has-session 2>/dev/null; then
	exec tmux attach
else 
	exec tmux new -s main
fi

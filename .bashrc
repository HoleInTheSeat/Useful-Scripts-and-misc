# When logging in via SSH, check for tmux sessions. If there are none, create one. If there is only 1, attach to it. If there are multiple, let the user select the desired session.
if [ -z "$TMUX" ] && [ -n "$SSH_CONNECTION" ]; then
    session_count=$(tmux list-sessions 2>/dev/null | wc -l)

    if [ "$session_count" -eq 0 ]; then
        tmux new -s main
    elif [ "$session_count" -eq 1 ]; then
        tmux attach
    else
        echo "Multiple tmux sessions found:"
        tmux list-sessions
        echo
        read -rp "Enter session name to attach: " session_name
        tmux attach -t "$session_name"
    fi
fi

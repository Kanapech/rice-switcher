#!/usr/bin/env fish
function rice-cycle
    set -l CONFIG_DIR ~/.config/rice-switcher
    set -l STATE_FILE $CONFIG_DIR/active

    source $CONFIG_DIR/config.fish

    set -l current (test -f $STATE_FILE && cat $STATE_FILE || echo "none")

    # Get all rice names (sorted for consistent cycling order)
    set -l rices
    for dir in $RICE_BASE/*/
        set -a rices (basename $dir)
    end

    # Find current index
    set -l idx 1
    for i in (seq (count $rices))
        if test "$rices[$i]" = "$current"
            set idx $i
            break
        end
    end

    # Cycle to next (wrap around)
    set -l next_idx (math "($idx % "(count $rices)") + 1")
    set -l next_rice $rices[$next_idx]

    # Switch — non-blocking, notify after switch completes
    nohup fish -c "
        source ~/.config/fish/functions/rice_switcher/rice.fish
        rice switch $next_rice
        notify-send '🍚 Rice' 'Switched to: $next_rice' 2>/dev/null || true
    " > /dev/null 2>&1 &
end

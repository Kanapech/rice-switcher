#!/usr/bin/env fish

function rice-menu
    set -l CONFIG_DIR ~/.config/rice-switcher
    set -l STATE_FILE $CONFIG_DIR/active

    if test -f $CONFIG_DIR/config.fish
        source $CONFIG_DIR/config.fish
    else
        notify-send "rice-menu" "Run 'rice list' first"
        return 1
    end

    if test -z "$RICE_BASE"
        notify-send "rice-menu" "RICE_BASE not set"
        return 1
    end

    set -l current (test -f $STATE_FILE && cat $STATE_FILE || echo "none")

    # Build menu
    set -l menu_items
    for dir in $RICE_BASE/*/
        test -d $dir; or continue
        set -l name (basename $dir)
        set -l mf "$dir/manifest.toml"
        set -l desc "—"
        
        if test -f $mf
            set desc (dasel query -i toml -o json 'metadata.description' < $mf 2>/dev/null | string trim -c '"' || echo "—")
        end

        set -l marker " "
        test "$name" = "$current"; and set marker "●"
        set -a menu_items "$marker $name    $desc"
    end

    # Fuzzel
    set -l selection (printf '%s\n' $menu_items | fuzzel --dmenu --prompt "🍚 Switch Rice: " --width 50 --lines 10 2>/dev/null)
    test -z "$selection"; and return 0

    # Extract rice name
    set -l words (string match -ar '\S+' $selection)
    
    set -l chosen
    if test "$words[1]" = "●"
        set chosen $words[2]
    else
        set chosen $words[1]
    end

    # Switch (non-blocking)
    if test -n "$chosen"
        nohup fish -c "
            source ~/.config/fish/functions/rice.fish
            rice switch $chosen
            notify-send '🍚 Rice' 'Switched to: $chosen' 2>/dev/null || true
        " > /dev/null 2>&1 &
    end
end

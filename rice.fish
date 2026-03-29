#!/usr/bin/env fish
# ╔══════════════════════════════════════════════════════╗
# ║  rice — Fish rice manager                           ║
# ║  deps: dasel, chezmoi                               ║
# ╚══════════════════════════════════════════════════════╝

set -g CONFIG_DIR  ~/.config/rice-switcher
set -g CONFIG_FILE $CONFIG_DIR/config.fish
set -g STATE_FILE  $CONFIG_DIR/active

function rice
    # ── Bootstrap ─────────────────────────────────────────────────────────
    if not test -f $CONFIG_FILE
        echo "First run — where should the rice library live?"
        echo "  1) ~/.local/share/rices  (XDG standard)"
        echo "  2) ~/dotfiles/rices      (in-repo)"
        echo "  3) Custom path"
        read -P "Choice [1/2/3]: " _choice

        switch $_choice
            case 1; set rice_base ~/.local/share/rices
            case 2; set rice_base ~/dotfiles/rices
            case 3
                read -P "Enter path: " rice_base
                set rice_base (eval echo $rice_base)
            case '*'
                echo "Invalid choice"; return 1
        end

        mkdir -p $CONFIG_DIR
        echo "set -gx RICE_BASE $rice_base" > $CONFIG_FILE
        echo "Saved to $CONFIG_FILE"
    end

    source $CONFIG_FILE

    # ── Dispatch ───────────────────────────────────────────────────────────
    switch $argv[1]
        case switch;      cmd_switch  $argv[2]
        case list ls;     cmd_list
        case status;      cmd_status
        case doctor;      cmd_doctor  $argv[2..]
        case ''
            echo "Usage: rice [switch <name> | list | status | doctor [name...]]"
        case '*'
            echo "Unknown command: $argv[1]"; return 1
    end
end

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Internal helpers
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function _manifest
    echo "$RICE_BASE/$argv[1]/manifest.toml"
end

function _rice_exists
    test -d "$RICE_BASE/$argv[1]"
end

function _active_rice
    test -f $STATE_FILE && cat $STATE_FILE || echo "none"
end

function _expand
    echo $argv[1] | string replace -r '^~' $HOME
end

function _dasel
    dasel query -i toml -o json $argv[2] < $argv[1] 2>/dev/null \
        | string trim -c '"'
end

function _get_symlinks
    set -l manifest (_manifest $argv[1])
    test -f $manifest || return
    dasel query -i toml -o json 'symlinks' < $manifest \
        | jq -r 'to_entries[] | "\(.key)\t\(.value)"'
end

function _get_inherit
    _dasel (_manifest $argv[1]) 'inherit.base'
end

# Paths in old manifest absent from new manifest (and its base) → ghost paths
function _symlink_diff
    set -l old_rice $argv[1]
    set -l new_rice $argv[2]

    set -l new_dsts
    for line in (_get_symlinks $new_rice)
        set -a new_dsts (_expand (echo $line | cut -f2))
    end

    set -l new_inherit (_get_inherit $new_rice)
    if test -n "$new_inherit"
        for line in (_get_symlinks $new_inherit)
            set -a new_dsts (_expand (echo $line | cut -f2))
        end
    end

    for line in (_get_symlinks $old_rice)
        set -l dst (_expand (echo $line | cut -f2))
        if not contains $dst $new_dsts
            echo $dst
        end
    end
end

function _link
    set -l src $argv[1]
    set -l dst $argv[2]

    if not test -e $src
        echo "  [warn] source missing: $src"
        return 1
    end
    if test -e $dst && not test -L $dst
        echo "  [warn] $dst exists and is not a symlink — skipping (backup manually)"
        return 1
    end

    mkdir -p (dirname $dst)
    ln -sf $src $dst
    echo "  [link] "(basename $src)" → $dst"
end

function _unlink
    set -l dst $argv[1]
    if test -L $dst
        rm $dst
        echo "  [unlink] $dst"
    else if test -d $dst
        rm -rf $dst
        echo "  [rm -rf] $dst"
    end
end

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Validation
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function _validate_rice
    set -l name $argv[1]
    set -l base "$RICE_BASE/$name"
    set -l errors 0

    # Manifest
    if not test -f "$base/manifest.toml"
        echo "  [error] manifest.toml missing"
        set errors (math $errors + 1)
    end

    # Scripts
    for script in start.sh stop.sh
        if not test -f "$base/scripts/$script"
            echo "  [error] scripts/$script missing"
            set errors (math $errors + 1)
        else if not test -x "$base/scripts/$script"
            echo "  [error] scripts/$script not executable  (fix: chmod +x)"
            set errors (math $errors + 1)
        end
    end

    # Symlink sources exist
    for line in (_get_symlinks $name)
        set -l src (echo $line | cut -f1)
        if not test -e "$base/$src"
            echo "  [error] manifest declares '$src' but path does not exist"
            set errors (math $errors + 1)
        end
    end

    # Inherit target exists
    set -l inherit (_get_inherit $name)
    if test -n "$inherit" && not _rice_exists $inherit
        echo "  [error] inherit.base = '$inherit' but that rice does not exist"
        set errors (math $errors + 1)
    end

    # Metadata (warn only — non-blocking)
    if test -f "$base/manifest.toml"
        for field in author description version
            if test -z (_dasel "$base/manifest.toml" "metadata.$field")
                echo "  [warn] metadata.$field is not set"
            end
        end
    end

    return $errors
end

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Commands
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

function cmd_switch
    set -l target $argv[1]

    if not _rice_exists $target
        echo "Rice '$target' not found in $RICE_BASE"; return 1
    end

    set -l current (_active_rice)
    set -l inherit  (_get_inherit $target)

    # ── Gate: validate before touching anything ───────────────────────────────
    echo "--> Validating: $target"
    _validate_rice $target
    if test $status -gt 0
        echo "  [abort] fix the errors above before switching"
        return 1
    end
    echo "  [ok]"

    echo "==> Switching: $current → $target"

    # ── Step 1: chezmoi apply — files must exist on disk before symlinking ────
    echo "--> chezmoi apply"
    set -l chezmoi_data (chezmoi source-path)/.chezmoidata.toml
    if test -f $chezmoi_data
        sed -i "s/^active = .*/active = \"$target\"/" $chezmoi_data
    end
    chezmoi apply --no-tty
    echo "  [ok]"

    # ── Step 2: Teardown current rice ─────────────────────────────────────────
    if test "$current" != none && _rice_exists $current && test "$current" != $target
        echo "--> Teardown: $current"

        set -l stop_sh "$RICE_BASE/$current/scripts/stop.sh"
        test -x $stop_sh && bash $stop_sh
        # Nuke ghost paths (in old manifest, absent from new)
        for dst in (_symlink_diff $current $target)
            _unlink $dst
        end
        
        # Remove shared links
        for line in (_get_symlinks $current)
            set -l dst (_expand (echo $line | cut -f2))
            test -L $dst && rm $dst
        end
    end

    set -l stop_sh "$RICE_BASE/$target/scripts/stop.sh"
    if test -x $stop_sh
        bash $stop_sh
    end

    # ── Step 3: Setup new rice ────────────────────────────────────────────────
    echo "--> Setup: $target"

    # Inherit links first
    if test -n "$inherit" && _rice_exists $inherit
        echo "  [inherit] $inherit"
        for line in (_get_symlinks $inherit)
            set -l src (echo $line | cut -f1)
            set -l dst (_expand (echo $line | cut -f2))
            _link "$RICE_BASE/$inherit/$src" $dst
        end
    end
    
    # Target links second
    for line in (_get_symlinks $target)
        set -l src (echo $line | cut -f1)
        set -l dst (_expand (echo $line | cut -f2))
        _link "$RICE_BASE/$target/$src" $dst
    end

    # Start the new rice
    set -l start_sh "$RICE_BASE/$target/scripts/start.sh"
    if test -x $start_sh
        setsid bash $start_sh > /dev/null 2>&1
    end

    # ── Step 4: Persist active state ──────────────────────────────────────────
    echo $target > $STATE_FILE
    echo "==> Active rice: $target ✓"
end

# ─────────────────────────────────────────────────────────────────────────────

function cmd_list
    set -l current (_active_rice)
    echo "Available rices in $RICE_BASE:"
    echo ""
    for dir in $RICE_BASE/*/
        set -l name    (basename $dir)
        set -l mf      "$dir/manifest.toml"
        set -l desc    (_dasel $mf 'metadata.description' || echo "—")
        set -l version (_dasel $mf 'metadata.version'     || echo "?")
        set -l marker  "  "
        test "$name" = "$current" && set marker "* "
        printf "%s%-16s v%-8s %s\n" $marker $name $version $desc
    end
end

# ─────────────────────────────────────────────────────────────────────────────

function cmd_status
    set -l current (_active_rice)
    set -l mf      (_manifest $current)

    echo "Active rice : $current"
    echo "Rice base   : $RICE_BASE"

    if test -f $mf
        echo "Author      : "(_dasel $mf 'metadata.author'      || echo "unknown")
        echo "Version     : "(_dasel $mf 'metadata.version'     || echo "?")
        echo "Description : "(_dasel $mf 'metadata.description' || echo "—")
        set -l inherit (_get_inherit $current)
        test -n "$inherit" && echo "Inherits    : $inherit"
    end

    echo ""
    echo "Symlinks:"
    if test "$current" != none
        for line in (_get_symlinks $current)
            set -l dst (_expand (echo $line | cut -f2))
            test -L $dst \
                && echo "  ✓ $dst" \
                || echo "  ✗ $dst  (broken or missing)"
        end
    end
end

# ─────────────────────────────────────────────────────────────────────────────

function cmd_doctor
    set -l targets $argv

    if test (count $targets) -eq 0
        for dir in $RICE_BASE/*/
            set -a targets (basename $dir)
        end
    end

    set -l total_errors 0

    for name in $targets
        echo "--> Validating: $name"
        if not _rice_exists $name
            echo "  [error] rice '$name' not found in $RICE_BASE"
            set total_errors (math $total_errors + 1)
            continue
        end

        set -l errs 0
        _validate_rice $name
        if test $status -gt 0
            set errs 1
        end
        if test $errs -eq 0
            echo "  [ok]"
        else
            set total_errors (math $total_errors + 1)
        end
    end

    if test $total_errors -eq 0
        echo "All rices valid."
    else
        echo "$total_errors error(s) found."
        return 1
    end
end

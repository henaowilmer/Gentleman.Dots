function gentleman-theme-init --description "Apply the persisted Gentleman Fish and Starship theme at shell startup"
    set -l config_home "$HOME/.config"
    set -l active_theme gentleman-blue
    set -l theme_marker "$config_home/fish/gentleman-theme"

    if test -r "$theme_marker"
        set -l marker_theme (string trim -- (cat "$theme_marker"))
        if test -n "$marker_theme"
            switch $marker_theme
                case gentleman gentleman-cute gentleman-blue
                    set active_theme $marker_theme
            end
        end
    end

    # Keep the resolved name available to startup integrations such as Atuin.
    set -g gentleman_active_theme $active_theme

    set -l fish_profile "$config_home/fish/themes/$active_theme.fish"
    if test -r "$fish_profile"
        source "$fish_profile"
    else
        echo "⚠️  Fish theme profile is unavailable: $fish_profile"
    end

    set -gx STARSHIP_CONFIG "$config_home/starship/$active_theme.toml"
end

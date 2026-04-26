{ lib, pkgs, ... }:
{
  # SketchyBar is installed via home.packages in flake.nix
  # This module only handles configuration files
  
  home.activation.copySketchybar = lib.hm.dag.entryAfter ["writeBoundary"] ''
    echo "Copying SketchyBar configuration..."
    
    # Create config directory
    SKETCHYBAR_DIR="$HOME/.config/sketchybar"
    mkdir -p "$SKETCHYBAR_DIR/plugins"
    
    # Copy main config (ensure re-runs can overwrite existing files)
    chmod u+w "$SKETCHYBAR_DIR/sketchybarrc" 2>/dev/null || true
    cp -f "${toString ./sketchybar}/sketchybarrc" "$SKETCHYBAR_DIR/sketchybarrc"
    chmod 755 "$SKETCHYBAR_DIR/sketchybarrc"
    
    # Copy plugins
    chmod u+w "$SKETCHYBAR_DIR/plugins/"*.sh 2>/dev/null || true
    cp -f "${toString ./sketchybar}/plugins/"*.sh "$SKETCHYBAR_DIR/plugins/"
    chmod 755 "$SKETCHYBAR_DIR/plugins/"*.sh
    
    echo "SketchyBar configuration copied to $SKETCHYBAR_DIR"
  '';
}

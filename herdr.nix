{ lib, ... }:

{
  # Herdr — agent multiplexer that lives in your terminal (https://herdr.dev)
  # Profile sources are immutable Home Manager files. The active config stays a
  # regular writable file because it is selected at runtime.
  #
  # There is no config validation gate: herdr 0.7.3 exposes no CLI subcommand
  # that parses config.toml, so a candidate can only be assembled and written
  # atomically. Bad edits surface in the repo sources, and `server reload-config`
  # reports anything the running server rejects.
  home.file = {
    ".config/herdr/config-base.toml".source = ./herdr/config-base.toml;
    ".config/herdr/profiles/gentleman.toml".source = ./herdr/profiles/gentleman.toml;
    ".config/herdr/profiles/gentleman-cute.toml".source = ./herdr/profiles/gentleman-cute.toml;
    ".config/herdr/profiles/gentleman-blue.toml".source = ./herdr/profiles/gentleman-blue.toml;

    ".local/bin/herdr-theme" = {
      executable = true;
      source = ./herdr/herdr-theme;
    };
  };

  # Auto-install Herdr on Home Manager activation if it is missing.
  # Guarded so a missing/failed brew never breaks the activation (same approach as engram.nix).
  home.activation.installHerdr = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    echo "🔧 Setting up Herdr..."

    if command -v herdr >/dev/null 2>&1; then
      echo "✅ Herdr already installed"
    elif command -v brew >/dev/null 2>&1; then
      echo "🚀 Installing Herdr via Homebrew..."
      brew install herdr || echo "❌ Herdr installation failed (run 'brew install herdr' manually)"
    else
      echo "⚠️  Homebrew not found — install Herdr manually: brew install herdr"
    fi

    # Never reset a runtime selection. The first successful installation uses
    # Gentleman Blue only when no active config exists yet. Run the same selector
    # implementation installed above so activation and manual selection cannot drift.
    if ! bash "${./herdr/herdr-theme}" --install-default; then
      echo "⚠️  Unable to write the initial Herdr config"
    fi
  '';
}

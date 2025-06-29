{
  description = "LabWC theme changer (Flutter)";

  inputs = {
    nixpkgs     .url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils .url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib  = pkgs.lib;

        # ── 1. download + scrub the upstream binary ──────────────────────────────
        binary = (pkgs.fetchurl {
          url    = "https://github.com/jaycee1285/labwcchanger/releases/download/relase/labwcchanger";
          sha256 = "sha256-VoYIgTq+wYBFx73mFSF9x9R24K0uYbcWgcP+VfGgWPw=";

          # runs *before* the hash is computed
          postFetch = ''
            # strip RPATHs that point into some other /nix/store
            patchelf --remove-rpath $out
          '';
        }).overrideAttrs (_: {
          # upstream build still contains a store-path interpreter;
          # we’ll patch it later, so waive the fixed-output check now
          unsafeDiscardReferences = true;
        });

        # ── 2. wrap it in a normal derivation so autoPatchelfHook can fix it ──
        app = pkgs.stdenv.mkDerivation {
          pname   = "labwcchanger";
          version = "0.1";

          src = binary;

          dontUnpack = true;
          phases     = [ "installPhase" ];

          nativeBuildInputs = [ pkgs.autoPatchelfHook ];

          buildInputs = with pkgs; [
            gtk3 libxkbcommon
            xorg.libX11 xorg.libXext xorg.libXi xorg.libXrender xorg.libXtst
            libGL             # OpenGL
            glib pango cairo gdk-pixbuf atk
            wayland libepoxy
          ];

          installPhase = ''
            install -Dm755 $src $out/bin/labwcchanger
          '';
        };
      in
      {
        packages.default = app;

        # optional shell for hacking on Flutter sources
        devShell = pkgs.mkShell {
          buildInputs = [ pkgs.flutter pkgs.dart ];
        };
      });
}

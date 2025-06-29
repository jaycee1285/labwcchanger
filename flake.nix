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

        # ── 1. Download *at evaluation time* (no sandbox, no FOD) ────────────
        upstream = builtins.fetchurl {
          url    = "https://github.com/jaycee1285/labwcchanger/releases/download/relase/labwcchanger";
          sha256 = "13q539gyagqwd1qip1ifmph7dm67glhibrmxqx2q1hdy7a0hi1jn"; # use lib.fakeSha256 first time
        };

        # ── 2. Patch interpreter/RPATH inside a normal derivation ───────────
        cleaned = pkgs.runCommand "labwcchanger-clean" {
          nativeBuildInputs = [ pkgs.patchelf ];
        } ''
          cp ${upstream} $out
          chmod +w $out
          patchelf --remove-rpath      $out || true
          patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 $out
          chmod +x $out
        '';

        # ── 3. Final package with proper Nix-store RPATHs ────────────────────
        labwcchanger = pkgs.stdenv.mkDerivation {
          pname   = "labwcchanger";
          version = "0.1";

          src = cleaned;

          dontUnpack = true;
          phases     = [ "installPhase" ];

          nativeBuildInputs = [ pkgs.autoPatchelfHook ];

          buildInputs = with pkgs; [
            gtk3 libxkbcommon
            xorg.libX11 xorg.libXext xorg.libXi xorg.libXrender xorg.libXtst
            libGL glib pango cairo gdk-pixbuf atk wayland libepoxy
          ];

          installPhase = ''
            install -Dm755 $src $out/bin/labwcchanger
          '';
        };
      in {
        packages.default = labwcchanger;

        devShell = pkgs.mkShell {
          buildInputs = [ pkgs.flutter pkgs.dart ];
        };
      });
}

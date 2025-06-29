{
  description = "LabWC theme changer (Flutter)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        
        app = pkgs.stdenv.mkDerivation rec {
          pname = "labwcchanger";
          version = "0.1";
          
          src = pkgs.fetchurl {
            url = "https://github.com/jaycee1285/labwcchanger/releases/download/${version}/labwcchanger";
            sha256 = "sha256-VoYIgTq+wYBFx73mFSF9x9R24K0uYbcWgcP+VfGgWPw=";
          };
          
          dontUnpack = true;
          
          nativeBuildInputs = with pkgs; [ 
            autoPatchelfHook 
          ];
          
          buildInputs = with pkgs; [
            gtk3
            libxkbcommon
            xorg.libX11
            xorg.libXext
            xorg.libXi
            xorg.libXrender
            xorg.libXtst
            libGL
            stdenv.cc.cc.lib
            glib
            pango
            cairo
            gdk-pixbuf
            atk
            wayland
            libepoxy
          ];
          
          installPhase = ''
            mkdir -p $out/bin
            cp $src $out/bin/labwcchanger
            chmod +x $out/bin/labwcchanger
          '';
        };
        
      in {
        packages.default = app;

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [ flutter dart ];
        };
      });
}
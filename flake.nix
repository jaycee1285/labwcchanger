# flake.nix
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

        app = pkgs.stdenv.mkDerivation {
          pname    = "labwcchanger";
          version  = "0.1";

          ## 1 – point directly at the release asset
          src = pkgs.fetchurl {
            url    = "https://github.com/jaycee1285/labwcchanger/releases/download/relase/labwcchanger";
            # put lib.fakeSha256 while iterating; replace with real hash once Nix prints it
            sha256 = "sha256-VoYIgTq+wYBFx73mFSF9x9R24K0uYbcWgcP+VfGgWPw=";
          };
              postFetch = ''
    # delete whatever RPATH the upstream build contains
    patchelf --remove-rpath $out
  '';
          ## 2 – no unpack step, so skip to install
          phases = [ "installPhase" ];
          dontUnpack = true;

          ## 3 – let autoPatchelfHook patch ELF RPATHs
          nativeBuildInputs = [ pkgs.autoPatchelfHook ];

          ## 4 – runtime libraries Flutter-on-Linux typically needs
          buildInputs = with pkgs; [
            gtk3 libxkbcommon
            xorg.libX11 xorg.libXext xorg.libXi xorg.libXrender xorg.libXtst
            libGL       # OpenGL
            glib pango cairo gdk-pixbuf atk
            wayland libepoxy
          ];

          installPhase = ''
            runHook preInstall
            install -D $src $out/bin/labwcchanger
            chmod +x $out/bin/labwcchanger
            runHook postInstall
          '';
        };
      in {
        packages.default = app;

        ## (optional) dev shell for hacking on Flutter code
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [ flutter dart ];
        };
      });
}

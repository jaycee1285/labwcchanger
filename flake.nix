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
        bundle = builtins.fetchTarball {
          url    = "https://github.com/jaycee1285/labwcchanger/releases/download/release/labwcchanger1.0.tar.gz";
          sha256 = "sha256:125b6snri611j31qlp4hqr9056gd14g2z70hi09q4pkkq4gj5754";
        };
        runtimeLibs = with pkgs; [
          gtk3 libxkbcommon
          xorg.libX11 xorg.libXext xorg.libXi xorg.libXrender xorg.libXtst
          libGL glib pango cairo gdk-pixbuf atk wayland libepoxy
          # Missing libraries
          zlib
          harfbuzz
          stdenv.cc.cc.lib  # for libstdc++.so.6
        ];
        rpathSys = lib.makeLibraryPath runtimeLibs;
        loader   = "${pkgs.glibc}/lib/ld-linux-x86-64.so.2";
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname   = "labwcchanger";
          version = "1.0";  # Updated version to match release
          src = bundle;
          nativeBuildInputs = [ pkgs.patchelf pkgs.makeWrapper ];
          buildInputs       = runtimeLibs;
          installPhase = ''
            runHook preInstall
            
            # Create the proper directory structure
            mkdir -p $out/share/labwcchanger
            cp -r $src/* $out/share/labwcchanger/
            
            # Patch the actual binary
            chmod +w $out/share/labwcchanger/labwcchanger
            patchelf \
              --set-interpreter ${loader} \
              --set-rpath       ${rpathSys}:$out/share/labwcchanger/lib \
              $out/share/labwcchanger/labwcchanger
            
            # Create wrapper that changes to the app directory first
            mkdir -p $out/bin
            makeWrapper $out/share/labwcchanger/labwcchanger $out/bin/labwcchanger \
              --run "cd $out/share/labwcchanger"
              
            runHook postInstall
          '';
        };
        devShell = pkgs.mkShell { buildInputs = [ pkgs.flutter pkgs.dart ]; };
      });
}
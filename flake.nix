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
          sha256 = "sha256:1233749a8eda530e18fcf2a8506aeb70bb55c708b0899b77ce705e91013f5acd";
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
          nativeBuildInputs = [ pkgs.patchelf ];
          buildInputs       = runtimeLibs;
          installPhase = ''
            runHook preInstall
            # copy everything from the bundle
            mkdir -p $out
            cp -r $src/* $out/
            # move executable into $out/bin so it's on PATH
            mkdir -p $out/bin
            mv $out/labwcchanger $out/bin/
            chmod +w $out/bin/labwcchanger
            # patch loader + RPATH (system libs + bundled plugins)
            patchelf \
              --set-interpreter ${loader} \
              --set-rpath       ${rpathSys}:$out/lib \
              $out/bin/labwcchanger
            runHook postInstall
          '';
        };
        devShell = pkgs.mkShell { buildInputs = [ pkgs.flutter pkgs.dart ]; };
      });
}
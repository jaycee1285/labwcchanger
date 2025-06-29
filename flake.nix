{
  description = "LabWC theme changer (Flutter)";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        
        # Step 1: Create a fixed-output derivation for dependencies
        pubspecLock = ./pubspec.lock;
        
        depsSource = pkgs.stdenv.mkDerivation {
          name = "labwcchanger-deps-source";
          src = pkgs.lib.cleanSource ./.;
          
          nativeBuildInputs = [ pkgs.flutter pkgs.cacert pkgs.git ];
          
          # Fixed-output derivation - has network access
          outputHashMode = "recursive";
          outputHashAlgo = "sha256";
          # Start with a fake hash - the build will fail and tell you the real one
          outputHash = "sha256-0000000000000000000000000000000000000000000=";
          
          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
          GIT_SSL_CAINFO = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
          
          buildPhase = ''
            export HOME=$TMPDIR
            export PUB_CACHE=$TMPDIR/.pub-cache
            
            mkdir -p $out
            cp -r . $out/
            cd $out
            
            flutter config --no-analytics
            flutter pub get
            
            # Copy the pub-cache to the output
            cp -r $PUB_CACHE $out/.pub-cache
          '';
          
          dontInstall = true;
        };
        
        # Step 2: Build the app using the deps from step 1
        app = pkgs.stdenv.mkDerivation {
          pname = "labwcchanger";
          version = "0.1.0";
          
          src = depsSource;
          
          nativeBuildInputs = with pkgs; [
            flutter
            pkg-config
            gtk3
            pcre2
            util-linux
            libselinux
            libsepol
            libthai
            libdatrie
            libxkbcommon
            dbus
            xorg.libX11
            at-spi2-core
            libsecret
            jsoncpp
            xorg.libXdmcp
            xorg.libXtst
            libepoxy
          ];
          
          buildPhase = ''
            export HOME=$TMPDIR
            export PUB_CACHE=$(pwd)/.pub-cache
            
            flutter config --no-analytics
            flutter config --enable-linux-desktop
            flutter build linux --release --offline
          '';
          
          installPhase = ''
            mkdir -p $out/bin
            cp -r build/linux/x64/release/bundle/* $out/
            
            if [ -f $out/labwcchanger ]; then
              chmod +x $out/labwcchanger
              mv $out/labwcchanger $out/bin/
            fi
          '';
        };
        
      in {
        packages.default = app;

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [ flutter dart ];
        };
      });
}
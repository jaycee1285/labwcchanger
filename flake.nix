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
        
        # Remove dev dependencies from pubspec for the build
        buildPubspec = pkgs.writeText "pubspec.yaml" ''
          name: labwcchanger
          description: "A theme manager for LabWC"
          publish_to: 'none'
          version: 0.1.0
          environment:
            sdk: ^3.8.0
          dependencies:
            flutter:
              sdk: flutter
            xml: ^6.3.0
            window_size: ^0.1.0
            path: ^1.8.3
          flutter:
            uses-material-design: true
        '';
        
        app = pkgs.stdenv.mkDerivation {
          pname = "labwcchanger";
          version = "0.1.0";
          
          src = pkgs.lib.cleanSource ./.;
          
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
          
          # Override pubspec to remove dev dependencies
          preConfigure = ''
            cp ${buildPubspec} pubspec.yaml
          '';
          
          buildPhase = ''
            runHook preBuild
            
            export HOME=$(mktemp -d)
            export PUB_CACHE="$HOME/.pub-cache"
            export FLUTTER_ROOT="${pkgs.flutter}"
            
            # Configure flutter
            flutter config --no-analytics
            flutter config --enable-linux-desktop
            
            # Get dependencies
            flutter pub get
            
            # Build the app
            flutter build linux --release
            
            runHook postBuild
          '';
          
          installPhase = ''
            runHook preInstall
            
            mkdir -p $out
            cp -r build/linux/x64/release/bundle/* $out/
            
            # Ensure binary is executable and in the right place
            if [ -f $out/labwcchanger ]; then
              chmod +x $out/labwcchanger
              mkdir -p $out/bin
              mv $out/labwcchanger $out/bin/
            fi
            
            runHook postInstall
          '';
        };
        
      in {
        packages.default = app;

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [ 
            flutter 
            dart 
            pkg-config
            gtk3
          ];
        };
      });
}
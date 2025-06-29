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
        
        flutterDrv = pkgs.flutter.buildFlutterApplication {
          pname       = "labwcchanger";
          version     = "0.1.0";
          src         = ./.;
          pubspecLock = ./pubspec.lock;
        };
        
        # Let's see what attributes this derivation has
        debugInfo = builtins.trace "Flutter drv attrs: ${toString (builtins.attrNames flutterDrv)}" flutterDrv;
        
        # Create a clean wrapper
        app = pkgs.stdenv.mkDerivation {
          pname = "labwcchanger";
          version = "0.1.0";
          
          src = flutterDrv;
          
          dontBuild = true;
          dontUnpack = true;
          
          installPhase = ''
            mkdir -p $out
            cp -r $src/* $out/
            # Remove any .nix files that might have been copied
            find $out -name "*.nix" -delete 2>/dev/null || true
          '';
        };
        
      in {
        packages.default = app;

        devShell = pkgs.mkShell {
          buildInputs = [ pkgs.flutter pkgs.dart ];
        };
      });
}
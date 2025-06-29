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
        
        flutterApp = pkgs.flutter.buildFlutterApplication {
          pname       = "lchanger";
          version     = "0.1.0";
          src         = ./.;
          pubspecLock = ./pubspec.lock;
        };
        
        # Create a clean derivation that only includes the output
        app = pkgs.stdenv.mkDerivation {
          pname = "lchanger";
          version = "0.1.0";
          
          # Don't need a src since we're copying from flutterApp
          dontUnpack = true;
          
          installPhase = ''
            mkdir -p $out
            cp -r ${flutterApp}/* $out/
          '';
        };
        
      in {
        packages.default = app;

        devShell = pkgs.mkShell {
          buildInputs = [ pkgs.flutter pkgs.dart ];
        };
      });
}
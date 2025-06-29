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
        
        app = pkgs.flutter.buildFlutterApplication {
          pname       = "lchanger";
          version     = "0.1.0";
          src         = ./.;
          pubspecLock = ./pubspec.lock;
        };
        
      in {
        # Use passthru to ensure we're only exposing the derivation itself
        packages.default = app // { 
          # Override any problematic attributes
          inherit (app) name version pname outPath drvPath;
        };

        devShell = pkgs.mkShell {
          buildInputs = [ pkgs.flutter pkgs.dart ];
        };
      });
}
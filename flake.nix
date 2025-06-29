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
        
        # Use runCommand to create a clean package
        app = pkgs.runCommand "lchanger" {
          version = "0.1.0";
        } ''
          mkdir -p $out/bin $out/share
          
          # Copy binaries
          if [ -d ${flutterApp}/bin ]; then
            cp -r ${flutterApp}/bin/* $out/bin/
          fi
          
          # Copy any other needed files
          if [ -d ${flutterApp}/share ]; then
            cp -r ${flutterApp}/share/* $out/share/
          fi
          
          # Copy lib if it exists (for shared libraries)
          if [ -d ${flutterApp}/lib ]; then
            mkdir -p $out/lib
            cp -r ${flutterApp}/lib/* $out/lib/
          fi
        '';
        
      in {
        packages.default = app;

        devShell = pkgs.mkShell {
          buildInputs = [ pkgs.flutter pkgs.dart ];
        };
      });
}
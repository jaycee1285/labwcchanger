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
        lib = pkgs.lib;
        
        bundle = builtins.fetchTarball {
          url = "https://github.com/jaycee1285/labwcchanger/releases/download/release/labwcchanger1.0.tar.gz";
          sha256 = "sha256:125b6snri611j31qlp4hqr9056gd14g2z70hi09q4pkkq4gj5754";
        };
        
        runtimeLibs = with pkgs; [
          gtk3
          libxkbcommon
          xorg.libX11
          xorg.libXext
          xorg.libXi
          xorg.libXrender
          xorg.libXtst
          libGL
          glib
          pango
          cairo
          gdk-pixbuf
          atk
          at-spi2-atk  # Added for ATK bridge
          wayland
          libepoxy
          zlib
          harfbuzz
          stdenv.cc.cc.lib  # for libstdc++.so.6
          mesa  # Added for GL implementation
        ];
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "labwcchanger";
          version = "1.0";
          src = bundle;
          
          nativeBuildInputs = with pkgs; [
            autoPatchelfHook  # Use autoPatchelfHook instead of manual patchelf
            makeWrapper
            wrapGAppsHook  # Important for GTK apps
          ];
          
          buildInputs = runtimeLibs;
          
          # Tell autoPatchelfHook to also look in the bundled lib directory
          appendRunpaths = [ "$out/share/labwcchanger/lib" ];
          
          # Don't strip the binaries as it might break Flutter
          dontStrip = true;
          
          installPhase = ''
            runHook preInstall
            
            # Create the proper directory structure
            mkdir -p $out/share/labwcchanger
            cp -r . $out/share/labwcchanger/
            
            # Make sure the binary is writable for patching
            chmod -R +w $out/share/labwcchanger
            
            # The autoPatchelfHook will handle the patching automatically
            # But we need to ensure it looks in the right place for Flutter libs
            
            # Create wrapper that sets up the environment properly
            mkdir -p $out/bin
            makeWrapper $out/share/labwcchanger/labwcchanger $out/bin/labwcchanger \
              --chdir $out/share/labwcchanger \
              --prefix LD_LIBRARY_PATH : "$out/share/labwcchanger/lib:${lib.makeLibraryPath runtimeLibs}" \
              --set GDK_GL "gles"  # Sometimes helps with GL issues
              
            runHook postInstall
          '';
          
          # This helps autoPatchelfHook find the bundled Flutter libraries
          postFixup = ''
            # Ensure the main binary can find its bundled libraries
            patchelf --add-rpath '$ORIGIN/lib' $out/share/labwcchanger/labwcchanger
            
            # Patch any plugin libraries that might need system libraries
            for lib in $out/share/labwcchanger/lib/*.so; do
              if [ -f "$lib" ]; then
                patchelf --add-rpath "${lib.makeLibraryPath runtimeLibs}" "$lib" || true
              fi
            done
          '';
        };
        
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [ flutter dart ];
        };
      }
    );
}
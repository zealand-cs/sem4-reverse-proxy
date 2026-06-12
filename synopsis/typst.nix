{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      inputs',
      system,
      ...
    }:
    let
      typixLib = inputs.typix.lib.${system};

      commonArgs = {
        fontPaths = [
          # Add paths to fonts here
          "${pkgs.roboto}/share/fonts/truetype"
          "${pkgs.source-sans-pro}/share/fonts/truetype"
          "${pkgs.font-awesome}/share/fonts/opentype"
        ];

        virtualPaths = [
          # Add paths that must be locally accessible to typst here
          # {
          #   dest = "icons";
          #   src = "${inputs.font-awesome}/svgs/regular";
          # }
        ];
      };

      # Compile a Typst project, and then copy the result
      # to the current directory
      build-script =
        file:
        typixLib.buildTypstProjectLocal (
          commonArgs
          // {
            typstSource = file;
            src = typixLib.cleanTypstSource ./.;
            typstOpts.root = ".";
          }
        );

      # Watch a project and recompile on changes
      watch-script =
        file:
        typixLib.watchTypstProject (
          commonArgs
          // {
            typstSource = file;
            typstOpts.root = ".";
          }
        );

      mkPdfApp = script: {
        type = "app";
        program = "${script}/bin/${script.name}";
      };
    in
    {
      apps = {
        build-synopsis = mkPdfApp (build-script "./main.typ");
        watch-synopsis = mkPdfApp (watch-script "./main.typ");

        build-presentation = mkPdfApp (build-script "./presentation.typ");
        watch-presentation = mkPdfApp (watch-script "./presentation.typ");
      };

      devShells.typix = typixLib.devShell {
        inherit (commonArgs) fontPaths virtualPaths;
        packages = [
          pkgs.font-awesome
          # WARNING: Don't run `typst-build` directly, instead use `nix run .#build`
          # See https://github.com/loqusion/typix/issues/2
          # build-script
          # (watch-script "")
          # More packages can be added here, like typstfmt
          # pkgs.typstfmt
        ];
      };
    };
}

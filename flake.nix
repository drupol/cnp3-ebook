{
  description = "CNP3";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-pydata-sphinx-theme.url = "github:NixOS/nixpkgs?rev=19d31fc041778c7d969b04b18b1e3cb91a804c6b";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, nixpkgs-pydata-sphinx-theme, ... }@inputs:
    with flake-utils.lib; eachSystem allSystems (system:
      let
        version = self.shortRev or self.lastModifiedDate;

        overlays = [
          (final: prev: {
            master = import inputs.nixpkgs-master {
              inherit (final) config;
              system = "${prev.system}";
            };
          })
          (final: prev: {
            pydata-sphinx-theme = import inputs.nixpkgs-pydata-sphinx-theme {
              inherit (final) config;
              system = "${prev.system}";
            };
          })
        ];

        pkgs = import nixpkgs {
          inherit overlays system;
          config = {
            allowUnfreePredicate = (pkg: true);
          };
        };

        # Doesn't seems to be used ?
        #
        # standalone = pkgs.fetchzip {
        #   name = "latex-standalone";
        #   url = "http://mirrors.ctan.org/install/macros/latex/contrib/standalone.tds.zip";
        #   sha256 = "";
        #   stripRoot = false;
        # };

        tex = pkgs.texlive.combine {
          inherit (pkgs.texlive) scheme-full latex-bin latexmk epstopdf;
        };

        # mscgen custom derivation
        # TODO: Submit this to NixOS/nixpkgs
        mscgenDrv = pkgs.pydata-sphinx-theme.python3Packages.buildPythonPackage {
          pname = "sphinxcontrib-mcsgen";
          version = "1.0.0";

          nativeBuildInputs = [ pkgs.pydata-sphinx-theme.python3Packages.sphinx ];

          src = pkgs.fetchFromGitHub {
            owner = "obonaventure";
            repo = "mscgen";
            rev = "26bc79a8b6e16093411092775d514cda6354ce6e";
            sha256 = "TvxNAe+eK7fEj21s5vXRFMkw/TCBuypUOpSdEnxD39I=";
          };
        };

        # Custom sphinxcontrib-tikz with a patch. Is it really needed?
        #
        # tikzDrv = pkgs.python310Packages.sphinxcontrib-tikz.overrideAttrs (attrs: {
        #   patches = (attrs.patches or []) ++ [
        #     (pkgs.fetchpatch {
        #       url = "https://github.com/sphinx-contrib/tikz/commit/0c7961ee6c5e1651bb117877a53203feea82e5dc.patch";
        #       sha256 = "xqIsOFc6NaOffbEfQkuy0h4Ya0dE6m7B+vtMzirQMMs=";
        #     })
        #   ];
        # });

        sphinx-build =
          let
            env = pkgs.pydata-sphinx-theme.python3.withPackages (pp: with pp; [
              sphinx
              recommonmark
              sphinx_rtd_theme
              mscgenDrv
              sphinxcontrib-spelling
              pyenchant
              sphinxcontrib-tikz
              sphinx-book-theme
              pydata-sphinx-theme
            ]);
          in
          # Expose only the sphinx-build binary to avoid contaminating
          # everything with Sphinx’s Python environment.
          pkgs.runCommand "sphinx-build" { } ''
            mkdir -p "$out/bin"
            ln -s "${env}/bin/sphinx-build" "$out/bin"
          '';

        documentProperties = {
          name = "cnp3";
          inputs = [
            # Core derivations
            pkgs.coreutils
            pkgs.gnumake
            pkgs.pandoc
            pkgs.plantuml
            pkgs.nixpkgs-fmt
            pkgs.nixfmt
            pkgs.inkscape
            pkgs.netpbm
            pkgs.poppler_utils
            pkgs.dejavu_fonts
            pkgs.pgfplots
            pkgs.imagemagick
            pkgs.mscgen
            # Custom derivations
            tex
            mscgenDrv
            sphinx-build
          ];
        };

        pdf = pkgs.stdenv.mkDerivation {
          name = documentProperties.name + "-pdf";
          fullname = documentProperties.name + "-" + version;
          src = self;

          nativeBuildInputs = documentProperties.inputs;

          buildPhase = ''
            sphinx-build -M latexpdf . tmp
          '';

          installPhase = "install -m 0644 -vD tmp/latex/CNP3.pdf \"$out\"";
        };

        epub = pkgs.stdenv.mkDerivation {
          name = documentProperties.name + "-epub";
          fullname = documentProperties.name + "-" + version;
          src = self;

          nativeBuildInputs = documentProperties.inputs;

          buildPhase = ''
            sphinx-build -M epub . tmp
          '';

          installPhase = "install -m 0644 -vD tmp/epub/CNP3.epub \"$out\"";
        };

        html = pkgs.stdenv.mkDerivation {
          name = documentProperties.name + "-html";
          fullname = documentProperties.name + "-" + version;
          src = self;

          nativeBuildInputs = documentProperties.inputs;

          buildPhase = ''
            sphinx-build -M html . tmp
          '';

          installPhase = "cp -r tmp/html/ \"$out\"";
        };

      in
      rec {
        # nix shell, nix build
        packages = {
          html = html;
          pdf = pdf;
          epub = epub;
          default = self.packages.${system}.pdf;
        };

        # nix develop
        devShell = pkgs.mkShellNoCC {
          name = documentProperties.name;
          buildInputs = documentProperties.inputs;
        };
      });
}

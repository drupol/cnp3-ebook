{
  description = "CNP3";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-pydata-sphinx-theme.url = "github:NixOS/nixpkgs?rev=19d31fc041778c7d969b04b18b1e3cb91a804c6b";
    nixpkgs-sphinxcontrib-mscgen.url = "github:drupol/nixpkgs/add-sphinx-contrib-mscgen";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, nixpkgs-pydata-sphinx-theme, nixpkgs-sphinxcontrib-mscgen, ... }@inputs:
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
          # Remove this when https://github.com/NixOS/nixpkgs/pull/192650 lands
          (final: prev: {
            sphinxcontrib-mscgen = import inputs.nixpkgs-sphinxcontrib-mscgen {
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

        sphinx = pkgs.pydata-sphinx-theme.python3.withPackages (pp: [
            pp.pyenchant
            pp.readthedocs-sphinx-ext
            pp.recommonmark
            pp.sphinx_rtd_theme
            pp.sphinx-book-theme
            pp.sphinxcontrib-spelling
            pp.sphinxcontrib-tikz
        ]);

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
            sphinx
            (pkgs.sphinxcontrib-mscgen.python3Packages.sphinxcontrib-mscgen.overrideAttrs (attrs: {
              inherit sphinx;
              patches = (attrs.patches or []) ++ [
                # https://github.com/sphinx-contrib/mscgen/commit/26bc79a8b6e16093411092775d514cda6354ce6e
                #  small fix for build proble
                (pkgs.fetchpatch {
                  url = "https://github.com/sphinx-contrib/mscgen/commit/26bc79a8b6e16093411092775d514cda6354ce6e.patch";
                  sha256 = "sqNIn4MFC+6Ai17czQUB8g9CmfHDobDF/jaIgf086AM=";
                })
                #  Update mscgen.py
                (pkgs.fetchpatch {
                  url = "https://github.com/sphinx-contrib/mscgen/commit/b71f74ebfbe70dad3970c2b0ec5350a70db6ec1f.patch";
                  sha256 = "VbNoPGfN6DBVg4Kfjh14Q6awFm7LiuYdPZ6M8EEglgA=";
                })
              ];
            }))
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

          installPhase = ''
            install -m 0644 -vD tmp/latex/CNP3.pdf $out
          '';
        };

        epub = pkgs.stdenv.mkDerivation {
          name = documentProperties.name + "-epub";
          fullname = documentProperties.name + "-" + version;
          src = self;

          nativeBuildInputs = documentProperties.inputs;

          buildPhase = ''
            sphinx-build -b epub . tmp
          '';

          installPhase = ''
            install -m 0644 -vD tmp/epub/CNP3.epub $out
          '';
        };

        html = pkgs.stdenv.mkDerivation {
          name = documentProperties.name + "-html";
          fullname = documentProperties.name + "-" + version;
          src = self;

          nativeBuildInputs = documentProperties.inputs;

          buildPhase = ''
            sphinx-build -b html . tmp
          '';

          installPhase = "cp -r tmp/html/ $out";
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

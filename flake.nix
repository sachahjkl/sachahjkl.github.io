{
  description = "Sacha Froment's personal website";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    theme = {
      url = "git+https://github.com/sachahjkl/hugo_theme_hjkl.it.git?rev=6e84649cbd3fb750a89f0f8d69e9c79b8724a08f";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      theme,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: import nixpkgs { inherit system; };
      siteFor =
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "sachahjkl.github.io";
          version = "1";
          src = ./.;
          nativeBuildInputs = [ pkgs.hugo ];

          buildPhase = ''
            runHook preBuild
            rm -rf themes/hugo_theme_hjkl.it
            cp -R ${theme} themes/hugo_theme_hjkl.it
            chmod -R u+w themes/hugo_theme_hjkl.it
            export HOME="$TMPDIR"
            export HUGO_CACHEDIR="$TMPDIR/hugo-cache"
            hugo --destination "$out" --noBuildLock --printPathWarnings
            substituteInPlace "$out/css/site.css.map" --replace-fail "$PWD" "."
            runHook postBuild
          '';

          installPhase = "true";
        };
    in
    {
      packages = forAllSystems (system: {
        default = siteFor system;
        site = siteFor system;
      });

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          site = siteFor system;
        in
        {
          inherit site;

          actionlint = pkgs.runCommand "actionlint" { nativeBuildInputs = [ pkgs.actionlint ]; } ''
            actionlint -config-file ${./.github/actionlint.yaml} ${./.github/workflows}/*.yml
            touch "$out"
          '';

          links = pkgs.runCommand "site-links" { nativeBuildInputs = [ pkgs.lychee ]; } ''
            export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
            lychee --offline --root-dir "${site}" "${site}"
            touch "$out"
          '';
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShellNoCC {
            packages = [
              pkgs.actionlint
              pkgs.hugo
              pkgs.lychee
              pkgs.nixfmt-tree
            ];
          };
        }
      );
    };
}

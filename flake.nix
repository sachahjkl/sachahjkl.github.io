{
  description = "Sacha Froment's personal website";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    hugo-nixpkgs.url = "github:NixOS/nixpkgs/0afa1438f7b195a370a971a025310c69cb8b2742";
    theme = {
      url = "git+https://github.com/sachahjkl/hugo_theme_hjkl.it.git?rev=a6505b23dc5a1c8bf8da46775f5d68e85bf48ee0";
      flake = false;
    };
  };

  outputs =
    {
      hugo-nixpkgs,
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
      hugoFor = system: (import hugo-nixpkgs { inherit system; }).hugo;
      siteFor =
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "sachahjkl.github.io";
          version = "1";
          src = ./.;
          nativeBuildInputs = [ (hugoFor system) ];

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
              (hugoFor system)
              pkgs.lychee
              pkgs.nixfmt-tree
            ];
          };
        }
      );
    };
}

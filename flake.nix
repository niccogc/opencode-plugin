{
  description = "OpenCode Plugins Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    oh-my-opencode-src = {
      url = "github:code-yeongyu/oh-my-opencode";
      flake = false;
    };
    antigravity-src = {
      url = "github:shekohex/opencode-google-antigravity-auth";
      flake = false;
    };
    anthropic-auth-src = {
      url = "github:sst/opencode-anthropic-auth";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    oh-my-opencode-src,
    antigravity-src,
    anthropic-auth-src,
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    mkOpenCodePlugin = {
      pname,
      version,
      src,
      outputHash,
      entryPoint ? "src/index.ts",
    }: let
      node_modules = pkgs.stdenvNoCC.mkDerivation {
        pname = "${pname}-node_modules-${version}";
        inherit version src;
        nativeBuildInputs = [pkgs.bun pkgs.writableTmpDirAsHomeHook];
        dontFixup = true;
        buildPhase = ''
          export HOME=$TMPDIR
          bun install --no-progress
        '';
        installPhase = "cp -r node_modules $out";
        inherit outputHash;
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
      };
    in
      pkgs.stdenvNoCC.mkDerivation {
        inherit pname version;
        src = src // {url = src.outPath;};
        passthru = {
          updateScript = [
            "${pkgs.nix-update}/bin/nix-update"
            "--version"
            "branch"
            pname
          ];
        };
        nativeBuildInputs = [pkgs.bun pkgs.typescript];
        buildPhase = ''
          cp -r ${node_modules} node_modules
          chmod -R u+w node_modules
          patchShebangs node_modules/.bin

          ENTRY="${entryPoint}"
          if [ ! -f "$ENTRY" ]; then ENTRY="index.ts"; fi

          bun build "$ENTRY" --outdir dist --target bun --format esm

          if [ -f "tsconfig.json" ]; then
            tsc --emitDeclarationOnly --declaration || echo "Warning: Type generation failed, but JS is bundled."
          fi
        '';
        installPhase = ''
          mkdir -p $out
          cp -r dist package.json $out/
        '';
      };
  in {
    inherit inputs;
    packages.${system} = {
      oh-my-opencode = mkOpenCodePlugin {
        pname = "oh-my-opencode";
        version = "3.5.3";
        src = oh-my-opencode-src;
        outputHash = "sha256-agFAByv56DGQjqPbzCixYAIFvnCATMZXTx3ujHFLev4=";
      };
      antigravity = mkOpenCodePlugin {
        pname = "opencode-antigravity-auth";
        version = "0.2.15";
        src = antigravity-src;
        entryPoint = "index.ts";
        outputHash = "sha256-RdkuMjqkwzHTeNFeNDkO/wtHjh6/dMqcpzqJZGR/YH4=";
      };
      anthropic-auth = mkOpenCodePlugin {
        pname = "opencode-anthropic-auth";
        version = "0.0.13";
        src = anthropic-auth-src;
        entryPoint = "index.mjs";
        outputHash = "sha256-uYg2Gwb7fLJxfamf3M1ZcAAQYTiYRD3S8/+QH8uTMHs=";
      };
    };
  };
}

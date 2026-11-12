{ pkgs }:
let
  schemas = {
    # Match the Homebrew Codex CLI; schema provenance is in Backlog doc-8.
    codex = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/openai/codex/rust-v0.167.0/codex-rs/core/config.schema.json";
      hash = "sha256-Zu15U1LTLyRkd4rNLjMrf6/mRCRtVAzc7sRmPFbPvBY=";
    };
    claude = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/SchemaStore/schemastore/bf7c6745505ccace5568dc0d7f4ae29647e9b41a/src/schemas/json/claude-code-settings.json";
      hash = "sha256-8m8CitlKHioo6drR+AgyqxlqjggL06fXoy5kKKFeBhE=";
    };
    # Vendored snapshots of the published schemas, which have no immutable URL.
    opencode = ./schemas/opencode-config.json;
    opencode-cli = ./schemas/opencode-cli.json;
  }
  // builtins.listToAttrs (
    map
      (name: {
        name = "pi-${name}";
        value = "${pkgs.pi-coding-agent}/lib/node_modules/pi-monorepo/schemas/${name}.schema.json";
      })
      [
        "settings"
        "keybindings"
        "models"
        "theme"
      ]
  );
  # Keep only schema JSON in the validator's runtime closure, rather than
  # pulling the Pi executable into every merge helper.
  bundle = pkgs.runCommandLocal "agent-config-schemas" { } ''
    mkdir -p "$out"
    ${builtins.concatStringsSep "\n" (
      map (name: ''cp ${schemas.${name}} "$out/${name}.json"'') (builtins.attrNames schemas)
    )}
  '';
  manifest = pkgs.writeText "agent-config-schemas.json" (
    builtins.toJSON (builtins.mapAttrs (name: _: "${bundle}/${name}.json") schemas)
  );
  validation = pkgs.python3Packages.buildPythonPackage {
    pname = "agent-config-validation";
    version = "1";
    format = "other";
    dontUnpack = true;
    dependencies = with pkgs.python3Packages; [
      jsonschema
      json5
    ];
    doCheck = true;
    nativeCheckInputs = with pkgs.python3Packages; [
      tomli-w
      tomlkit
    ];
    checkPhase = ''
      cp ${./agent_config_validation.py} agent_config_validation.py
      cp ${manifest} agent-config-schemas.json
      cp ${../modules/home/programs/ai/cleanup-agent-config.py} cleanup-agent-config.py
      cp ${../../tests/ai/test_cleanup_agent_config.py} test_cleanup_agent_config.py
      cp ${../../tests/ai/test_agent_config_validation.py} test_agent_config_validation.py
      export PYTHONPATH="$PWD''${PYTHONPATH:+:$PYTHONPATH}"
      export CLEANUP_AGENT_CONFIG="$PWD/cleanup-agent-config.py"
      export MERGE_CONFIG=${../modules/home/merge-config.py}
      ${pkgs.python3.interpreter} -m unittest discover -v
    '';
    pythonImportsCheck = [ "agent_config_validation" ];
    passthru.validator =
      pkgs.writers.writePython3Bin "validate-agent-config"
        {
          libraries = [ validation ];
        }
        ''
          from agent_config_validation import main

          main()
        '';
    installPhase = ''
      mkdir -p "$out/${pkgs.python3.sitePackages}"
      cp ${./agent_config_validation.py} "$out/${pkgs.python3.sitePackages}/agent_config_validation.py"
      cp ${manifest} \
        "$out/${pkgs.python3.sitePackages}/agent-config-schemas.json"
    '';
  };
in
validation

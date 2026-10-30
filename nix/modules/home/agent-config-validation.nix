{ pkgs }:
let
  schemas = {
    # Match the Homebrew Codex CLI used here (see docs/agent-keybindings.md).
    codex = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/openai/codex/rust-v0.166.0/codex-rs/core/config.schema.json";
      hash = "sha256-IRvsIoJFn81w5JBa+UhyEXe27HoD4N+EzYt8ExAGpso=";
    };
    claude = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/SchemaStore/schemastore/bf7c6745505ccace5568dc0d7f4ae29647e9b41a/src/schemas/json/claude-code-settings.json";
      hash = "sha256-8m8CitlKHioo6drR+AgyqxlqjggL06fXoy5kKKFeBhE=";
    };
    opencode = pkgs.opencode.passthru.jsonschema.config;
    opencode-cli = pkgs.opencode.passthru.jsonschema.cli;
    # Legacy OpenCode 1 client, alongside the pinned OpenCode 2 schemas.
    opencode-tui = pkgs.fetchurl {
      url = "https://opencode.ai/tui.json";
      hash = "sha256-6zYeKEZpvCU5gsUpsaZ6jYZ+XNlqbqppbvFiV0+Fwd8=";
    };
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
  # pulling the OpenCode and Pi executables into every merge helper.
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
      cp ${./programs/ai/cleanup-agent-config.py} cleanup-agent-config.py
      cp ${./programs/ai/test_cleanup_agent_config.py} test_cleanup_agent_config.py
      cp ${./programs/ai/test_agent_config_validation.py} test_agent_config_validation.py
      export PYTHONPATH="$PWD''${PYTHONPATH:+:$PYTHONPATH}"
      export MERGE_CONFIG=${./merge-config.py}
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

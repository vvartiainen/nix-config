{ lib, ... }:
let
  allowAfterStar = lib.hm.dag.entryAfter [ "*" ] "allow";
  denyAfterStar = lib.hm.dag.entryAfter [ "*" ] "deny";
in
{
  programs.opencode = {
    enable = true;
    # Homebrew provides the binary; this module only manages config.
    package = null;

    settings = {
      model = "github-copilot/gpt-5.4";
      permission = {
        bash = {
          "*" = "ask";
          "git status *" = allowAfterStar;
          "git diff *" = allowAfterStar;
          "grep *" = allowAfterStar;
          "npm run test *" = allowAfterStar;
          "npm run build *" = allowAfterStar;
          "npm run format *" = allowAfterStar;
          "npm test *" = allowAfterStar;
          "npx vitest *" = allowAfterStar;
          "npx tsc *" = allowAfterStar;
          "npx eslint *" = allowAfterStar;
          "terraform fmt *" = allowAfterStar;
          "terraform validate *" = allowAfterStar;
        };
        read = {
          "*" = "allow";
          "*.env" = denyAfterStar;
          "*.env.*" = denyAfterStar;
          "*.env.example" = lib.hm.dag.entryAfter [
            "*.env"
            "*.env.*"
          ] "allow";
        };
      };
    };

    tui.theme = "catppuccin";
  };
}

{ lib, config, repoRoot }:
let
  # List files from the flake tree so gitignored runtime dirs (node_modules,
  # etc.) are not linked. Symlink targets still use repoRoot so edits apply
  # without a rebuild.
  dotfilesSrc = ../../../dotfiles;

  skipNames = [
    "node_modules"
    ".git"
    ".DS_Store"
  ];

  # Runtime files that programs write next to config (do not manage).
  skipRels = [
    "opencode/package.json"
    "opencode/package-lock.json"
    "opencode/bun.lock"
  ];

  link = rel: config.lib.file.mkOutOfStoreSymlink "${repoRoot}/dotfiles/${rel}";

  # Per-file links so ~/.config/<app> stays a real directory that programs
  # can write into at runtime.
  linkTree =
    rel:
    let
      walk =
        prefix: dir:
        lib.concatMapAttrs (
          name: type:
          if builtins.elem name skipNames then
            { }
          else
            let
              childRel = "${prefix}/${name}";
            in
            if type == "directory" then
              walk childRel (dir + "/${name}")
            else if builtins.elem childRel skipRels then
              { }
            else
              { ${childRel} = { source = link childRel; }; }
        ) (builtins.readDir dir);
    in
    walk rel (dotfilesSrc + "/${rel}");
in
{
  inherit link linkTree;
}

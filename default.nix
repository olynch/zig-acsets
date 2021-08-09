{ pkgs, ... }:

let
  shell = pkgs.mkShell {
    hardeningDisable = [ "all" ];
    buildInputs = with pkgs; [ zig ];
  };
in { inherit shell; }

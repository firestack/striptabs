{
	description = "Strip tabs, for when nix fails you";

	outputs = { self, nixpkgs }: let 
		stripTabsFn = lib: text: let
			# Whether all lines start with a tab (or is empty)
			shouldStripTab = lines: builtins.all (line: (line == "") || (lib.strings.hasPrefix "	" line)) lines;
			# Strip a leading tab from all lines
			stripTab = lines: builtins.map (line: lib.strings.removePrefix "	" line) lines;
			# Strip tabs recursively until there are none
			stripTabs = lines: if (shouldStripTab lines) then (stripTabs (stripTab lines)) else lines;
		in
			# Split into lines. Strip leading tabs. Concat back to string.
			builtins.concatStringsSep "\n" (stripTabs (lib.strings.splitString "\n" text));
	in {
		# Packaged from https://github.com/NixOS/nix/issues/3759#issuecomment-653033810

		lib.stripTabs = stripTabsFn nixpkgs.lib;

		/*
		# QOL Utilitiy Attributes
		Eg
			``` inherit (flakes.striptabs) stripTabs;```
		or 
			``` flakes.striptabs.fn ''<multiline-tab-indented-string>'' ```;
		*/

		fn = self.lib.stripTabs;
		stripTabs = self.lib.stripTabs;
		

		/*
		# Utility Access via `pkgs`
		E.g.
			```callPackage ./package.nix { }; # provides `stripTabs` as requested by name```
		or
			```pkgs.stripTabs ''<multiline-tab-indented-string>''```
		*/
		overlays.default = self.overlays.stripTabs;

		overlays.stripTabs = final: prev: {
			stripTabs = stripTabsFn final.lib;
		};
	};
}

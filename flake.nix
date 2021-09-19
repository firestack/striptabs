{
	description = "Strip tabs, for when nix fails you";

	outputs = { self, nixpkgs }: let inherit (nixpkgs) lib; in {
		# Packaged from https://github.com/NixOS/nix/issues/3759#issuecomment-653033810

		lib.stripTabs = text: let
			# Whether all lines start with a tab (or is empty)
			shouldStripTab = lines: builtins.all (line: (line == "") || (lib.strings.hasPrefix "	" line)) lines;
			# Strip a leading tab from all lines
			stripTab = lines: builtins.map (line: lib.strings.removePrefix "	" line) lines;
			# Strip tabs recursively until there are none
			stripTabs = lines: if (shouldStripTab lines) then (stripTabs (stripTab lines)) else lines;
		in
			# Split into lines. Strip leading tabs. Concat back to string.
			builtins.concatStringsSep "\n" (stripTabs (lib.strings.splitString "\n" text));


	};
}

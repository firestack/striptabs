{
	description = "Strip tabs, for when nix fails you";

	inputs.utils.url = "github:numtide/flake-utils";

	outputs = { self, nixpkgs, utils }: let
		inherit (nixpkgs) lib;

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

		lib.stripTabs = let 
			stripTabs = stripTabsFn nixpkgs.lib;

			evaluatedTests = builtins.mapAttrs
				(_test_name: test_case: test_case // rec {
					input = stripTabs test_case.input;
					comparison = [ test_case.expected input ];
				})
				self.nixTests.text.cases;

			assertions = fn:
				let
					testFn = test_name: test_data:
						lib.asserts.assertMsg 
							(with test_data; expected == input)
							stripTabs ''
								`input` differs from `expected`
								::  Expected ::
								${test_data.expected}
								
								::  Recieved ::
								${test_data.input}
							'';
				in
					assert builtins.all
						({test_name, test_data}: testFn test_name test_data)
						(lib.attrsets.mapAttrsToList
							(test_name: test_data: { inherit test_name test_data; })
							evaluatedTests);
					fn;

		in assertions stripTabs;

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

		nixTests.text.fn.assertMsg = { test_name, test_data }:
			lib.asserts.assertMsg
				(nixTests.text.fn.predicate test_data)
				(nixTests.text.fn.errorMessage test_name test_data);
		nixTests.text.fn.predicate = case: (case.expected == case.input);
		nixTests.text.fn.errorMessage = stripTabs: test_name: { expected, input }: stripTabs ''
			:: Error In Test :: ${test_name}
			`input` differs from `expected`

			::  Expected ::
			${expected}
			
			::  Recieved ::
			${input}
		'';

		nixTests.text.cases = {
			# empty = {
			# 	input = '''';
			# 	expected = "";
			# };

			trivial = {
				input = ''indent0'';
				expected = "indent0";
			};

			trivial_newline = {
				input = ''
					indent0
				'';
				expected = "indent0\n";
			};
			
			trivial_newline2 = {
				input = ''
					indent0
					indent0
					indent0
				'';
				expected = "indent0\nindent0\nindent0\n";
			};
			
			trivial_indent = {
				input = ''
					indent0
						indent1
					indent0
				'';
				expected = "indent0\n\tindent1\nindent0\n";
			};

			multiple_indent_levels = {
				input = ''
					indent0
							indent2
						indent1
					indent0
				'';
				expected = "indent0\n\t\tindent2\n\tindent1\nindent0\n";
			};
		};
	}
	// utils.lib.eachSystem [ "x86_64-linux" ] (system: let
		inherit (utils.lib.check-utils system) isEqual; 
		isDataTestEqual = fn: { input, expected }: isEqual input (fn expected);
	in {
		# checks = builtins.mapAttrs (_test_name: isDataTestEqual self.stripTabs) self.nixTests.text.cases;
	});
}

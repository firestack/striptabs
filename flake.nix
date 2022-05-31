{
	description = "Strip tabs, for when nix fails you";

	outputs = { self, nixpkgs }: let

		inherit (nixpkgs) lib;

		# Packaged from https://github.com/NixOS/nix/issues/3759#issuecomment-653033810
		stripTabsFn = lib: text: let
			# Whether all lines start with a tab (or is empty)
			shouldStripTab = lines: builtins.all (line: (line == "") || (lib.strings.hasPrefix "\t" line)) lines;
			# Strip a leading tab from all lines
			stripTab = lines: builtins.map (line: lib.strings.removePrefix "\t" line) lines;
			# Strip tabs from lines recursively until there are none
			stripTabs = lines:
				if (builtins.all (line: line == "") lines) then lines
				else if (shouldStripTab lines) then (stripTabs (stripTab lines))
				else lines;
		in
			# Split into lines. Strip leading tabs. Concat back to string.
			builtins.concatStringsSep "\n" (stripTabs (lib.strings.splitString "\n" text));

	in {
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

		nixTests.text = {
			fn = {
				assertMsg = test_name: test_data:
					lib.asserts.assertMsg
						(self.nixTests.text.fn.predicate test_data)
						(self.nixTests.text.fn.errorMessage test_name test_data);

				predicate = case: (case.config.expected == case.output);

				errorMessage = let
					makePrintable = string: builtins.replaceStrings [ 
						" "
						"\t"
						"\n"
					] [
						"·"
						"→"
						"\\n"
					] string;
				in test_name: { config, output }: (self.stripTabs ''
					:: Error In Test :: ${test_name}
					`input` differs from `expected`

					::  Expected ::
					${makePrintable config.expected}
					
					::  Recieved ::
					${makePrintable output}
				'');
			};

			result = builtins.all
				({ test_name, test_result}: test_result.success && test_result.value.result)
					(lib.attrsets.mapAttrsToList
						(test_name: test_result: { inherit test_name test_result; })
						self.nixTests.text.eval);

			output = assert self.nixTests.text.result; self.nixTests.text.eval;
			eval = builtins.mapAttrs
				(test_name: test_config: builtins.tryEval (let evalTest = {
					inherit test_config;
					result = self.nixTests.text.fn.assertMsg test_name test_config;
					expect_equal = [ test_config.config.expected test_config.output ];
				}; in builtins.deepSeq evalTest evalTest))
				self.nixTests.text.cases;

			cases = (attrs:
				builtins.mapAttrs
					(test_name: test_config: rec {
						config = test_config;
						# inherit (test_config) expected;
						output = self.stripTabs test_config.input;
					})
					(lib.attrsets.filterAttrs
						(name: value: value.enable or true)
						attrs
					))
			{

				empty = {
					input = '''';
					expected = "";
				};

				empty2 = {
					input = ''

					'';
					expected = "\n";
				};

				empty3 = {
					input = "\t\t\t";
					expected = "";
				};

				identity = {
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

				arbitrary_indent = {
					input = ''
								indent0
								indent0
								indent0'';
					expected = "indent0\nindent0\nindent0";
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

				indented_content_first = {
					input = ''
								indent2
									indent3
								indent2
						indent0
					'';
					expected = "\t\tindent2\n\t\t\tindent3\n\t\tindent2\nindent0\n";
				};

				error_message_test = {
					enable = true;
					input = ''
						:: Error In Test :: ''${test_name}
						`input` differs from `expected`

						::  Expected ::
						''${config.expected}

						::  Recieved ::
						''${output}
					'';
					expected = ":: Error In Test :: \${test_name}\n"
					+ "`input` differs from `expected`\n\n"
					+ "::  Expected ::\n"
					+ "\${config.expected}\n\n"
					+ "::  Recieved ::\n"
					+ "\${output}\n";
				};

				error_message_test2 = {
					enable = true;
					input = ''
						:: Error In Test :: ''${test_name}
							`input` differs from `expected`

						::  Expected ::
						''${config.expected}

						::  Recieved ::
						''${output}
					'';
					expected = ":: Error In Test :: \${test_name}\n"
					+ "\t`input` differs from `expected`\n\n"
					+ "::  Expected ::\n"
					+ "\${config.expected}\n\n"
					+ "::  Recieved ::\n"
					+ "\${output}\n";
				};
			};
		};
	};
}

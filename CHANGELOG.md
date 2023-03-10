# 1.3 (Mar 11 2023)
- Implement inlay hints
- Implement `textDocument/documentHighlight`
- Listen to `workspace/didCreateFiles` and `workspace/didDeleteFiles`
- Slightly improve auto completion
- Send memory usage information to the server periodically
- Fix a lot of type definitions
- Add some heuristics for `subdir(x)`, where x is not a string literal. This allows parsing e.g. GTK correctly.
- Add web-based dashboard for showing performance over the time
# 1.2.1 (Feb 16 2023)
- Upload binary on release
# 1.2 (Feb 16 2023)
- Cache AST for all unopened documents
- Cancel rebuilding the tree, if another rebuild has started
- Fix some bugs with jumping to declaration. (Sadly comes with a performance regression)
- Add required code for VSCode
- Add installation instructions for Kate
- Don't advertise support for higlighting
- Bump swift-argument-parser
- Setup CI workflow to measure RAM-usage/performance regressions
# 1.1 (Feb 13 2023)
## Changes
- Reduced memory usage (Up to 60%) by just allocating methods for each type only once, instead for each object created.
- Improve performance for some projects (0%-60%) by switching from structs to classes for all types. This reduces the amount of copying needed.
- On the other side, improvements to the type analysis had some negative performance impact. See the measurements below.
- Fix a lot of bad type definitions (Some still remain, feel free to file bugs/submit a PR if you encounter one)
- Implement some test cases for validation of the type deduction and the emitted diagnostics
- Use meson test cases to check for bad type definitions.
- Show an error if the condition is not bool
- Show an error if the number of identifiers in a foreach-loop is not appropriate for the type on the right side
- Several other added diagnostics
- Improve the handling of if-Statements during type deduction
- Fix some bugs regarding the handling of binary expressions during type analysis
- Improve code quality
- Add CI with automatic tests
- Add `--stdio` flag for VSCode. (I have started to work on a [fork of vscode-meson](https://github.com/JCWasmx86/vscode-meson) to add support, but it does not work yet.
Feel free to reach out, if you want to help.)
- If the CLI is used for parsing a project, print the diagnostics in an GCC-compatible style, so it can be used e.g. by IDEs.
- Don't clear file if the meson.build file has parsing errors.
- Bump tree-sitter-meson and fix some parser bugs:
  - Don't fail on empty files with an error
  - Allow uppercase `0X`, `0B`, `0O`

## Measurements
These measurements are based on the meson build system of four projects:
- GNOME Builder (~4.8KLOC meson, medium size)
- GNOME-Builder-Plugins (~465LOC meson, small size)
- mesa (~16.4KLOC, huge size)
- QEMU (~9.3KLOC, medium size)

| Measurement                                                                        | v1.0      | v1.1      | Quotient ((v1.1/v1.0) * 100) - 100 | Better? |
|------------------------------------------------------------------------------------|-----------|-----------|------------------------------------|---------|
| Clean compile time (`rm -rf .build&&swift build -c release --static-swift-stdlib`) | 182.93s   | 211.04s   | +15.4%                             | ????      |
| Binary size                                                                        | 86715656B | 86591856B | -0.14%                             | ????      |
| Binary size (Stripped)                                                             | 55070672B | 54934992B | -0.24%                             | ????      |
| Parsing mesa 10 * 100 times                                                        | 8m33.626s | 8m35.773s | +0.42%                             | ????      |
| Parsing QEMU 10 * 100 times                                                        | 8m27.328s | 5m56.167s | -29.80%                            | ????      |
| Parsing gnome-builder 10 * 100 times                                               | 3m14.213s | 2m32.249s | -21.61%                            | ????      |
| Parsing GNOME-Builder-Plugins 10 * 100 times                                       | 0m39.257s | 0m13.350s | -65.99%                            | ????      |
| Allocated during parsing mesa (Sysprof)                                            | 630MB     | 666.8MB   | +5.84%                             | ????      |
| Allocated during parsing QEMU (Sysprof)                                            | 622MB     | 514MB     | -17.36%                            | ????      |
| Allocated during parsing gnome-builder (Sysprof)                                   | 253.7MB   | 263.3MB   | +3.78%                             | ????      |
| Allocated during parsing GNOME-Builder-Plugins (Sysprof)                           | 70.0MB    | 30.2MB    | -56.86%                            | ????      |
| Allocations during parsing mesa (Sysprof)                                          | 10393258  | 9482006   | -8.77%                             | ????      |
| Allocations during parsing QEMU (Sysprof)                                          | 11976168  | 7512774   | -37.27%                            | ????      |
| Allocations during parsing gnome-builder (Sysprof)                                 | 4022854   | 3176052   | -21.05%                            | ????      |
| Allocations during parsing GNOME-Builder-Plugins (Sysprof)                         | 1497990   | 348596    | -76.73%                            | ????      |
| Peak heap memory usage during parsing mesa (Heaptrack)                             | 165.74M   | 25.93MB   | -84.36%                            | ????      |
| Peak heap memory usage during parsing QEMU (Heaptrack)                             | 209.05M   | 25.01M    | -88.03%                            | ????      |
| Peak heap memory usage during parsing gnome-builder (Heaptrack)                    | 129.73M   | 11.51M    | -91.12%                            | ????      |
| Peak heap memory usage during	parsing	GNOME-Builder-Plugins (Heaptrack)            | 113.93M   | 2.95M     | -97.41%                            | ????      |
| Memory usage of language server using mesa and rebuilding tree 70 times            | 493.9MB   | 60.7MB    | -87.71%                            | ????      |

`Parsing XYZ 10 * 100 times` was measured like this:
```
echo v1.0
time for i in {0..9}; do
	echo $i
	# Will internally parse the tree 100 times
	# Including converting to an AST and doing
	# typeanalysis/typechecking
	# => 10 * 100 = 1000 iterations
	../v1.0 --path ./meson.build >/dev/null 2>&1
done
echo v1.1
time for i in {0..9}; do
	echo $i
	../v1.1 --path ./meson.build >/dev/null 2>&1
done
```
The number of allocations and the amount of allocations was tracked using Sysprof, just using "Memory Usage" and "Track Allocations" as instruments.
The selected project will be parsed 100 times.

The peak heap memory was obtained by using heaptrack:
```
heaptrack ../v1.0 --path meson.build
heaptrack_print heaptrack.v1.0.somepid.zst | grep peak.heap
heaptrack ../v1.1 --path meson.build
heaptrack_print heaptrack.v1.1.somepid2.zst | grep peak.heap
```
Reference hardware/software:
```
Swift version 5.7.3 (swift-5.7.3-RELEASE)
Target: x86_64-unknown-linux-gnu

Fedora 37
11th Gen Intel i5-1135G7 (8) @ 4.200GHz
```
# 1.0
Initial release

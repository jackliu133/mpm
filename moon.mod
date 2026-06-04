// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "jackliu133/mpm"

version = "0.1.0"

readme = "README.mbt.md"

repository = ""

license = "Apache-2.0"

keywords = []

description = ""

preferred_target = "js"

supported_targets = "js+native"

import {
  "moonbitlang/x@0.4.45",
  "moonbitlang/async@0.19.1",
  "moonbit-community/rabbita@0.12.3",
  "moonbit-community/js-ffi@0.4.2",
}

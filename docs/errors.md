1. E4156 :extern "js" is unsupported in wasm-gc backend.
> 在 对应的 moon.pkg中添加 "{filename}.mbt":"js" . eg ：
options(
  "targets":{
    "index.mbt":"js",
    "dom.mbt":"js"
  },
)

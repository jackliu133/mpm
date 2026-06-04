1. E4156 :extern "js" is unsupported in wasm-gc backend.
> 在 对应的 moon.pkg中添加 "{filename}.mbt":"js" . eg ：
options(
  "targets":{
    "index.mbt":"js",
    "dom.mbt":"js"
  },
)
2. lsp 支持问题
> 情况一：代码存在 bug lsp 跳转失效
> 情况一：target js 但是未在 moon.mod 配置  ， 
```moon.mod 
preferred_target = "js"

supported_targets = "js+native"
```
extern “js” fn xxx lsp 跳转失效

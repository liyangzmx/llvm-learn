# 第15章验证证据

输入为 `insider-compiler-ch14-end.pdf` 的PDF26–48。源PDF的SHA256为 `fc51b66bce20a574106efca042b7e1a15b816e3ad75a0db875bcd4fe1e309faa`；原始Apple Vision OCR未修改。数学密集扫描PDF27–48共22页已经实际目视，26按OCR核对；输出两张PNG均实际目视。

源码/库来自 `/opt/llvm-project`，LLVM18.1.8，commit `3b5b5c1ec4a3095ab096dd780e84d7ab81f3d7ff`。实际使用AppleClang17和项目已有MLIR静态库，未新增大型依赖。原书参考LLVM20，本次库测试不声称是20版行为。

在仓库根目录复现：

```sh
python3 mlir/insider-compiler/issues/evidence/ch15/check_math.py
python3 mlir/insider-compiler/issues/evidence/ch15/draw_geometry.py
cmake -S mlir/insider-compiler/issues/evidence/ch15 -B /private/tmp/insider-ch15-build -DMLIR_DIR=/opt/llvm-project/build/lib/cmake/mlir
cmake --build /private/tmp/insider-ch15-build -j 2
/private/tmp/insider-ch15-build/ch15-check > mlir/insider-compiler/issues/evidence/ch15/library-results.txt
```

`check_math.py`仅需Python标准库；`draw_geometry.py`生成SVG并调用本机已有 `rsvg-convert` 生成PNG。SVG是明确坐标的科学示意图，不是生成式图像。生成图的五个顶点由所有两直线交点中筛选可行点得到，横纵比例一致。

- `math-results.json`：高斯中间矩阵、FME每步完整约束及回代点、比较/除法/量词内部规范化检查数量。有限域穷举验证例子和转写，普遍正确性仍依赖正文代数论证。
- `geometry-results.json`：全部五条不等式、完整可行域顶点、最优点与最优值。
- `library-results.txt`：真实MLIR库的8项断言结果；对不可整的有理点、有理/整数字典序接口和反向冗余做了有区分力的检查。
- `independent-math-review.md`：独立代理的三轮单纯形/基逆/对偶证书、7节点B&B、25点整数枚举、267个正式表格单元的检查与哈希。可按文中说明提取唯一Python围栏复跑。本轮主代理直接复用此证据，没有把重复执行当成额外覆盖。

未运行通用性能评测、完整符号参数分区测试或完整Barvinok计数器。没有声称一般整数规划存在多项式时间算法。仅原书所引 `barvinok: User Guide` 的2024具体版号尚未核实，正文保留原日期标识并在章校订记录说明。根代理统一保存Mermaid、KaTeX及全书结构校验，本目录不另行生成一套相互冲突的总报告。

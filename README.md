# shang

## 毕设思路：filtfilt 算法到硬件实现

### 1) 先在 MATLAB 侧跑通并对齐结果

- 现有项目已用 `filtfilt` 实现低通滤波（参考 `low_power_filter.m`）。
- 典型调用：

```matlab
out_profile = low_pass_filter(out_profile, 4, 10, 1);
```

- 建议先在 MATLAB 中固定以下内容并导出：
  - 输入序列（68 点）
  - `filtfilt` 输出序列
  - 中间量（可选：前向 filter 输出、反向 filter 输出）
- 目标：后续 C/硬件结果与 MATLAB 的误差可量化（max abs err / RMSE）。

---

### 2) 算法拆解（软件）

`filtfilt` 可拆解为：

1. 前向一次 IIR 滤波（`filter_iir`）
2. 序列反转
3. 再做一次 IIR 滤波
4. 再次反转得到最终输出
5. 配合初始状态 `zi` 与边界处理（移位/补偿）

> 在本项目条件下，滤波器阶数和参数固定，因此不需要在线设计滤波器，可直接固化常量。

固定参数如下（double）：

```c
double a[5] = {1, -2.369513007182036, 2.313988414415877, -1.054665405878565, 0.187379492368184};
double b[5] = {0.004824343357716, 0.019297373430865, 0.028946060146297, 0.019297373430865, 0.004824343357716};
double zi[4] = {0.9951756566422711, -1.3936347239705993, 0.8914076302989508, -0.1825551490104656};
```

---

### 3) C 语言实现建议（用于对标 MATLAB）

建议按以下模块拆分：

- `filter_iir_fixed()`：固定 4 阶 IIR（a0=1）
- `reverse_inplace()`：68 点原地反转
- `filtfilt_fixed_68()`：两次 `filter_iir_fixed` + 两次反转 + 初始状态处理
- `compare_with_matlab()`：读取 `输入输出序列.txt`，输出误差统计

验证指标：

- `max_abs_error < 1e-9`（double 参考目标）
- 或按工程可接受阈值设定

---

### 4) 硬件实现（IIR 固定系数）

硬件中直接固化系数（示例写法）：

```verilog
// a0 always 1.0
wire [inst_sig_width+inst_exp_width:0] a1_neg = $shortrealtobits(2.369513007182036);
wire [inst_sig_width+inst_exp_width:0] a2_neg = $shortrealtobits(-2.313988414415877);
wire [inst_sig_width+inst_exp_width:0] a3_neg = $shortrealtobits(1.054665405878565);
wire [inst_sig_width+inst_exp_width:0] a4_neg = $shortrealtobits(-0.187379492368184);

wire [inst_sig_width+inst_exp_width:0] b0 = $shortrealtobits(0.004824343357716);
wire [inst_sig_width+inst_exp_width:0] b1 = $shortrealtobits(0.019297373430865);
wire [inst_sig_width+inst_exp_width:0] b2 = $shortrealtobits(0.028946060146297);
wire [inst_sig_width+inst_exp_width:0] b3 = $shortrealtobits(0.019297373430865);
wire [inst_sig_width+inst_exp_width:0] b4 = $shortrealtobits(0.004824343357716);

wire [inst_sig_width+inst_exp_width:0] z0 = $shortrealtobits(0.9951756566422711);
wire [inst_sig_width+inst_exp_width:0] z1 = $shortrealtobits(-1.39363472397059933);
wire [inst_sig_width+inst_exp_width:0] z2 = $shortrealtobits(0.8914076302989508);
wire [inst_sig_width+inst_exp_width:0] z3 = $shortrealtobits(-0.1825551490104656);
```

---

### 5) 硬件实现 `FiltFilt` 顶层建议

- 一次性输入 68 点数据（可 RAM 缓存）
- 用 FSM 串联流程：
  1. Load input
  2. Forward IIR
  3. Reverse buffer
  4. Backward IIR
  5. Reverse buffer
  6. Output compare/log

建议状态机：`IDLE -> LOAD -> IIR_FWD -> REV1 -> IIR_BWD -> REV2 -> DONE`

测试数据：

- `输入输出序列.txt`（黄金输入/输出）

---

### 6) 论文/答辩可讲亮点

- `filtfilt` 的零相位特性来源（前后向滤波）
- 固定系数带来的硬件简化：
  - 无需在线求系数
  - 无需动态计算 `zi`
- 资源与精度折中：
  - 浮点实现 vs 定点实现
  - 不同位宽下误差与 LUT/DSP 消耗对比


## 代码实现

- C 实现位于 `src/filtfilt_fixed.c` / `src/filtfilt_fixed.h`。
- Demo 程序位于 `src/main.c`，可通过 `make` 编译运行。


### Makefile 这个文件是做什么的？

`Makefile` 不是文件夹，它是 **构建脚本文件**。作用是把编译命令统一管理，避免每次手写很长的 `cc ...` 命令。

本项目中它主要提供两个目标：

- `make`：编译生成可执行程序 `filtfilt_demo`
- `make clean`：删除编译产物 `filtfilt_demo`

对应规则见 `Makefile`：

- 第 1~2 行：编译器与编译参数（开启 `-Wall -Wextra -Werror`）
- 第 4 行：默认目标 `all`
- 第 6~7 行：如何把 `src/main.c` 与 `src/filtfilt_fixed.c` 链接成 `filtfilt_demo`
- 第 9~10 行：清理目标

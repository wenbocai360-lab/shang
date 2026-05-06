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


### 如何使用这个工程（快速上手）

1. 编译：

```bash
make
```

2. 运行 demo：

```bash
./filtfilt_demo
```

运行后会输出 68 行 `索引,滤波值`（CSV 形式），例如：

```text
0,0.900731251183885
1,1.314300976585985
```

3. 清理编译产物：

```bash
make clean
```

4. 若你要替换为自己的 68 点输入：

- 打开 `src/main.c`
- 把 `in[i] = (double)i;` 改成你的输入数据来源（如数组/文件读入）
- 重新 `make && ./filtfilt_demo`

5. 若要与 MATLAB 对比：

- MATLAB 导出同一组 68 点输入的 `filtfilt` 输出（double 精度）
- 在 C 侧读取该输出作为参考值，调用 `max_abs_error()` 统计最大绝对误差


### Verilog 代码生成（硬件版）

- `rtl/iir4_fixed.v`：固定系数四阶 IIR（Q8.24）。
- `rtl/filtfilt68_top.v`：68 点批处理 `filtfilt` 顶层 FSM（LOAD -> FWD -> REV1 -> BWD -> REV2OUT）。
- 使用方式：在 testbench 中按 `start/in_valid/in_data` 灌入 68 点，等待 `done`，在 `out_valid` 时采样输出。


### 硬件实现需要写哪些模块（建议清单）

建议至少拆成下面 8 个模块：

1. **顶层控制模块 `filtfilt68_top`**
   - 负责流程控制（LOAD -> FWD -> REV1 -> BWD -> REV2OUT）
   - 对外提供 `start/in_valid/in_data/in_ready/out_valid/out_data/done` 接口

2. **IIR 计算核心 `iir4_fixed`**
   - 4 阶固定系数 IIR（Direct Form II Transposed）
   - 输入 1 点、输出 1 点，内部维护 `z0~z3`

3. **系数/初值常量模块 `coeff_rom`（可选）**
   - 存 `a/b/zi`，便于后期改位宽或切换滤波器
   - 系数固定时也可直接写在 `iir4_fixed` 内部

4. **输入缓存模块 `input_buffer`**
   - 存 68 点输入（可用单口 RAM 或寄存器阵列）
   - 支持按顺序读出给前向 IIR

5. **中间缓存模块 `work_buffer`**
   - 保存前向滤波结果与反向滤波中间结果
   - 通常和输入缓存分开，减少读写冲突

6. **反转地址发生器 `reverse_addr_gen`**
   - 负责 `0..67` 与 `67..0` 地址映射
   - 减少“整块搬移”逻辑，直接用反向地址读写

7. **输出缓冲与接口模块 `output_buffer`**
   - 缓存最终 68 点结果
   - 统一对外输出节拍与 `out_valid` 握手

8. **验证/对比模块 `tb + golden_checker`（仿真侧）**
   - testbench 读入输入向量与 MATLAB 黄金输出
   - 自动比较误差并打印最大绝对误差

> 最小可运行版本：`filtfilt68_top + iir4_fixed + 双端口RAM(或寄存器数组)` 就能跑通；
> 为了工程可维护性，建议把地址反转、缓存和比对逻辑独立成模块。


### 是否必须写 8 个模块？

不是“必须”。8 个模块是**工程化推荐拆分**，不是硬性要求。你可以按两阶段推进：

- **最小可运行版（先过功能）**：
  - `iir4_fixed`
  - `filtfilt68_top`
  - RAM/寄存器数组（可先内嵌在 top）

- **课程设计/答辩版（更规范）**：
  - 再把 `reverse_addr_gen / input_buffer / work_buffer / output_buffer / coeff_rom / golden_checker` 拆出去

这样可以先保证“能跑通 + 能对比”，再做结构优化。

### Quartus 里如何落地（从建工程到验收）

1. **建工程**
   - Quartus -> New Project Wizard
   - 选择 FPGA 型号（按你的开发板，如 Cyclone IV/V）
   - 加入 RTL 文件：`rtl/iir4_fixed.v`、`rtl/filtfilt68_top.v`

2. **设置顶层与时钟**
   - 将 `filtfilt68_top` 设为 Top-Level Entity
   - 用板卡主时钟（例如 50MHz）作为 `clk`
   - `rst_n` 接按键或上电复位逻辑

3. **引脚分配（Pin Planner）**
   - 给 `clk/rst_n/start/in_valid/in_data/out_valid/out_data/done` 分配管脚
   - 若 `in_data/out_data` 位宽较大，建议先用 testbench 验证；上板时可改成 FIFO/UART 接口

4. **先做功能仿真（强烈建议）**
   - ModelSim/Questa 联合仿真
   - testbench 流程：
     1) 拉高 `start`
     2) 连续 68 拍送 `in_valid=1` + `in_data`
     3) 等 `done`
     4) 在 `out_valid` 时采样 68 点输出
   - 将输出与 MATLAB 黄金数据对比（最大绝对误差）

5. **综合与时序**
   - 运行 Analysis & Synthesis、Fitter、TimeQuest
   - 检查：
     - 是否有时序违例（Setup/Hold）
     - DSP、ALM、RAM 资源是否在板卡预算内

6. **下载上板与联调**
   - Programmer 下载 `.sof`
   - 用 SignalTap 抓关键信号：`state/rd_ptr/wr_ptr/out_valid/out_data/done`
   - 若输出接口是 UART/FIFO，可回传到 PC 与 MATLAB 再比一次

### 建议的“最终实现要求”（可写进毕设验收指标）

- **功能正确性**：
  - 对固定 68 点测试向量，硬件输出与 MATLAB `filtfilt` 对齐
- **精度指标**：
  - 给出 `max_abs_error`（例如 <= 1e-3，按定点位宽可调整）
- **性能指标**：
  - 给出总延迟（从 start 到 done 的时钟周期）
  - 给出吞吐率（每 68 点一帧的处理时间）
- **资源指标**：
  - DSP/ALM/RAM 使用率
- **工程指标**：
  - 提供 testbench + 黄金向量 + 自动比对脚本

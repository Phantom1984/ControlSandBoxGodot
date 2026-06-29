# 系统辨识系列文档

本系列文档记录 ControlSandBox 项目中系统辨识模块的理论与实践，按"理论先行、项目落地"的方式组织，便于后续复习沉淀。

## 文档目录

| 序号 | 标题 | 内容要点 |
|------|------|---------|
| 01 | [频域辨识原理](./01_频域辨识原理.md) | 频率响应、H1/H2/Hv 估计、相干函数 |
| 02 | [Welch 法](./02_Welch法.md) | 功率谱估计、分段加窗、分辨率-方差权衡 |
| 03 | [激励信号设计](./03_激励信号设计.md) | 步进正弦、Chirp、PRBS、多正弦对比 |
| 04 | [实践：扫频辨识倒立摆](./04_实践_扫频辨识倒立摆.md) | 闭环辨识实操流程与结果分析 |
| 05 | [时域辨识（ARX）](./05_时域辨识_ARX.md) | 最小二乘、ARX/ARMAX、阶次确定（阶段2） |

## 推荐阅读顺序

理论先行：`01 → 02 → 03`（理论三角），然后 `04`（项目实践），最后 `05`（参数化扩展）。

## 整体流程

```
激励信号 u(t) ──► Plant ──► y(t)
                    │
                    ▼
            DataRecorder 录制完整 u-y 序列
                    │
                    ▼
            Welch 法估计 Sxx / Syy / Sxy
                    │
                    ▼
            H1 传递函数估计 + 相干函数 γ²
                    │
                    ▼
            Bode 图（幅频/相频）+ 相干图
                    │
                    ▼
            模型拟合（可选）+ 验证
```

## 与项目代码的对应关系

| 文档 | 对应代码（计划） |
|------|-----------------|
| 01 | `scripts/identification/freq_tf_estimator.gd` |
| 02 | `scripts/identification/welch_psd.gd` |
| 03 | `scripts/identification/excitation/*.gd` |
| 04 | 实操流程，无对应单文件 |
| 05 | `scripts/identification/arx_identifier.gd` |

## 共用基础

- `scripts/linalg/FFT.gd`：Cooley-Tukey 蝶形 FFT
- `scripts/linalg/Window.gd`：Hann / Hamming / Blackman 窗函数
- `scripts/linalg/Matrix.gd`：阶段 2 补齐（求逆、解方程）

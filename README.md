# ControlSandBox

一个基于 Godot 物理引擎的控制算法沙盒，用于在真实物理仿真环境下设计、调试和验证控制器，并支持通过系统辨识从实验数据估计被控对象的频率响应。适合控制理论教学与算法原型验证。

## 功能特性

### 控制器
- **PID 控制器**：带积分限幅（抗积分饱和）、微分项基于测量值（避免微分冲击）、输出限幅
- **串级控制器**：`CascadeController` 容器，把外环输出注入内环设定值，构成双环控制
- **LQR 控制器**：线性二次调节器框架，控制律 `u = -Kx` 已就绪；状态方程线性化与 Riccati 求解为 TODO 占位，待补齐
- **直通控制器**：`PassThroughController`，开环辨识专用，直接将激励信号作为控制量输出
- **双环控制**：倒立摆场景支持单环（摆角）/双环（摆角 + 位置）切换

### 仿真场景
- **小车控制**：一维滑块位置跟踪，验证 PID 在不同扰动下的响应
- **倒立摆控制**：经典的 cart-pole 系统，支持初始角度设置与控制模式切换
- **系统辨识**：独立的辨识实验场景，支持扫频辨识与频率响应估计

### 环境与扰动
- 地面摩擦（库仑摩擦）
- 空气阻力（与速度成正比）
- 周期性正弦扰动（可调幅度与频率）
- 瞬时脉冲冲量干扰

### 系统辨识
- **激励信号**：Chirp 线性扫频、Stepped Sine 步进正弦、PRBS 伪随机二进制序列
- **谱估计**：基于 Cooley-Tukey FFT 的 Welch 法，输出 Sxx / Syy / Sxy
- **频率响应估计**：H1 / H2 估计 + 相干函数 γ²
- **Bode 图**：`FrequencyPlotter` 绘制幅频 / 相频 / 相干曲线
- **实验状态机**：`IdentificationExperiment` 管理 IDLE / RUNNING / ANALYZING / DONE / ERROR 全流程

### 数据采集与可视化
- 实时多曲线示波器，支持位置 / 速度 / 加速度 / 控制力等变量勾选
- 自适应坐标刻度、网格、图例
- 鼠标悬停查看任意时刻数值

### 交互调试
- 滑动条 + 数值框双向同步调参
- 停止 / 继续 / 复位一键操作
- 复位时自动恢复初始参数与状态

## 技术栈

- **引擎**：Godot 4.6（Forward+ 渲染）
- **物理**：Jolt Physics（3D）/ 内置 2D 物理
- **语言**：GDScript

## 项目结构

```
.
├── scenes/                            # 场景文件
│   ├── main_menu.tscn                 # 主菜单
│   ├── cart.tscn                      # 小车控制场景
│   ├── inverted_pendulum.tscn         # 倒立摆场景
│   └── identification_panel.tscn      # 系统辨识场景
├── scripts/
│   ├── plants/                        # 被控对象
│   │   ├── plant.gd                   # 被控对象基类
│   │   ├── cart.gd                    # 小车（单 PID 位置控制）
│   │   └── pendulum_controller.gd     # 一阶倒立摆
│   ├── controllers/                   # 控制器
│   │   ├── controller_base.gd         # 控制器基类
│   │   ├── pid_controller.gd          # PID 控制器
│   │   ├── cascade_controller.gd      # 串级控制器容器
│   │   └── lqr_controller.gd          # LQR 框架（待完善）
│   ├── ui/                            # 界面与菜单
│   │   ├── main_menu.gd / back_mainmenu.gd
│   │   ├── pid_panel.gd / pendulum_pid_panel.gd
│   │   ├── env_panel.gd / var_panel.gd
│   ├── data/                          # 数据采集与绘图
│   │   ├── data_bridge.gd / pendulum_data_bridge.gd
│   │   ├── data_monitor.gd / plotter.gd
│   └── identification/                # 系统辨识模块
│       ├── signals/                   # 激励信号
│       │   ├── excitation_base.gd / chirp_signal.gd
│       │   ├── stepped_sine.gd / prbs_signal.gd
│       ├── estimators/                # 估计算法
│       │   ├── fft.gd / welch_estimator.gd / data_acquirer.gd
│       ├── pass_through_controller.gd # 直通控制器（开环辨识）
│       ├── frequency_plotter.gd       # Bode 图绘制
│       ├── identification_experiment.gd  # 辨识实验状态机
│       └── identification_panel.gd    # 辨识 UI 面板
├── docs/
│   ├── 设计构想.md                     # 设计文档与路线图
│   └── system_identification/         # 系统辨识系列文档（5 篇）
├── project.godot                      # 引擎配置
└── README.md
```

## 快速开始

### 环境要求
- Godot Engine 4.6 或更高版本

### 运行
1. 用 Godot 打开本项目目录
2. 直接运行（F5），从主菜单选择场景进入

### 基本操作
1. **选择场景**：主菜单中选择「小车控制」「倒立摆」或「系统辨识」
2. **调参**：拖动滑动条或在数值框中输入，实时生效
3. **设置目标**：调整目标位置滑动条，观察跟踪响应
4. **施加扰动**：在环境面板中调节摩擦、阻力、周期扰动，或输入冲量施加脉冲
5. **监控数据**：在变量面板勾选需要观测的量，示波器实时绘制
6. **系统辨识**：进入辨识场景，选择激励信号与参数，点击「开始辨识」，完成后查看 Bode 图与相干函数
7. **停止 / 复位**：随时停止仿真或复位到初始状态

## 设计文档

- 详细的设计构想与后续规划见 [设计构想.md](docs/设计构想.md)
- 系统辨识理论与实操文档见 [docs/system_identification/](docs/system_identification/README.md)

## 许可证

本项目仅供学习与交流使用。

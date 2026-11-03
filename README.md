# 基于 FPGA 的实时图像处理系统

2026 年全国大学生嵌入式芯片与系统设计竞赛 FPGA 创新设计赛道作品(题目:实时图像处理)。

## 平台
- FPGA:安路 PH1P35MDG324(DDR2 帧存)
- 摄像头:SC500CS,MIPI CSI-2,1920×1080 输出
- 显示:HDMI 1920×1080,像素时钟 75 MHz(约 30 帧/秒)
- 开发工具:Anlogic TD 2026.2

## 功能
共 8 种显示模式,BTN0 循环切换,切换在场同步处生效:
| 模式 | 功能 | BTN1 |
|---|---|---|
| 0 | 原图 | 直方图均衡开/关 |
| 1 | 灰度 | 分屏:左原图,右灰度伪彩色 |
| 2 | Sobel 边缘检测 | 分屏对比 |
| 3 | 区域填充 | — |
| 4 | 颜色目标跟踪(红/绿/蓝/黄),外接框、中心坐标、形状(矩形/圆/三角形)与置信度,LED 指示左/中/右 | 切换目标颜色 |
| 5 | 二值化 | 分屏对比 |
| 6 | 反色 | 分屏对比 |
| 7 | 运动检测(块平均灰度帧差) | — |

另有水平锐化、对焦清晰度条、处理延迟测量、数字自动增益、屏幕信息显示(OSD)。

## 目录
- `user_source/hdl_source`:Verilog 源码(顶层 `design_top_wrapper.v`;目标跟踪与叠加在 `target_track.v`)
- `user_source/constraints_source`:引脚约束 `pin.adc`
- `user_source/ip_source`:IP 配置
- `td_project`:TD 工程文件 `camera_to_dsi_display.al`
- `bitstream/camera_to_dsi_display.bit`:本版本综合布线后生成的比特流

## 使用
1. 用 TD 2026.2 打开 `td_project/camera_to_dsi_display.al`,运行综合与布局布线,生成比特流;或直接下载 `bitstream/camera_to_dsi_display.bit`。
2. 开发板接好摄像头和 HDMI 显示器,上电后按 BTN0 切换模式。
3. 目标跟踪演示:摄像头先对着中性色背景稳定几秒,再切到模式 4(此模式锁定白平衡),BTN1 选颜色。

## 资源与时序(本版本)
LUT 16239/21216(76.54%),DSP 18,片上 RAM 52,建立时间裕量 +0.466 ns,保持时间裕量 +0.020 ns。

## 说明
- 工程基于安路提供的 MIPI/HDMI 示例工程扩展,其中 `hdmi_1_4b_transmitter_core_wrapper.enc.v` 等为厂商 IP。
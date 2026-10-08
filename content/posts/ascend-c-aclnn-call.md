---
title: "Ascend C 算子开发：工程生成、部署与 ACLNN 调用接入"
date: 2026-10-08T16:00:00+08:00
draft: false
tags: ["Ascend C", "ACLNN", "自定义算子"]
categories: ["Ascend C 算子开发"]
summary: "以 add_custom 为例，记录使用 msopgen 生成算子工程、理解目录结构，以及编译安装后接入调用方的流程。"
description: "从 msopgen 工程生成到 .run 包安装，整理自定义算子接入 ACLNN 调用链路的准备步骤。"
showtoc: true
tocopen: true
---

以 `add_custom` 为例，记录自定义算子从工程生成、编译部署到调用方接入的过程。

## 1. 使用 msopgen 生成算子工程

```bash
msopgen gen -i ./add_custom.json -lan cpp -out ./
```

其中，`add_custom.json` 为算子原型定义文件，用来描述输入、输出的张量格式、数据类型等。

## 2. 了解工程目录结构

执行命令后，会在当前文件夹下生成对应的算子工程。

![msopgen 生成的算子工程目录结构](/images/ascend-c/operator-project.png)

主要目录和文件的作用如下：

| 目录 / 文件 | 作用 |
| --- | --- |
| `op_host` | 算子的 Host 侧代码，包含算子原型注册、Tiling 实现、Shape 与 Dtype 推导，以及 Host 侧的 `CMakeLists.txt`。 |
| `op_kernel` | 算子实现，包含 Tiling 定义、算子实现，以及 Device 侧的 `CMakeLists.txt`。 |
| `build.sh` | 工程编译脚本。 |
| `CMakeLists.txt` | 工程编译文件。 |
| `CMakePresets.json` | 工程编译配置文件。 |

## 3. 编译与安装算子

`msopgen` 已经搭建好了算子工程框架。完成编译后，会生成对应的 `.run` 部署包；使用该包部署到指定目录，即可完成算子的安装。

安装命令示例：

```bash
add_custom_template.run --install-path=./.local
```

## 4. 将安装路径接入调用链路

安装完成后，将安装路径加入调用方的引用链路中。

![左侧为算子安装后的目录，右侧为调用方引入安装路径的配置](/images/ascend-c/operator-call-path.png)

上图左侧为安装完成后的路径，右侧为调用方引入该路径的示例。

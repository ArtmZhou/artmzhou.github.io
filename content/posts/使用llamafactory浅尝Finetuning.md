---
title: "使用llamafactory浅尝Finetuning"
date: 2026-04-19T15:56:16+08:00
draft: false
tags: ['finetuning']
categories: []
summary: ""
---
# 安装llamafactory
本文介绍再自己的windows机器上安装使用

1. 现在mircosoft商城安装好ubuntu
   ![unbuntu安装](/images/dab77ca5-325d-46f2-82e5-af06fab257ce.png)
2. 使用`wsl`进入ubuntu，最好在d盘下创建一个自己的workspace后进入，这样wsl会自动帮你mnt到linux环境中
3. 下载llamafactory
   ```shell
   git clone https://github.com/hiyouga/LlamaFactory.git
   ```
   下载的工程中有各类微调方法的配置文件，数据集配置文件等
4. 配置项目venv虚拟环境，安装好所需依赖（提前安装好python，pip, uv等工具）
   ```shell
   cd LlamaFactory
   python3 -m venv ~/myvenv
   source ~/myvenv/bin/activate
   uv pip install -e ".[torch,metrics]" -i https://mirrors.aliyun.com/pypi/simple
   # 验证
   llamafactory-cli version
   ```
   上述安装如果存在问题，建议复制错误去问deepseek/qwen
   本人第一次安装时也出现了一些问题，比如ubuntu中的python环境受到了保护，安装uv失败；比如wsl路径问题，这些都可以复制报错信息去问大模型，给出解决方案。

   验证一下本机的nvidia驱动以及cuda可用性
   ```shell
   # 执行以下命令会输出nvidia显卡驱动的基本信息
   nvidia-smi
   # ok的话会返回True，如果有问题，请自行升级nvidia驱动后再尝试
   python3 -c "import torch;print(torch.cuda.is_available())"
   ```

# 执行微调
准备工作就绪之后，就可以使用`llamafactory-cli`执行微调尝试了

1. 下载模型
   ```shell
   uv pip install modelscope -i https://mirrors.aliyun.com/pypi/simple
   modelscope download --model Qwen/Qwen3-0.6B --local_dir /mnt/d/ubuntu/models/Qwen3-0.6B
   ```
   这里使用魔塔提供的工具进行下载，如果要换模型可以去他们官网查看https://www.modelscope.cn/
   当然你也可以去hugging face下载，不过需要有机场。

   下载的路径推荐放在wsl的挂载路径中，这样我们可以在windows中进行查看，这里我放在了d盘下`/d/ubuntu/models/Qwen3-0.6B`
   ![alt text](/images/image.png)

   
2. 修改配置文件
   
   配置文件在llamfactory工程的`example`文件夹中有示例，里面包含了各类的微调方法的配置文件示例
   ![alt text](/images/image11.png)

   我们使用lora相关的配置文件初次尝试一下，只修改模型配置文件即可，其他配置不动，微调的数据集在llamafactory的`data`目录中有

   ![alt text](/images/image22.png)


3. 执行训练
   
   ```shell
   llamafactory-cli train examples/train_lora/qwen3_lora_sft.yaml
   ```
   执行完后可以查看已经开始加载并进行训练
   ![alt text](/images/image-0.png)
   ![alt text](/images/image-1.png)

   配置文件中同样声明了训练完成的输出目录在哪，没有修改的话，可以在`save`目录中看到
   ![alt text](/images/training_loss.png)


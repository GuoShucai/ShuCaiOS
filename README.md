# 蔬菜OS/ShuCaiOS
一个简单的命令行式操作系统，仅支持几个基础功能，包括：
1. 显示欢迎/帮助/系统信息
2. 简单命令参数解析
3. 清屏
4. 重启/关机
5. 内置了一个简单的BrainFuck解释器
注：
1. 此系统是个人用来学习FASM汇编和操作系统的相关知识的，仅供学习和娱乐，没有任何实用价值。
2. 16位系统（boot.asm、kernel.asm）在实模式下运行，系统较稳定，但后续开发时将会被废弃。
3. 32位系统（boot32.asm、kernel32.asm）在32位保护模式下运行，目前并不能完全实现16位版本的功能，有待后续优化。

A simple command-line operating system that only supports a few basic features, including:
1. Display welcome/help/system information
2. Simple command parameter parsing
3. Clear screen
4. Restart/Shutdown
5. Built in a simple BrainFuck interpreter
Note:
1. This system is intended for personal learning of FASM assembly and operating system related knowledge, for learning and entertainment purposes only, and has no practical value.
2. The 16-bit system (boot.asm, kernel.asm) runs in real mode and is relatively stable, but it will be abandoned during subsequent development.
3. 32-bit systems (boot32.asm, kernel32.asm) run in 32-bit protected mode and currently cannot fully implement the functionality of the 16-bit version, requiring further optimization.

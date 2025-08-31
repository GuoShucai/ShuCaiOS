format binary as 'img'
org 0x7C00
use16

start:
    ; 初始化段寄存器
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; 显示加载消息
    mov si, loading_msg
    call print_16

    ; 加载内核到0x10000 (64KB处)
    mov ah, 0x02
    mov al, 20        ; 读取20个扇区 (10KB)
    mov ch, 0         ; 柱面号0
    mov cl, 2         ; 从扇区2开始 (扇区1是引导扇区)
    mov dh, 0         ; 磁头0
    mov bx, 0x1000    ; ES:BX = 0000:1000 (物理地址0x10000)
    mov es, bx
    xor bx, bx
    int 0x13
    jc disk_error
    
    ; 检查实际读取的扇区数
    cmp al, 20
    jne disk_error

    ; 准备切换到保护模式
    cli               ; 禁用中断
    lgdt [gdt_descriptor] ; 加载GDT
    
    ; 启用A20线 (使用更可靠的方法)
    call enable_a20
    
    ; 设置保护模式标志
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    ; 远跳转到保护模式代码
    jmp 0x08:protected_mode
    
enable_a20:
    ; 通过键盘控制器启用A20
    call .wait_input
    mov al, 0xAD      ; 禁用键盘
    out 0x64, al
    
    call .wait_input
    mov al, 0xD0      ; 读取输出端口
    out 0x64, al
    
    call .wait_output
    in al, 0x60       ; 获取输出端口值
    push eax
    
    call .wait_input
    mov al, 0xD1      ; 写入输出端口
    out 0x64, al
    
    call .wait_input
    pop eax
    or al, 2          ; 设置A20位
    out 0x60, al
    
    call .wait_input
    mov al, 0xAE      ; 启用键盘
    out 0x64, al
    
    call .wait_input
    ret

.wait_input:
    in al, 0x64
    test al, 2
    jnz .wait_input
    ret

.wait_output:
    in al, 0x64
    test al, 1
    jz .wait_output
    ret

print_16:
    pusha
    mov ah, 0x0E
.loop:
    lodsb
    test al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    popa
    ret

disk_error:
    mov si, err_msg
    call print_16
    ; 挂起系统
    cli
    hlt
    jmp $

; GDT定义 (使用平坦模型)
gdt_start:
    ; 空描述符
    dq 0
    
    ; 代码段描述符 (基地址0, 限制4GB)
    dw 0xFFFF       ; 限制 0-15
    dw 0x0000       ; 基地址 0-15
    db 0x00         ; 基地址 16-23
    db 0x9A         ; 访问字节 (P=1, DPL=00, S=1, EX=1, DC=0, RW=1, AC=0) [值0b10011010]
    db 0xCF         ; 标志 + 限制 16-19 (G=1, D/B=1, L=0, AVL=0, 限制16-19=0xF) [值0b11001111]
    db 0x00         ; 基地址 24-31
    
    ; 数据段描述符 (基地址0, 限制4GB)
    dw 0xFFFF       ; 限制 0-15
    dw 0x0000       ; 基地址 0-15
    db 0x00         ; 基地址 16-23
    db 0x92         ; 访问字节 (P=1, DPL=00, S=1, EX=0, DC=0, RW=1, AC=0) [值0b10010010]
    db 0xCF         ; 标志 + 限制 16-19 [值0b11001111]
    db 0x00         ; 基地址 24-31
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; GDT大小
    dd gdt_start                ; GDT地址

loading_msg db "Loading OS...", 0
err_msg db "Disk error! Press Ctrl+Alt+Del to restart", 0

; 填充引导扇区
times 510-($-$$) db 0
dw 0xAA55

use32
protected_mode:
    ; 设置段寄存器
    mov ax, 0x10    ; 数据段选择子
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x9FFFF ; 设置栈指针 (640KB处)
    
    ; 跳转到内核 (0x10000)
    jmp 0x08:0x10000
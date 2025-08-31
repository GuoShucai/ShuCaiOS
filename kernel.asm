format binary as 'img'
org 0x8000
use16

start:
    ; 设置段寄存器
    mov ax, cs
    mov ds, ax
    mov es, ax

    ; 设置栈指针
    mov ss, ax
    mov sp, 0xFFFF  ; 栈顶在段末尾

    ; 初始化显示
    call clear_screen
    call display_welcome
    
    ; 主命令行循环
    cli_loop:
        call display_prompt
        call read_command
        call process_command
        jmp cli_loop

; ==== 功能函数 ====

; 清屏函数
clear_screen:
    mov ax, 0x0600  ; AH=06h(滚动), AL=00h(全屏)
    mov bh, 0x07    ; 属性(黑底白字)
    xor cx, cx      ; CH=0,CL=0(左上角)
    mov dx, 0x184F  ; DH=24,DL=79(右下角)
    int 0x10
    mov dx, 0x0000
    call set_cursor  ; 确保光标回到左上角
    ret

; 设置光标位置
; 输入: DH=行, DL=列
set_cursor:
    mov ah, 0x02
    mov bh, 0       ; 第0页
    int 0x10
    ret

; 获取光标位置
; 输出: DH=行, DL=列
get_cursor:
    mov ah, 0x03
    mov bh, 0
    int 0x10
    ret

; 打印字符串
; 输入: SI=字符串地址
print_string:
    push ax
    push si
    
    .print_loop:
        lodsb           ; 加载AL中的字节并增加SI
        or al, al       ; 检测是否到字符串结尾(0)
        jz .done
        mov ah, 0x0E    ; BIOS打印字符功能
        int 0x10
        jmp .print_loop
    .done:
    
    pop si
    pop ax
    ret

; 打印换行
print_newline:
    push ax
    mov ah, 0x0E
    mov al, 13     ; 回车
    int 0x10
    mov al, 10     ; 换行
    int 0x10
    pop ax
    ret

; 显示欢迎消息
display_welcome:
    mov si, welcome_msg
    call print_string
    call print_newline
    ret

; 显示提示符
display_prompt:
    mov si, prompt
    call print_string
    ret

; 读取命令
read_command:
    ; 清零命令缓冲区
    mov al, 0
    mov di, command_buffer
    mov cx, COMMAND_MAX_LEN+1
    rep stosb
    
    ; 清零参数缓冲区
    mov di, arg1
    mov cx, (ARG_MAX_LEN+1)*3
    rep stosb

    mov di, command_buffer  ; 命令缓冲区
    mov cx, 0               ; 字符计数器
    
    .read_char:
        ; 获取键盘输入
        mov ah, 0x00
        int 0x16
        
        ; 处理回车键
        cmp al, 13
        je .command_done
        
        ; 处理退格键
        cmp al, 8
        je .backspace
        
        ; 处理普通字符
        cmp cx, COMMAND_MAX_LEN
        jae .read_char      ; 缓冲区满，忽略输入
        
        ; 回显字符
        mov ah, 0x0E
        int 0x10
        
        ; 存储字符
        stosb
        inc cx
        jmp .read_char
    
    .backspace:
        cmp cx, 0
        je .read_char       ; 无字符可删除
        
        ; 移动光标并删除字符
        dec di
        dec cx
        
        ; 回显退格
        mov ah, 0x0E
        mov al, 8
        int 0x10
        mov al, ' '
        int 0x10
        mov al, 8
        int 0x10
        
        jmp .read_char
    
    .command_done:
        ; 添加字符串结束符
        mov byte [di], 0
        
        ; 换行
        call print_newline
        ret

; 处理命令
process_command:
    ; 重置参数计数器
    mov byte [arg_count], 0
    
    ; 跳过前导空格
    mov si, command_buffer
    .skip_spaces:
        lodsb
        cmp al, ' '
        je .skip_spaces
        cmp al, 0
        je .empty_command
        dec si             ; 回退到第一个非空格字符
    
    ; 查找命令结束位置
    mov di, si
    .find_end:
        lodsb
        cmp al, 0
        je .single_command
        cmp al, ' '
        je .split_command
        jmp .find_end
    
    .split_command:
        ; 分割命令和参数
        mov byte [si-1], 0 ; 替换空格为0终止命令
        
        ; 保存命令位置
        mov [current_command], di
        
        ; 处理参数
        call process_arguments
        jmp .execute_command
    
    .single_command:
        ; 无参数命令
        mov [current_command], di
        jmp .execute_command
    
    .empty_command:
        ret
    
    .execute_command:
        ; 检查命令并执行
        mov si, [current_command]
        
        ; 比较命令
        mov di, cmd_help
        call strcmp
        jc .do_help

        mov di, cmd_bf
        call strcmp
        jc .do_bf
        
        mov di, cmd_clear
        call strcmp
        jc .do_clear
        
        mov di, cmd_echo
        call strcmp
        jc .do_echo
        
        mov di, cmd_info
        call strcmp
        jc .do_info
        
        mov di, cmd_reboot
        call strcmp
        jc .do_reboot

        mov di, cmd_Na2SO4
        call strcmp
        jc .do_Na2SO4

        ; ==== 添加关机命令处理 ====
        mov di, cmd_shutdown
        call strcmp
        jc .do_shutdown
        
        ; 未知命令
        mov si, unknown_cmd_msg
        call print_string
        call print_newline
        ret
        
        ; 命令处理
        .do_help:
            mov si, help_msg
            call print_string
            call print_newline
            ret

        .do_bf:
            cmp byte [arg_count], 0
            je .bf_no_args

            mov si, arg1
            call execute_brainfuck
            ret

            .bf_no_args:
                mov si, bf_msg
                call print_string
                call print_newline
                ret
        
        .do_clear:
            call clear_screen
            ret
        
        .do_echo:
            cmp byte [arg_count], 0
            je .echo_no_args
    
            ; 循环打印所有参数
            mov cl, 0                  ; 当前参数索引
    
            .print_loop:
                ; 计算参数地址 = arg1 + (索引 * 参数大小)
                mov al, cl
                mov bl, ARG_MAX_LEN+1
                mul bl                 ; AX = AL * BL
                mov si, arg1
                add si, ax             ; SI = 参数地址
        
                ; 打印参数
                call print_string
                call print_newline
        
                ; 如果不是最后一个参数，打印空格
                inc cl
                cmp cl, [arg_count]
                jae .echo_done

                ;调试用
                ;mov al, ' '
                ;mov ah, 0x0E
                ;int 0x10
                jmp .print_loop
    
            .echo_done:
                ;call print_newline
                ret
    
            .echo_no_args:
                call print_newline  ; 空行
                ret
        
        .do_info:
            mov si, info_msg
            call print_string
            call print_newline
            ret

        .do_Na2SO4:
            mov si, Na2SO4_msg
            call print_string
            call print_newline
            ret
        
        .do_reboot:
                mov si, reboot_msg
                call print_string
                call print_newline
    
                ; 方法1: 键盘控制器重启 (首选)
                mov al, 0xFE
                out 0x64, al
    
                ; 方法2: 延迟后尝试跳转 (防止方法1执行太快)
                mov cx, 0xFFFF
                .delay_loop:
                    nop
                    loop .delay_loop
    
                ; 方法3: CPU复位向量 (最终保障)
                cli
                xor ax, ax
                mov ds, ax
                mov ss, ax
                mov sp, 0xFFF0
                jmp 0xF000:0xFFF0  ; 跳转到BIOS复位向量

        ; ==== 关机命令处理 ====
        .do_shutdown:
            call shutdown
            ; 如果关机失败，显示错误信息
            mov si, shutdown_fail_msg
            call print_string
            call print_newline
            ret

; ==== BrainFuck解释器实现 ====
execute_brainfuck:
    ; 初始化内存带 (用ES:DI指向)
    push es
    mov ax, ds
    mov es, ax
    mov di, bf_tape
    mov cx, BF_TAPE_SIZE
    xor al, al
    rep stosb
    
    ; 设置指针
    mov word [bf_data_ptr], bf_tape
    mov word [bf_code_ptr], si
    
    ; 主解释循环
    .bf_loop:
        mov si, [bf_code_ptr]
        cmp byte [si], 0
        je .bf_done
        
        ; 处理不同指令
        mov al, [si]
        cmp al, '>'
        je .ptr_inc
        cmp al, '<'
        je .ptr_dec
        cmp al, '+'
        je .cell_inc
        cmp al, '-'
        je .cell_dec
        cmp al, '.'
        je .cell_out
        cmp al, ','
        je .cell_in
        cmp al, '['
        je .loop_start
        cmp al, ']'
        je .loop_end
        jmp .next_char  ; 忽略无效字符
        
    .ptr_inc:
        inc word [bf_data_ptr]
        jmp .next_char
    .ptr_dec:
        dec word [bf_data_ptr]
        jmp .next_char
    .cell_inc:
        mov si, [bf_data_ptr]
        inc byte [si]
        jmp .next_char
    .cell_dec:
        mov si, [bf_data_ptr]
        dec byte [si]
        jmp .next_char
    .cell_out:
        mov si, [bf_data_ptr]
        mov al, [si]
        mov ah, 0x0E
        int 0x10
        jmp .next_char
    .cell_in:
        ; 简单实现：输入0
        mov si, [bf_data_ptr]
        mov byte [si], 0
        jmp .next_char
    .loop_start:
        mov si, [bf_data_ptr]
        cmp byte [si], 0
        jne .next_char
        
        ; 跳过循环，寻找匹配的]
        mov cx, 1  ; 嵌套计数
        .find_loop_end:
            inc word [bf_code_ptr]
            mov si, [bf_code_ptr]
            cmp byte [si], '['
            jne .check_close
            inc cx
        .check_close:
            cmp byte [si], ']'
            jne .next_find
            dec cx
            jz .next_char  ; 找到匹配
        .next_find:
            jmp .find_loop_end
    .loop_end:
        mov si, [bf_data_ptr]
        cmp byte [si], 0
        je .next_char
        
        ; 跳回匹配的[
        mov cx, 1  ; 嵌套计数
        .find_loop_start:
            dec word [bf_code_ptr]
            mov si, [bf_code_ptr]
            cmp byte [si], ']'
            jne .check_open
            inc cx
        .check_open:
            cmp byte [si], '['
            jne .next_find_start
            dec cx
            jz .next_char  ; 找到匹配
        .next_find_start:
            jmp .find_loop_start
    .next_char:
        inc word [bf_code_ptr]
        jmp .bf_loop
    .bf_done:
        call print_newline
        pop es
        ret

; ==== 完全修复的参数处理函数 ====
process_arguments:
    ; 重置参数计数器
    mov byte [arg_count], 0
    
    .next_arg:
        ; 跳过空格
        .skip_spaces:
            lodsb
            cmp al, ' '
            je .skip_spaces
            cmp al, 0
            je .done
            dec si          ; 回退到第一个非空格字符
        
        ; 根据arg_count选择目标缓冲区
        mov al, [arg_count]
        cmp al, 0
        je .arg1
        cmp al, 1
        je .arg2
        cmp al, 2
        je .arg3
        jmp .done   ; 最多只处理3个参数
        .arg1:
            mov di, arg1
            jmp .copy
        .arg2:
            mov di, arg2
            jmp .copy
        .arg3:
            mov di, arg3

        ; 在.copy循环中添加缓冲区长度检查
        .copy:
            mov cx, ARG_MAX_LEN  ; 最大参数长度
        .copy_loop:
            lodsb
            cmp al, ' '
            je .space_found
            cmp al, 0
            je .end_found
            stosb
            dec cx
            jz .buffer_full     ; 缓冲区满
            jmp .copy_loop

        .buffer_full:
            mov byte [di], 0    ; 确保结束符
            ; 处理缓冲区满的情况...
            
            .space_found:
                ; 参数结束，存储0并增加计数
                mov byte [di], 0
                inc byte [arg_count]
                jmp .next_arg
            .end_found:
                mov byte [di], 0
                inc byte [arg_count]
                jmp .done
    
    .done:
        ret

; 字符串比较
; 输入: SI=字符串1, DI=字符串2
; 输出: CF=1(相等), CF=0(不等)
strcmp:
    push si
    push di
    
    .compare:
        lodsb
        mov bl, [di]
        inc di
        
        cmp al, bl
        jne .not_equal
        
        test al, al
        jz .equal
        jmp .compare
    
    .equal:
        stc
        jmp .done
    
    .not_equal:
        clc
    
    .done:
        pop di
        pop si
        ret

; 字符串复制
; 输入: SI=源字符串, DI=目标缓冲区
strcpy:
    push si
    push di
    cld      ; 确保方向标志清除（向前复制）
    
    .copy_loop:
        lodsb      ; 从[SI]加载到AL，SI++
        stosb      ; 从AL存储到[DI]，DI++
        test al, al
        jnz .copy_loop
    
        pop di
        pop si
        ret

; ==== 关机函数实现 ====
shutdown:
    ; 显示关机消息
    mov si, shutdown_msg
    call print_string
    call print_newline
    
    ; 延迟让用户看到消息
    mov cx, 0xFFFF
    .delay_loop:
        nop
        loop .delay_loop
    
    ; 方法1: QEMU专用关机
    mov dx, 0x604      ; QEMU特殊端口
    mov ax, 0x2000
    out dx, ax
    
    ; 方法2: APM关机
    mov ax, 0x5301     ; APM安装检查
    xor bx, bx
    int 0x15
    jc .try_cpu_halt   ; 如果失败则跳过
    
    mov ax, 0x530E     ; 设置APM版本
    xor bx, bx
    mov cx, 0x0102     ; 版本1.2
    int 0x15
    jc .try_cpu_halt
    
    mov ax, 0x5307     ; 设置电源状态
    mov bx, 0x0001     ; 所有设备
    mov cx, 0x0003     ; 关机
    int 0x15
    
    ; 方法3: 尝试CPU停机
    .try_cpu_halt:
        cli            ; 禁用中断
        hlt            ; 停止CPU
        
        ; 如果HLT被中断，尝试循环停机
        .halt_loop:
            cli
            hlt
            jmp .halt_loop
    
    ; 如果执行到这里，说明所有关机方法都失败了
    ret

; ==== 常量定义 ====
BF_TAPE_SIZE  = 30000   ; BrainFuck内存带大小
BF_MAX_CODE   = 255     ; BrainFuck代码最大长度
COMMAND_MAX_LEN = 256    ; 指令最大长度
ARG_MAX_LEN     = 255    ; 参数最大长度
MAX_ARGS        = 3     ; 参数最大数量

; ==== 数据区 ====
welcome_msg db 'ShuCaiOS v0.3', 13, 10
            db 'By GuoShucai',13,10
            db 'Type "help" for available commands', 13, 10, 0

prompt      db '> ', 0

cmd_help     db 'help', 0
cmd_bf       db 'bf', 0
cmd_clear    db 'clear', 0
cmd_echo     db 'echo', 0
cmd_info     db 'info', 0
cmd_reboot   db 'reboot', 0
cmd_shutdown db 'shutdown', 0
cmd_Na2SO4   db 'Na2SO4', 0

help_msg    db 'Available commands:', 13, 10
            db '  help      - Show this help', 13, 10
            db '  bf <code> - Execute BrainFuck code', 13, 10
            db '  clear     - Clear the screen', 13, 10
            db '  echo      - Print arguments', 13, 10
            db '  info      - Show system information', 13, 10
            db '  reboot    - Restart the system', 13, 10
            db '  shutdown  - Power off the system', 13, 10, 0

bf_msg      db 'Error: No BrainFuck code provided', 13, 10
            db 'bf <code>', 13, 10
            db 'Example: bf ++++++++[>+++++++++<-]>.', 13, 10, 0

info_msg    db 'A Simple Test System Developed By GuoShucai', 13, 10
            db 'Memory: 0x8000-0xFFFF', 13, 10
            db 'Bootloader: FASM', 13, 10, 0

Na2SO4_msg  db 'This is a surprise.', 13, 10
            db 'Shucai really like Na2SO4.', 13, 10, 0

reboot_msg  db 'System will reboot. Press any key...', 0

shutdown_msg:      db 'Shutting down system...', 0
shutdown_fail_msg: db 'Error: Shutdown failed. System still running.', 0

unknown_cmd_msg db 'Error: Unknown command', 0

; ==== 变量区 ====
command_buffer:  times (COMMAND_MAX_LEN+1) db 0
current_command: dw 0
arg_count:       db 0
arg1:            times (ARG_MAX_LEN+1) db 0
arg2:            times (ARG_MAX_LEN+1) db 0
arg3:            times (ARG_MAX_LEN+1) db 0
bf_tape:      times BF_TAPE_SIZE db 0
bf_data_ptr:  dw 0     ; 数据指针
bf_code_ptr:  dw 0     ; 代码指针

; 填充剩余空间确保文件大小是512字节的倍数
kernel_size = $ - $$
padding_size = (512 - (kernel_size mod 512)) mod 512
times padding_size db 0
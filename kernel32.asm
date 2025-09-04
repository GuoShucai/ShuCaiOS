format binary as 'img'
org 0x10000
use32

start:
    ; 设置段寄存器
    mov ax, 0x10    ; 数据段选择子
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; 设置栈指针
    mov esp, 0x9FFFF ; 设置栈顶
    
    ; 初始化显示
    call clear_screen
    call display_welcome
    
    ; 初始化键盘LED
    call init_keyboard_leds

    ; 主循环
    cli_loop:
        call display_prompt
        call read_command
        call process_command
        jmp cli_loop

; ==== 功能函数 ====

; 清屏函数
clear_screen:
    push eax
    push ecx
    push edi
    
    mov edi, VGA_MEMORY
    mov ecx, 80*25 ; 80列25行
    mov eax, 0x07200720 ; 空格字符(0x20) + 属性(0x07)
    
    rep stosd ; 填充屏幕
    
    ; 重置光标位置
    mov dword [cursor_x], 0
    mov dword [cursor_y], 0
    call update_cursor
    
    pop edi
    pop ecx
    pop eax
    ret

; 更新光标位置
update_cursor:
    push eax
    push ebx
    push edx
    ; 计算光标位置
    mov eax, [cursor_y]
    mov ebx, 80
    mul ebx
    add eax, [cursor_x]
    ; 保存光标位置值到ebx
    mov ebx, eax
    ; 设置光标位置低位
    mov edx, 0x3D4
    mov al, 0x0F
    out dx, al
    mov edx, 0x3D5
    mov al, bl   ; 输出光标位置的低字节
    out dx, al
    ; 设置光标位置高位
    mov edx, 0x3D4
    mov al, 0x0E
    out dx, al
    mov edx, 0x3D5
    mov al, bh   ; 输出光标位置的高字节
    out dx, al
    pop edx
    pop ebx
    pop eax
    ret

; 打印字符串
; 输入: ESI = 字符串地址
print_string:
    push eax
    push esi
    
    .print_loop:
        lodsb ; 加载字节到AL并增加ESI
        test al, al ; 检测是否字符串结束(0)
        jz .done
        
        call print_char
        jmp .print_loop
        
    .done:
        pop esi
        pop eax
    ret

; 打印字符
; 输入: AL = 字符
print_char:
    push edi
    push eax
    push ebx
    
    cmp al, 13 ; 回车
    je .carriage_return
    cmp al, 10 ; 换行
    je .newline
    cmp al, 8  ; 退格
    je .backspace
    
    ; 计算VGA内存位置
    mov edi, [cursor_y]
    imul edi, 80
    add edi, [cursor_x]
    shl edi, 1 ; 每个字符占2字节
    add edi, VGA_MEMORY
    
    ; 写入字符和属性
    mov byte [edi], al
    mov byte [edi+1], 0x07 ; 灰色文本，黑色背景
    
    ; 移动光标
    inc dword [cursor_x]
    cmp dword [cursor_x], 80
    jl .update
    
    ; 换行
    mov dword [cursor_x], 0
    inc dword [cursor_y]
    
    .update:
        cmp dword [cursor_y], 25
        jl .done
        call scroll_screen
        jmp .done
    
    .carriage_return:
        mov dword [cursor_x], 0
        jmp .done
    
    .newline:
        mov dword [cursor_x], 0
        inc dword [cursor_y]
        cmp dword [cursor_y], 25
        jl .done
        call scroll_screen
        jmp .done

    .backspace:
        ; 如果已经在行首，不能继续退格
        cmp dword [cursor_x], 0
        je .done
        
        ; 移动光标
        dec dword [cursor_x]
        
        ; 计算VGA内存位置
        mov edi, [cursor_y]
        imul edi, 80
        add edi, [cursor_x]
        shl edi, 1 ; 每个字符占2字节
        add edi, VGA_MEMORY
        
        ; 写入空格字符清除内容
        mov byte [edi], ' '
        mov byte [edi+1], 0x07
        
        jmp .done
        
    .done:
        call update_cursor
        pop ebx
        pop eax
        pop edi
    ret

; 屏幕滚动
scroll_screen:
    push esi
    push edi
    push ecx
    
    ; 将第2-25行复制到第1-24行
    mov esi, VGA_MEMORY + 160 ; 第2行开始
    mov edi, VGA_MEMORY       ; 第1行开始
    mov ecx, 80*24           ; 24行
    rep movsd
    
    ; 清除最后一行
    mov edi, VGA_MEMORY + 80*24*2
    mov ecx, 80
    mov eax, 0x07200720 ; 空格字符 + 属性
    rep stosd
    
    ; 调整光标位置
    mov dword [cursor_y], 24
    
    pop ecx
    pop edi
    pop esi
    ret

; 打印换行
print_newline:
    push eax
    mov al, 13
    call print_char
    mov al, 10
    call print_char
    pop eax
    ret

; 显示欢迎信息
display_welcome:
    mov esi, welcome_msg
    call print_string
    call print_newline
    ret

; 显示提示符
display_prompt:
    mov esi, prompt
    call print_string
    ret

; 读取命令
read_command:
    push eax
    push ecx
    push edi
    
    ; 清空命令缓冲区
    mov edi, command_buffer
    mov ecx, COMMAND_MAX_LEN+1
    xor al, al
    rep stosb
    
    ; 清空参数缓冲区
    mov edi, arg1
    mov ecx, (ARG_MAX_LEN+1)*3
    rep stosb
    
    mov edi, command_buffer
    mov ecx, 0
    
    .read_char:
        ; 等待键盘输入
        call keyboard_read
        
        ; 处理回车键
        cmp al, 13
        je .command_done
        
        ; 处理退格键
        cmp al, 8
        je .backspace
        
        ; 检查缓冲区是否已满
        cmp ecx, COMMAND_MAX_LEN
        jae .read_char
        
        ; 忽略空字符
        test al, al
        jz .read_char
        
        ; 回显字符
        call print_char
        
        ; 存储字符
        stosb
        inc ecx
        jmp .read_char
    
    .backspace:
        cmp ecx, 0
        je .read_char
        
        ; 移动光标并删除字符
        dec edi
        dec ecx
        
        ; 回显退格
        mov al, 8
        call print_char
        
        jmp .read_char
    
    .command_done:
        ; 添加字符串终止符
        mov byte [edi], 0
        
        ; 换行
        call print_newline
        
        pop edi
        pop ecx
        pop eax
    ret

; 键盘读取（轮询方式）
keyboard_read:
    push edx
    push ebx
    
    ; 等待键盘缓冲区有数据
    .wait:
        in al, KEYBOARD_STATUS_PORT
        test al, 1
        jz .wait
    
    ; 读取键盘数据
    in al, KEYBOARD_PORT
    
    ; 检查是否是按键释放事件（最高位为1）
    test al, 0x80
    jnz .ignore_key
    
    ; 简单扫描码到ASCII转换
    xor ebx, ebx  ; 清零 EBX
    mov bl, al
    cmp bl, 0x39  ; 空格键
    je .space_key
    cmp bl, 0x1C  ; 回车键
    je .enter_key
    cmp bl, 0x0E  ; 退格键
    je .backspace_key
    cmp bl, 0x3A  ; Caps Lock
    je .caps_lock
    ; 字母和数字键处理
    cmp byte [caps_lock], 1
    je .upper

    mov esi, keymap
    add esi, ebx
    mov al, [esi]
    
    jmp .done

    .upper:
        mov esi, keymap_shift
        add esi, ebx
        mov al, [esi]
        jmp .done

    .caps_lock:
        xor byte [caps_lock], 1
        ; 更新键盘LED
        call update_keyboard_leds
        mov al, 0
        jmp .done

    .space_key:
        mov al, ' '
        jmp .done
        
    .enter_key:
        mov al, 13
        jmp .done
        
    .backspace_key:
        mov al, 8
        jmp .done
        
    .ignore_key:
        xor al, al ; 返回0表示忽略
    
    .done:
        pop ebx
        pop edx
    ret

; 等待键盘控制器准备好接收命令/数据
keyboard_wait:
    push eax
    push ecx
    
    mov ecx, 0xFFFF  ; 超时计数器
    .wait:
        in al, KEYBOARD_STATUS_PORT
        test al, 0x02  ; 检查输入缓冲区状态位（位1）
        jz .ready      ; 如果为0，表示缓冲区空，可以发送
        loop .wait
    
    ; 超时处理
    .ready:
        pop ecx
        pop eax
        ret

; 等待键盘确认(0xFA)
keyboard_wait_for_ack:
    push eax
    push ecx
    
    mov ecx, 0xFFFF  ; 超时计数器
    .wait:
        in al, KEYBOARD_STATUS_PORT
        test al, 0x01  ; 检查输出缓冲区状态位（位0）
        jz .continue   ; 如果没有数据，继续等待
        
        in al, KEYBOARD_PORT
        cmp al, 0xFA   ; 检查是否是确认响应
        je .ack_received
        
        .continue:
        loop .wait
    
    ; 超时处理
    .ack_received:
        pop ecx
        pop eax
        ret

; 更新键盘LED状态
update_keyboard_leds:
    push eax
    
    ; 等待键盘控制器准备好
    call keyboard_wait
    
    ; 发送LED设置命令
    mov al, 0xED
    out KEYBOARD_PORT, al
    
    ; 等待键盘确认
    call keyboard_wait_for_ack
    
    ; 等待键盘控制器准备好
    call keyboard_wait
    
    ; 计算LED状态
    mov al, 0
    cmp byte [caps_lock], 1
    jne .send_leds
    or al, 0x04  ; 设置Caps Lock LED
    
.send_leds:
    ; 发送LED状态
    out KEYBOARD_PORT, al
    
    ; 等待键盘确认
    call keyboard_wait_for_ack
    
    pop eax
    ret

; 初始化键盘LED
init_keyboard_leds:
    call update_keyboard_leds
    ret
    
; 处理命令
process_command:
    ; 重置参数计数器
    mov byte [arg_count], 0
    
    ; 跳过前导空格
    mov esi, command_buffer
    .skip_spaces:
        lodsb
        cmp al, ' '
        je .skip_spaces
        cmp al, 0
        je .empty_command
        dec esi ; 回退到第一个非空格字符
    
    ; 查找命令结束位置
    mov edi, esi
    .find_end:
        lodsb
        cmp al, 0
        je .single_command
        cmp al, ' '
        je .split_command
        jmp .find_end
    
    .split_command:
        ; 分割命令和参数
        mov byte [esi-1], 0
        
        ; 保存命令位置
        mov [current_command], edi
        
        ; 处理参数
        call process_arguments
        jmp .execute_command
    
    .single_command:
        ; 无参数命令
        mov [current_command], edi
        jmp .execute_command
    
    .empty_command:
        ret
    
    .execute_command:
        ; 检查并执行命令
        mov esi, [current_command]
        
        ; 比较命令
        mov edi, cmd_help
        call strcmp
        jc .do_help

        mov edi, cmd_bf
        call strcmp
        jc .do_bf
        
        mov edi, cmd_clear
        call strcmp
        jc .do_clear
        
        mov edi, cmd_echo
        call strcmp
        jc .do_echo
        
        mov edi, cmd_info
        call strcmp
        jc .do_info
        
        mov edi, cmd_reboot
        call strcmp
        jc .do_reboot

        mov edi, cmd_Na2SO4
        call strcmp
        jc .do_Na2SO4

        ; 添加关机命令处理
        mov edi, cmd_shutdown
        call strcmp
        jc .do_shutdown
        
        ; 未知命令
        mov esi, unknown_cmd_msg
        call print_string
        call print_newline
        ret
        
        ; 命令处理
        .do_help:
            mov esi, help_msg
            call print_string
            call print_newline
            ret

        .do_bf:
            cmp byte [arg_count], 0
            je .bf_no_args

            mov esi, arg1
            call execute_brainfuck
            ret

            .bf_no_args:
                mov esi, bf_msg
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
            mov ecx, 0                  ; 当前参数索引
    
            .print_loop:

                ; 计算参数地址 = arg1 + (索引 * 参数大小)
                mov eax, ecx
                mov ebx, ARG_MAX_LEN+1
                mul ebx                 ; EAX = EAX * EBX
                mov esi, arg1
                add esi, eax            ; ESI = 参数地址

                ; 打印参数
                call print_string
                call print_newline

                inc ecx
                cmp cl, [arg_count]
                jae .echo_done
                
                jmp .print_loop
    
            .echo_done:
                call print_newline
                ret
    
            .echo_no_args:
                call print_newline  ; 空行
                ret
        
        .do_info:
            mov esi, info_msg
            call print_string
            call print_newline
            ret

        .do_Na2SO4:
            mov esi, Na2SO4_msg
            call print_string
            call print_newline
            ret
        
        .do_reboot:
            call reboot
            ret

        ; 关机命令处理
        .do_shutdown:
            call shutdown
            mov esi, shutdown_fail_msg
            call print_string
            call print_newline
            ret

; ==== BrainFuck解释器实现 ====
execute_brainfuck:
    push ebp
    mov ebp, esp
    pushad                 ; 保存所有寄存器
    
    ; 初始化内存带 (使用ES:EDI指向)
    mov edi, bf_tape
    mov ecx, BF_TAPE_SIZE
    xor al, al
    rep stosb
    
    ; 设置指针
    mov dword [bf_data_ptr], bf_tape
    mov dword [bf_code_ptr], esi    ; ESI包含BF代码地址
    
    ; 主解释循环
    .bf_loop:
        mov esi, [bf_code_ptr]
        cmp byte [esi], 0
        je .bf_done
        
        ; 处理不同指令
        mov al, [esi]
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
        inc dword [bf_data_ptr]
        jmp .next_char
    .ptr_dec:
        dec dword [bf_data_ptr]
        jmp .next_char
    .cell_inc:
        mov esi, [bf_data_ptr]
        inc byte [esi]
        jmp .next_char
    .cell_dec:
        mov esi, [bf_data_ptr]
        dec byte [esi]
        jmp .next_char
    .cell_out:
        mov esi, [bf_data_ptr]
        mov al, [esi]
        call print_char      ; 使用自定义字符输出函数
        jmp .next_char
    .cell_in:
        ; 实现输入功能 - 使用键盘驱动程序
        call keyboard_read
        mov esi, [bf_data_ptr]
        mov [esi], al
        jmp .next_char
    .loop_start:
        mov esi, [bf_data_ptr]
        cmp byte [esi], 0
        jne .next_char
        
        ; 跳过循环，寻找匹配的]
        mov ecx, 1  ; 嵌套计数
        .find_loop_end:
            inc dword [bf_code_ptr]
            mov esi, [bf_code_ptr]
            cmp byte [esi], '['
            jne .check_close
            inc ecx
        .check_close:
            cmp byte [esi], ']'
            jne .next_find
            dec ecx
            jz .next_char  ; 找到匹配
        .next_find:
            jmp .find_loop_end
    .loop_end:
        mov esi, [bf_data_ptr]
        cmp byte [esi], 0
        je .next_char
        
        ; 跳回匹配的[
        mov ecx, 1  ; 嵌套计数
        .find_loop_start:
            dec dword [bf_code_ptr]
            mov esi, [bf_code_ptr]
            cmp byte [esi], ']'
            jne .check_open
            inc ecx
        .check_open:
            cmp byte [esi], '['
            jne .next_find_start
            dec ecx
            jz .next_char  ; 找到匹配
        .next_find_start:
            jmp .find_loop_start
    .next_char:
        inc dword [bf_code_ptr]
        jmp .bf_loop
    .bf_done:
        call print_newline
        popad
        mov esp, ebp
        pop ebp
    ret

; ==== 参数处理函数 ====
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
            dec esi ; 回退到第一个非空格字符
        
        ; 根据arg_count选择目标缓冲区
        mov al, [arg_count]
        cmp al, 0
            je .arg1
        cmp al, 1
            je .arg2
        cmp al, 2
            je .arg3
        jmp .done ; 最多处理3个参数
        
        .arg1:
            mov edi, arg1
            jmp .copy
        .arg2:
            mov edi, arg2
            jmp .copy
        .arg3:
            mov edi, arg3

        ; 复制参数
        .copy:
            mov ecx, ARG_MAX_LEN ; 最大参数长度
        .copy_loop:
            lodsb
            cmp al, ' '
            je .space_found
            cmp al, 0
            je .end_found
            stosb
            dec ecx
            jz .buffer_full ; 缓冲区满
            
            jmp .copy_loop

        .buffer_full:
            mov byte [edi], 0 ; 确保终止符
            
        .space_found:
            mov byte [edi], 0
            inc byte [arg_count]
            jmp .next_arg
            
        .end_found:
            mov byte [edi], 0
            inc byte [arg_count]
            jmp .done
    
    .done:
    ret

; 字符串比较
; 输入: ESI=字符串1, EDI=字符串2
; 输出: CF=1(相等), CF=0(不相等)
strcmp:
    push esi
    push edi
    
    .compare:
        lodsb
        mov bl, [edi]
        inc edi
        
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
        pop edi
        pop esi
    ret

; 字符串复制
; 输入: ESI=源字符串, EDI=目标缓冲区
strcpy:
    push esi
    push edi
    
    .copy_loop:
        lodsb
        stosb
        test al, al
        jnz .copy_loop
    
    pop edi
    pop esi
    ret

; ==== 关机函数实现 ====
shutdown:
    ; 显示关机消息
    mov esi, shutdown_msg
    call print_string
    call print_newline
    
    ; 延迟让用户看到消息
    mov ecx, 0xFFFFFF
    .delay_loop:
        nop
        loop .delay_loop
    
    ; 方法1: QEMU专用关机
    mov dx, 0x604 ; QEMU特殊端口
    mov ax, 0x2000
    out dx, ax
    
    ; 方法2: APM关机
    mov ax, 0x5301 ; APM安装检查
    xor bx, bx
    int 0x15
    jc .try_cpu_halt ; 如果失败则跳过
    
    mov ax, 0x530E ; 设置APM版本
    xor bx, bx
    mov cx, 0x0102 ; 版本1.2
    int 0x15
    jc .try_cpu_halt
    
    mov ax, 0x5307 ; 设置电源状态
    mov bx, 0x0001 ; 所有设备
    mov cx, 0x0003 ; 关机
    int 0x15
    
    ; 方法3: 尝试CPU停机
    .try_cpu_halt:
        cli ; 禁用中断
        hlt ; 停止CPU
        
        ; 如果HLT被中断，尝试循环停机
        .halt_loop:
            cli
            hlt
            jmp .halt_loop
    
    ; 如果执行到这里，说明所有关机方法都失败了
    ret
; ==== 重启函数实现 ====
reboot:
    mov esi, reboot_msg
    call print_string
    call print_newline
    
    ; 尝试通过键盘控制器重启
    mov al, 0xFE
    out 0x64, al
    
    ; 延迟后尝试跳转到复位向量
    mov ecx, 0xFFFFFF
    .delay_loop:
        nop
    loop .delay_loop
    
    ; 跳转到BIOS复位向量
    jmp 0xF000:0xFFF0
    
    ret
; ==== 数据区 ====
welcome_msg:  db 'ShuCaiOS v0.1 (32-bit Protected Mode)', 13, 10
              db 'By GuoShucai', 13, 10
              db 'Type "help" for available commands', 13, 10, 0

prompt:       db '> ', 0

cmd_help:     db 'help', 0
cmd_bf:       db 'bf', 0
cmd_clear:    db 'clear', 0
cmd_echo:     db 'echo', 0
cmd_info:     db 'info', 0
cmd_reboot:   db 'reboot', 0
cmd_shutdown: db 'shutdown', 0
cmd_Na2SO4:   db 'Na2SO4', 0

help_msg:     db 'Available commands:', 13, 10
              db '  help      - Show this help', 13, 10
              db '  bf <code> - Execute BrainFuck code', 13, 10
              db '  clear     - Clear the screen', 13, 10
              db '  echo      - Print arguments', 13, 10
              db '  info      - Show system information', 13, 10
              db '  reboot    - Restart the system', 13, 10
              db '  shutdown  - Power off the system', 13, 10, 0

bf_msg:       db 'Error: No BrainFuck code provided', 13, 10
              db 'bf <code>', 13, 10
              db 'Example: bf ++++++++[>+++++++++<-]>.', 13, 10, 0

info_msg:     db 'A Simple Test System Developed By GuoShucai', 13, 10
              db 'Running in 32-bit Protected Mode', 13, 10
              db 'Memory: 0x8000-0xFFFF', 13, 10
              db 'Bootloader: FASM', 13, 10, 0

Na2SO4_msg:   db 'This is a surprise.', 13, 10
              db 'Shucai really like Na2SO4.', 13, 10, 0

reboot_msg:   db 'System will reboot. Press any key...', 0

shutdown_msg:      db 'Shutting down system...', 0
shutdown_fail_msg: db 'Error: Shutdown failed. System still running.', 0

unknown_cmd_msg:   db 'Error: Unknown command', 0

keymap:
    db 0, 'E1234567890-=', 8
    db 0, 'qwertyuiop[]', 13
    db 0, "asdfghjkl;'", '`'
    db 0, '\zxcvbnm,./', 0
    times 128 db 0
keymap_shift:
    db 0, 0, '!@#$%^&*()_+', 8
    db 0, 'QWERTYUIOP{}', 13
    db 0, 'ASDFGHJKL:"', "~"
    db 0, '|ZXCVBNM<>?', 0
    times 128 db 0

; ==== 定义常量 ====
VGA_MEMORY = 0xB8000
KEYBOARD_PORT = 0x60
KEYBOARD_STATUS_PORT = 0x64
COMMAND_MAX_LEN = 256
ARG_MAX_LEN = 255
BF_TAPE_SIZE = 30000
; ==== 变量区 ====
cursor_x: dd 0
cursor_y: dd 0

command_buffer:  times (COMMAND_MAX_LEN+1) db 0
current_command: dd 0
arg_count:       db 0
arg1:            times (ARG_MAX_LEN+1) db 0
arg2:            times (ARG_MAX_LEN+1) db 0
arg3:            times (ARG_MAX_LEN+1) db 0
bf_tape:      times BF_TAPE_SIZE db 0
bf_data_ptr:  dd 0     ; 数据指针
bf_code_ptr:  dd 0     ; 代码指针
caps_lock:    db 0     ;Caps Lock状态
; 填充剩余空间确保文件大小是512字节的倍数
kernel_size = $ - $$
padding_size = (512 - (kernel_size mod 512)) mod 512
times padding_size db 0
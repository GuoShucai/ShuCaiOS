format binary as 'img'
org 0x10000
use32

start:
    ; ���öμĴ���
    mov ax, 0x10    ; ���ݶ�ѡ����
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; ����ջָ��
    mov esp, 0x9FFFF ; ����ջ��
    
    ; ��ʼ����ʾ
    call clear_screen
    call display_welcome
    
    ; ��ʼ������LED
    call init_keyboard_leds

    ; ��ѭ��
    cli_loop:
        call display_prompt
        call read_command
        call process_command
        jmp cli_loop

; ==== ���ܺ��� ====

; ��������
clear_screen:
    push eax
    push ecx
    push edi
    
    mov edi, VGA_MEMORY
    mov ecx, 80*25 ; 80��25��
    mov eax, 0x07200720 ; �ո��ַ�(0x20) + ����(0x07)
    
    rep stosd ; �����Ļ
    
    ; ���ù��λ��
    mov dword [cursor_x], 0
    mov dword [cursor_y], 0
    call update_cursor
    
    pop edi
    pop ecx
    pop eax
    ret

; ���¹��λ��
update_cursor:
    push eax
    push ebx
    push edx
    ; ������λ��
    mov eax, [cursor_y]
    mov ebx, 80
    mul ebx
    add eax, [cursor_x]
    ; ������λ��ֵ��ebx
    mov ebx, eax
    ; ���ù��λ�õ�λ
    mov edx, 0x3D4
    mov al, 0x0F
    out dx, al
    mov edx, 0x3D5
    mov al, bl   ; ������λ�õĵ��ֽ�
    out dx, al
    ; ���ù��λ�ø�λ
    mov edx, 0x3D4
    mov al, 0x0E
    out dx, al
    mov edx, 0x3D5
    mov al, bh   ; ������λ�õĸ��ֽ�
    out dx, al
    pop edx
    pop ebx
    pop eax
    ret

; ��ӡ�ַ���
; ����: ESI = �ַ�����ַ
print_string:
    push eax
    push esi
    
    .print_loop:
        lodsb ; �����ֽڵ�AL������ESI
        test al, al ; ����Ƿ��ַ�������(0)
        jz .done
        
        call print_char
        jmp .print_loop
        
    .done:
        pop esi
        pop eax
    ret

; ��ӡ�ַ�
; ����: AL = �ַ�
print_char:
    push edi
    push eax
    push ebx
    
    cmp al, 13 ; �س�
    je .carriage_return
    cmp al, 10 ; ����
    je .newline
    cmp al, 8  ; �˸�
    je .backspace
    
    ; ����VGA�ڴ�λ��
    mov edi, [cursor_y]
    imul edi, 80
    add edi, [cursor_x]
    shl edi, 1 ; ÿ���ַ�ռ2�ֽ�
    add edi, VGA_MEMORY
    
    ; д���ַ�������
    mov byte [edi], al
    mov byte [edi+1], 0x07 ; ��ɫ�ı�����ɫ����
    
    ; �ƶ����
    inc dword [cursor_x]
    cmp dword [cursor_x], 80
    jl .update
    
    ; ����
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
        ; ����Ѿ������ף����ܼ����˸�
        cmp dword [cursor_x], 0
        je .done
        
        ; �ƶ����
        dec dword [cursor_x]
        
        ; ����VGA�ڴ�λ��
        mov edi, [cursor_y]
        imul edi, 80
        add edi, [cursor_x]
        shl edi, 1 ; ÿ���ַ�ռ2�ֽ�
        add edi, VGA_MEMORY
        
        ; д��ո��ַ��������
        mov byte [edi], ' '
        mov byte [edi+1], 0x07
        
        jmp .done
        
    .done:
        call update_cursor
        pop ebx
        pop eax
        pop edi
    ret

; ��Ļ����
scroll_screen:
    push esi
    push edi
    push ecx
    
    ; ����2-25�и��Ƶ���1-24��
    mov esi, VGA_MEMORY + 160 ; ��2�п�ʼ
    mov edi, VGA_MEMORY       ; ��1�п�ʼ
    mov ecx, 80*24           ; 24��
    rep movsd
    
    ; ������һ��
    mov edi, VGA_MEMORY + 80*24*2
    mov ecx, 80
    mov eax, 0x07200720 ; �ո��ַ� + ����
    rep stosd
    
    ; �������λ��
    mov dword [cursor_y], 24
    
    pop ecx
    pop edi
    pop esi
    ret

; ��ӡ����
print_newline:
    push eax
    mov al, 13
    call print_char
    mov al, 10
    call print_char
    pop eax
    ret

; ��ʾ��ӭ��Ϣ
display_welcome:
    mov esi, welcome_msg
    call print_string
    call print_newline
    ret

; ��ʾ��ʾ��
display_prompt:
    mov esi, prompt
    call print_string
    ret

; ��ȡ����
read_command:
    push eax
    push ecx
    push edi
    
    ; ����������
    mov edi, command_buffer
    mov ecx, COMMAND_MAX_LEN+1
    xor al, al
    rep stosb
    
    ; ��ղ���������
    mov edi, arg1
    mov ecx, (ARG_MAX_LEN+1)*3
    rep stosb
    
    mov edi, command_buffer
    mov ecx, 0
    
    .read_char:
        ; �ȴ���������
        call keyboard_read
        
        ; ����س���
        cmp al, 13
        je .command_done
        
        ; �����˸��
        cmp al, 8
        je .backspace
        
        ; ��黺�����Ƿ�����
        cmp ecx, COMMAND_MAX_LEN
        jae .read_char
        
        ; ���Կ��ַ�
        test al, al
        jz .read_char
        
        ; �����ַ�
        call print_char
        
        ; �洢�ַ�
        stosb
        inc ecx
        jmp .read_char
    
    .backspace:
        cmp ecx, 0
        je .read_char
        
        ; �ƶ���겢ɾ���ַ�
        dec edi
        dec ecx
        
        ; �����˸�
        mov al, 8
        call print_char
        
        jmp .read_char
    
    .command_done:
        ; ����ַ�����ֹ��
        mov byte [edi], 0
        
        ; ����
        call print_newline
        
        pop edi
        pop ecx
        pop eax
    ret

; ���̶�ȡ����ѯ��ʽ��
keyboard_read:
    push edx
    push ebx
    
    ; �ȴ����̻�����������
    .wait:
        in al, KEYBOARD_STATUS_PORT
        test al, 1
        jz .wait
    
    ; ��ȡ��������
    in al, KEYBOARD_PORT
    
    ; ����Ƿ��ǰ����ͷ��¼������λΪ1��
    test al, 0x80
    jnz .ignore_key
    
    ; ��ɨ���뵽ASCIIת��
    xor ebx, ebx  ; ���� EBX
    mov bl, al
    cmp bl, 0x39  ; �ո��
    je .space_key
    cmp bl, 0x1C  ; �س���
    je .enter_key
    cmp bl, 0x0E  ; �˸��
    je .backspace_key
    cmp bl, 0x3A  ; Caps Lock
    je .caps_lock
    ; ��ĸ�����ּ�����
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
        ; ���¼���LED
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
        xor al, al ; ����0��ʾ����
    
    .done:
        pop ebx
        pop edx
    ret

; �ȴ����̿�����׼���ý�������/����
keyboard_wait:
    push eax
    push ecx
    
    mov ecx, 0xFFFF  ; ��ʱ������
    .wait:
        in al, KEYBOARD_STATUS_PORT
        test al, 0x02  ; ������뻺����״̬λ��λ1��
        jz .ready      ; ���Ϊ0����ʾ�������գ����Է���
        loop .wait
    
    ; ��ʱ����
    .ready:
        pop ecx
        pop eax
        ret

; �ȴ�����ȷ��(0xFA)
keyboard_wait_for_ack:
    push eax
    push ecx
    
    mov ecx, 0xFFFF  ; ��ʱ������
    .wait:
        in al, KEYBOARD_STATUS_PORT
        test al, 0x01  ; ������������״̬λ��λ0��
        jz .continue   ; ���û�����ݣ������ȴ�
        
        in al, KEYBOARD_PORT
        cmp al, 0xFA   ; ����Ƿ���ȷ����Ӧ
        je .ack_received
        
        .continue:
        loop .wait
    
    ; ��ʱ����
    .ack_received:
        pop ecx
        pop eax
        ret

; ���¼���LED״̬
update_keyboard_leds:
    push eax
    
    ; �ȴ����̿�����׼����
    call keyboard_wait
    
    ; ����LED��������
    mov al, 0xED
    out KEYBOARD_PORT, al
    
    ; �ȴ�����ȷ��
    call keyboard_wait_for_ack
    
    ; �ȴ����̿�����׼����
    call keyboard_wait
    
    ; ����LED״̬
    mov al, 0
    cmp byte [caps_lock], 1
    jne .send_leds
    or al, 0x04  ; ����Caps Lock LED
    
.send_leds:
    ; ����LED״̬
    out KEYBOARD_PORT, al
    
    ; �ȴ�����ȷ��
    call keyboard_wait_for_ack
    
    pop eax
    ret

; ��ʼ������LED
init_keyboard_leds:
    call update_keyboard_leds
    ret
    
; ��������
process_command:
    ; ���ò���������
    mov byte [arg_count], 0
    
    ; ����ǰ���ո�
    mov esi, command_buffer
    .skip_spaces:
        lodsb
        cmp al, ' '
        je .skip_spaces
        cmp al, 0
        je .empty_command
        dec esi ; ���˵���һ���ǿո��ַ�
    
    ; �����������λ��
    mov edi, esi
    .find_end:
        lodsb
        cmp al, 0
        je .single_command
        cmp al, ' '
        je .split_command
        jmp .find_end
    
    .split_command:
        ; �ָ�����Ͳ���
        mov byte [esi-1], 0
        
        ; ��������λ��
        mov [current_command], edi
        
        ; �������
        call process_arguments
        jmp .execute_command
    
    .single_command:
        ; �޲�������
        mov [current_command], edi
        jmp .execute_command
    
    .empty_command:
        ret
    
    .execute_command:
        ; ��鲢ִ������
        mov esi, [current_command]
        
        ; �Ƚ�����
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

        ; ��ӹػ������
        mov edi, cmd_shutdown
        call strcmp
        jc .do_shutdown
        
        ; δ֪����
        mov esi, unknown_cmd_msg
        call print_string
        call print_newline
        ret
        
        ; �����
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
    
            ; ѭ����ӡ���в���
            mov ecx, 0                  ; ��ǰ��������
    
            .print_loop:

                ; ���������ַ = arg1 + (���� * ������С)
                mov eax, ecx
                mov ebx, ARG_MAX_LEN+1
                mul ebx                 ; EAX = EAX * EBX
                mov esi, arg1
                add esi, eax            ; ESI = ������ַ

                ; ��ӡ����
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
                call print_newline  ; ����
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

        ; �ػ������
        .do_shutdown:
            call shutdown
            mov esi, shutdown_fail_msg
            call print_string
            call print_newline
            ret

; ==== BrainFuck������ʵ�� ====
execute_brainfuck:
    push ebp
    mov ebp, esp
    pushad                 ; �������мĴ���
    
    ; ��ʼ���ڴ�� (ʹ��ES:EDIָ��)
    mov edi, bf_tape
    mov ecx, BF_TAPE_SIZE
    xor al, al
    rep stosb
    
    ; ����ָ��
    mov dword [bf_data_ptr], bf_tape
    mov dword [bf_code_ptr], esi    ; ESI����BF�����ַ
    
    ; ������ѭ��
    .bf_loop:
        mov esi, [bf_code_ptr]
        cmp byte [esi], 0
        je .bf_done
        
        ; ����ָͬ��
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
        jmp .next_char  ; ������Ч�ַ�
        
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
        call print_char      ; ʹ���Զ����ַ��������
        jmp .next_char
    .cell_in:
        ; ʵ�����빦�� - ʹ�ü�����������
        call keyboard_read
        mov esi, [bf_data_ptr]
        mov [esi], al
        jmp .next_char
    .loop_start:
        mov esi, [bf_data_ptr]
        cmp byte [esi], 0
        jne .next_char
        
        ; ����ѭ����Ѱ��ƥ���]
        mov ecx, 1  ; Ƕ�׼���
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
            jz .next_char  ; �ҵ�ƥ��
        .next_find:
            jmp .find_loop_end
    .loop_end:
        mov esi, [bf_data_ptr]
        cmp byte [esi], 0
        je .next_char
        
        ; ����ƥ���[
        mov ecx, 1  ; Ƕ�׼���
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
            jz .next_char  ; �ҵ�ƥ��
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

; ==== ���������� ====
process_arguments:
    ; ���ò���������
    mov byte [arg_count], 0
    
    .next_arg:
        ; �����ո�
        .skip_spaces:
            lodsb
            cmp al, ' '
            je .skip_spaces
            cmp al, 0
            je .done
            dec esi ; ���˵���һ���ǿո��ַ�
        
        ; ����arg_countѡ��Ŀ�껺����
        mov al, [arg_count]
        cmp al, 0
            je .arg1
        cmp al, 1
            je .arg2
        cmp al, 2
            je .arg3
        jmp .done ; ��ദ��3������
        
        .arg1:
            mov edi, arg1
            jmp .copy
        .arg2:
            mov edi, arg2
            jmp .copy
        .arg3:
            mov edi, arg3

        ; ���Ʋ���
        .copy:
            mov ecx, ARG_MAX_LEN ; ����������
        .copy_loop:
            lodsb
            cmp al, ' '
            je .space_found
            cmp al, 0
            je .end_found
            stosb
            dec ecx
            jz .buffer_full ; ��������
            
            jmp .copy_loop

        .buffer_full:
            mov byte [edi], 0 ; ȷ����ֹ��
            
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

; �ַ����Ƚ�
; ����: ESI=�ַ���1, EDI=�ַ���2
; ���: CF=1(���), CF=0(�����)
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

; �ַ�������
; ����: ESI=Դ�ַ���, EDI=Ŀ�껺����
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

; ==== �ػ�����ʵ�� ====
shutdown:
    ; ��ʾ�ػ���Ϣ
    mov esi, shutdown_msg
    call print_string
    call print_newline
    
    ; �ӳ����û�������Ϣ
    mov ecx, 0xFFFFFF
    .delay_loop:
        nop
        loop .delay_loop
    
    ; ����1: QEMUר�ùػ�
    mov dx, 0x604 ; QEMU����˿�
    mov ax, 0x2000
    out dx, ax
    
    ; ����2: APM�ػ�
    mov ax, 0x5301 ; APM��װ���
    xor bx, bx
    int 0x15
    jc .try_cpu_halt ; ���ʧ��������
    
    mov ax, 0x530E ; ����APM�汾
    xor bx, bx
    mov cx, 0x0102 ; �汾1.2
    int 0x15
    jc .try_cpu_halt
    
    mov ax, 0x5307 ; ���õ�Դ״̬
    mov bx, 0x0001 ; �����豸
    mov cx, 0x0003 ; �ػ�
    int 0x15
    
    ; ����3: ����CPUͣ��
    .try_cpu_halt:
        cli ; �����ж�
        hlt ; ֹͣCPU
        
        ; ���HLT���жϣ�����ѭ��ͣ��
        .halt_loop:
            cli
            hlt
            jmp .halt_loop
    
    ; ���ִ�е����˵�����йػ�������ʧ����
    ret
; ==== ��������ʵ�� ====
reboot:
    mov esi, reboot_msg
    call print_string
    call print_newline
    
    ; ����ͨ�����̿���������
    mov al, 0xFE
    out 0x64, al
    
    ; �ӳٺ�����ת����λ����
    mov ecx, 0xFFFFFF
    .delay_loop:
        nop
    loop .delay_loop
    
    ; ��ת��BIOS��λ����
    jmp 0xF000:0xFFF0
    
    ret
; ==== ������ ====
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

; ==== ���峣�� ====
VGA_MEMORY = 0xB8000
KEYBOARD_PORT = 0x60
KEYBOARD_STATUS_PORT = 0x64
COMMAND_MAX_LEN = 256
ARG_MAX_LEN = 255
BF_TAPE_SIZE = 30000
; ==== ������ ====
cursor_x: dd 0
cursor_y: dd 0

command_buffer:  times (COMMAND_MAX_LEN+1) db 0
current_command: dd 0
arg_count:       db 0
arg1:            times (ARG_MAX_LEN+1) db 0
arg2:            times (ARG_MAX_LEN+1) db 0
arg3:            times (ARG_MAX_LEN+1) db 0
bf_tape:      times BF_TAPE_SIZE db 0
bf_data_ptr:  dd 0     ; ����ָ��
bf_code_ptr:  dd 0     ; ����ָ��
caps_lock:    db 0     ;Caps Lock״̬
; ���ʣ��ռ�ȷ���ļ���С��512�ֽڵı���
kernel_size = $ - $$
padding_size = (512 - (kernel_size mod 512)) mod 512
times padding_size db 0
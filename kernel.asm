format binary as 'img'
org 0x8000
use16

start:
    ; ���öμĴ���
    mov ax, cs
    mov ds, ax
    mov es, ax

    ; ����ջָ��
    mov ss, ax
    mov sp, 0xFFFF  ; ջ���ڶ�ĩβ

    ; ��ʼ����ʾ
    call clear_screen
    call display_welcome
    
    ; ��������ѭ��
    cli_loop:
        call display_prompt
        call read_command
        call process_command
        jmp cli_loop

; ==== ���ܺ��� ====

; ��������
clear_screen:
    mov ax, 0x0600  ; AH=06h(����), AL=00h(ȫ��)
    mov bh, 0x07    ; ����(�ڵװ���)
    xor cx, cx      ; CH=0,CL=0(���Ͻ�)
    mov dx, 0x184F  ; DH=24,DL=79(���½�)
    int 0x10
    mov dx, 0x0000
    call set_cursor  ; ȷ�����ص����Ͻ�
    ret

; ���ù��λ��
; ����: DH=��, DL=��
set_cursor:
    mov ah, 0x02
    mov bh, 0       ; ��0ҳ
    int 0x10
    ret

; ��ȡ���λ��
; ���: DH=��, DL=��
get_cursor:
    mov ah, 0x03
    mov bh, 0
    int 0x10
    ret

; ��ӡ�ַ���
; ����: SI=�ַ�����ַ
print_string:
    push ax
    push si
    
    .print_loop:
        lodsb           ; ����AL�е��ֽڲ�����SI
        or al, al       ; ����Ƿ��ַ�����β(0)
        jz .done
        mov ah, 0x0E    ; BIOS��ӡ�ַ�����
        int 0x10
        jmp .print_loop
    .done:
    
    pop si
    pop ax
    ret

; ��ӡ����
print_newline:
    push ax
    mov ah, 0x0E
    mov al, 13     ; �س�
    int 0x10
    mov al, 10     ; ����
    int 0x10
    pop ax
    ret

; ��ʾ��ӭ��Ϣ
display_welcome:
    mov si, welcome_msg
    call print_string
    call print_newline
    ret

; ��ʾ��ʾ��
display_prompt:
    mov si, prompt
    call print_string
    ret

; ��ȡ����
read_command:
    ; �����������
    mov al, 0
    mov di, command_buffer
    mov cx, COMMAND_MAX_LEN+1
    rep stosb
    
    ; �������������
    mov di, arg1
    mov cx, (ARG_MAX_LEN+1)*3
    rep stosb

    mov di, command_buffer  ; �������
    mov cx, 0               ; �ַ�������
    
    .read_char:
        ; ��ȡ��������
        mov ah, 0x00
        int 0x16
        
        ; ����س���
        cmp al, 13
        je .command_done
        
        ; �����˸��
        cmp al, 8
        je .backspace
        
        ; ������ͨ�ַ�
        cmp cx, COMMAND_MAX_LEN
        jae .read_char      ; ������������������
        
        ; �����ַ�
        mov ah, 0x0E
        int 0x10
        
        ; �洢�ַ�
        stosb
        inc cx
        jmp .read_char
    
    .backspace:
        cmp cx, 0
        je .read_char       ; ���ַ���ɾ��
        
        ; �ƶ���겢ɾ���ַ�
        dec di
        dec cx
        
        ; �����˸�
        mov ah, 0x0E
        mov al, 8
        int 0x10
        mov al, ' '
        int 0x10
        mov al, 8
        int 0x10
        
        jmp .read_char
    
    .command_done:
        ; ����ַ���������
        mov byte [di], 0
        
        ; ����
        call print_newline
        ret

; ��������
process_command:
    ; ���ò���������
    mov byte [arg_count], 0
    
    ; ����ǰ���ո�
    mov si, command_buffer
    .skip_spaces:
        lodsb
        cmp al, ' '
        je .skip_spaces
        cmp al, 0
        je .empty_command
        dec si             ; ���˵���һ���ǿո��ַ�
    
    ; �����������λ��
    mov di, si
    .find_end:
        lodsb
        cmp al, 0
        je .single_command
        cmp al, ' '
        je .split_command
        jmp .find_end
    
    .split_command:
        ; �ָ�����Ͳ���
        mov byte [si-1], 0 ; �滻�ո�Ϊ0��ֹ����
        
        ; ��������λ��
        mov [current_command], di
        
        ; �������
        call process_arguments
        jmp .execute_command
    
    .single_command:
        ; �޲�������
        mov [current_command], di
        jmp .execute_command
    
    .empty_command:
        ret
    
    .execute_command:
        ; ������ִ��
        mov si, [current_command]
        
        ; �Ƚ�����
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

        ; ==== ��ӹػ������ ====
        mov di, cmd_shutdown
        call strcmp
        jc .do_shutdown
        
        ; δ֪����
        mov si, unknown_cmd_msg
        call print_string
        call print_newline
        ret
        
        ; �����
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
    
            ; ѭ����ӡ���в���
            mov cl, 0                  ; ��ǰ��������
    
            .print_loop:
                ; ���������ַ = arg1 + (���� * ������С)
                mov al, cl
                mov bl, ARG_MAX_LEN+1
                mul bl                 ; AX = AL * BL
                mov si, arg1
                add si, ax             ; SI = ������ַ
        
                ; ��ӡ����
                call print_string
                call print_newline
        
                ; ����������һ����������ӡ�ո�
                inc cl
                cmp cl, [arg_count]
                jae .echo_done

                ;������
                ;mov al, ' '
                ;mov ah, 0x0E
                ;int 0x10
                jmp .print_loop
    
            .echo_done:
                ;call print_newline
                ret
    
            .echo_no_args:
                call print_newline  ; ����
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
    
                ; ����1: ���̿��������� (��ѡ)
                mov al, 0xFE
                out 0x64, al
    
                ; ����2: �ӳٺ�����ת (��ֹ����1ִ��̫��)
                mov cx, 0xFFFF
                .delay_loop:
                    nop
                    loop .delay_loop
    
                ; ����3: CPU��λ���� (���ձ���)
                cli
                xor ax, ax
                mov ds, ax
                mov ss, ax
                mov sp, 0xFFF0
                jmp 0xF000:0xFFF0  ; ��ת��BIOS��λ����

        ; ==== �ػ������ ====
        .do_shutdown:
            call shutdown
            ; ����ػ�ʧ�ܣ���ʾ������Ϣ
            mov si, shutdown_fail_msg
            call print_string
            call print_newline
            ret

; ==== BrainFuck������ʵ�� ====
execute_brainfuck:
    ; ��ʼ���ڴ�� (��ES:DIָ��)
    push es
    mov ax, ds
    mov es, ax
    mov di, bf_tape
    mov cx, BF_TAPE_SIZE
    xor al, al
    rep stosb
    
    ; ����ָ��
    mov word [bf_data_ptr], bf_tape
    mov word [bf_code_ptr], si
    
    ; ������ѭ��
    .bf_loop:
        mov si, [bf_code_ptr]
        cmp byte [si], 0
        je .bf_done
        
        ; ����ָͬ��
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
        jmp .next_char  ; ������Ч�ַ�
        
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
        ; ��ʵ�֣�����0
        mov si, [bf_data_ptr]
        mov byte [si], 0
        jmp .next_char
    .loop_start:
        mov si, [bf_data_ptr]
        cmp byte [si], 0
        jne .next_char
        
        ; ����ѭ����Ѱ��ƥ���]
        mov cx, 1  ; Ƕ�׼���
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
            jz .next_char  ; �ҵ�ƥ��
        .next_find:
            jmp .find_loop_end
    .loop_end:
        mov si, [bf_data_ptr]
        cmp byte [si], 0
        je .next_char
        
        ; ����ƥ���[
        mov cx, 1  ; Ƕ�׼���
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
            jz .next_char  ; �ҵ�ƥ��
        .next_find_start:
            jmp .find_loop_start
    .next_char:
        inc word [bf_code_ptr]
        jmp .bf_loop
    .bf_done:
        call print_newline
        pop es
        ret

; ==== ��ȫ�޸��Ĳ��������� ====
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
            dec si          ; ���˵���һ���ǿո��ַ�
        
        ; ����arg_countѡ��Ŀ�껺����
        mov al, [arg_count]
        cmp al, 0
        je .arg1
        cmp al, 1
        je .arg2
        cmp al, 2
        je .arg3
        jmp .done   ; ���ֻ����3������
        .arg1:
            mov di, arg1
            jmp .copy
        .arg2:
            mov di, arg2
            jmp .copy
        .arg3:
            mov di, arg3

        ; ��.copyѭ������ӻ��������ȼ��
        .copy:
            mov cx, ARG_MAX_LEN  ; ����������
        .copy_loop:
            lodsb
            cmp al, ' '
            je .space_found
            cmp al, 0
            je .end_found
            stosb
            dec cx
            jz .buffer_full     ; ��������
            jmp .copy_loop

        .buffer_full:
            mov byte [di], 0    ; ȷ��������
            ; ���������������...
            
            .space_found:
                ; �����������洢0�����Ӽ���
                mov byte [di], 0
                inc byte [arg_count]
                jmp .next_arg
            .end_found:
                mov byte [di], 0
                inc byte [arg_count]
                jmp .done
    
    .done:
        ret

; �ַ����Ƚ�
; ����: SI=�ַ���1, DI=�ַ���2
; ���: CF=1(���), CF=0(����)
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

; �ַ�������
; ����: SI=Դ�ַ���, DI=Ŀ�껺����
strcpy:
    push si
    push di
    cld      ; ȷ�������־�������ǰ���ƣ�
    
    .copy_loop:
        lodsb      ; ��[SI]���ص�AL��SI++
        stosb      ; ��AL�洢��[DI]��DI++
        test al, al
        jnz .copy_loop
    
        pop di
        pop si
        ret

; ==== �ػ�����ʵ�� ====
shutdown:
    ; ��ʾ�ػ���Ϣ
    mov si, shutdown_msg
    call print_string
    call print_newline
    
    ; �ӳ����û�������Ϣ
    mov cx, 0xFFFF
    .delay_loop:
        nop
        loop .delay_loop
    
    ; ����1: QEMUר�ùػ�
    mov dx, 0x604      ; QEMU����˿�
    mov ax, 0x2000
    out dx, ax
    
    ; ����2: APM�ػ�
    mov ax, 0x5301     ; APM��װ���
    xor bx, bx
    int 0x15
    jc .try_cpu_halt   ; ���ʧ��������
    
    mov ax, 0x530E     ; ����APM�汾
    xor bx, bx
    mov cx, 0x0102     ; �汾1.2
    int 0x15
    jc .try_cpu_halt
    
    mov ax, 0x5307     ; ���õ�Դ״̬
    mov bx, 0x0001     ; �����豸
    mov cx, 0x0003     ; �ػ�
    int 0x15
    
    ; ����3: ����CPUͣ��
    .try_cpu_halt:
        cli            ; �����ж�
        hlt            ; ֹͣCPU
        
        ; ���HLT���жϣ�����ѭ��ͣ��
        .halt_loop:
            cli
            hlt
            jmp .halt_loop
    
    ; ���ִ�е����˵�����йػ�������ʧ����
    ret

; ==== �������� ====
BF_TAPE_SIZE  = 30000   ; BrainFuck�ڴ����С
BF_MAX_CODE   = 255     ; BrainFuck������󳤶�
COMMAND_MAX_LEN = 256    ; ָ����󳤶�
ARG_MAX_LEN     = 255    ; ������󳤶�
MAX_ARGS        = 3     ; �����������

; ==== ������ ====
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

; ==== ������ ====
command_buffer:  times (COMMAND_MAX_LEN+1) db 0
current_command: dw 0
arg_count:       db 0
arg1:            times (ARG_MAX_LEN+1) db 0
arg2:            times (ARG_MAX_LEN+1) db 0
arg3:            times (ARG_MAX_LEN+1) db 0
bf_tape:      times BF_TAPE_SIZE db 0
bf_data_ptr:  dw 0     ; ����ָ��
bf_code_ptr:  dw 0     ; ����ָ��

; ���ʣ��ռ�ȷ���ļ���С��512�ֽڵı���
kernel_size = $ - $$
padding_size = (512 - (kernel_size mod 512)) mod 512
times padding_size db 0
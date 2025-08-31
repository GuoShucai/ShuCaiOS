format binary as 'img'
org 0x7C00
use16

start:
    ; ��ʼ���μĴ���
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; ��ʾ������Ϣ
    mov si, loading_msg
    call print_16

    ; �����ں˵�0x10000 (64KB��)
    mov ah, 0x02
    mov al, 20        ; ��ȡ20������ (10KB)
    mov ch, 0         ; �����0
    mov cl, 2         ; ������2��ʼ (����1����������)
    mov dh, 0         ; ��ͷ0
    mov bx, 0x1000    ; ES:BX = 0000:1000 (�����ַ0x10000)
    mov es, bx
    xor bx, bx
    int 0x13
    jc disk_error
    
    ; ���ʵ�ʶ�ȡ��������
    cmp al, 20
    jne disk_error

    ; ׼���л�������ģʽ
    cli               ; �����ж�
    lgdt [gdt_descriptor] ; ����GDT
    
    ; ����A20�� (ʹ�ø��ɿ��ķ���)
    call enable_a20
    
    ; ���ñ���ģʽ��־
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    
    ; Զ��ת������ģʽ����
    jmp 0x08:protected_mode
    
enable_a20:
    ; ͨ�����̿���������A20
    call .wait_input
    mov al, 0xAD      ; ���ü���
    out 0x64, al
    
    call .wait_input
    mov al, 0xD0      ; ��ȡ����˿�
    out 0x64, al
    
    call .wait_output
    in al, 0x60       ; ��ȡ����˿�ֵ
    push eax
    
    call .wait_input
    mov al, 0xD1      ; д������˿�
    out 0x64, al
    
    call .wait_input
    pop eax
    or al, 2          ; ����A20λ
    out 0x60, al
    
    call .wait_input
    mov al, 0xAE      ; ���ü���
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
    ; ����ϵͳ
    cli
    hlt
    jmp $

; GDT���� (ʹ��ƽ̹ģ��)
gdt_start:
    ; ��������
    dq 0
    
    ; ����������� (����ַ0, ����4GB)
    dw 0xFFFF       ; ���� 0-15
    dw 0x0000       ; ����ַ 0-15
    db 0x00         ; ����ַ 16-23
    db 0x9A         ; �����ֽ� (P=1, DPL=00, S=1, EX=1, DC=0, RW=1, AC=0) [ֵ0b10011010]
    db 0xCF         ; ��־ + ���� 16-19 (G=1, D/B=1, L=0, AVL=0, ����16-19=0xF) [ֵ0b11001111]
    db 0x00         ; ����ַ 24-31
    
    ; ���ݶ������� (����ַ0, ����4GB)
    dw 0xFFFF       ; ���� 0-15
    dw 0x0000       ; ����ַ 0-15
    db 0x00         ; ����ַ 16-23
    db 0x92         ; �����ֽ� (P=1, DPL=00, S=1, EX=0, DC=0, RW=1, AC=0) [ֵ0b10010010]
    db 0xCF         ; ��־ + ���� 16-19 [ֵ0b11001111]
    db 0x00         ; ����ַ 24-31
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1  ; GDT��С
    dd gdt_start                ; GDT��ַ

loading_msg db "Loading OS...", 0
err_msg db "Disk error! Press Ctrl+Alt+Del to restart", 0

; �����������
times 510-($-$$) db 0
dw 0xAA55

use32
protected_mode:
    ; ���öμĴ���
    mov ax, 0x10    ; ���ݶ�ѡ����
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x9FFFF ; ����ջָ�� (640KB��)
    
    ; ��ת���ں� (0x10000)
    jmp 0x08:0x10000
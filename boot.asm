format binary as 'img'
org 0x7C00
use16

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; 显示加载信息
    mov si, loading_msg
    call print_16

    ; 加载内核
    mov ah, 0x02
    mov al, 20
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov bx, 0x8000
    int 0x13
    jc disk_error

    jmp 0x0000:0x8000

print_16:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_16
.done:
    ret

disk_error:
    mov si, err_msg
    call print_16
    jmp $

loading_msg db "Loading OS...", 0
err_msg db "Disk Error!", 0

times 510-($-$$) db 0
dw 0xAA55
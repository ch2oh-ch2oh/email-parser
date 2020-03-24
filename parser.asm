code_seg segment
	assume  cs:code_seg,ds:code_seg,es:code_seg
	org 100h
start:
    jmp begin
	
;----------{ constants }----------
dog			EQU	40h		;@	
dot			EQU	2eh		;.
hyphen		EQU 2dh		;-
underscore 	EQU	5fh		;_
plus		EQU 2bh		;+
apostrophe	EQU 27h		;'
comma		EQU 2ch		;,
semicolon	EQU 3bh		;;
CR		EQU	13
LF 		EQU	10
Space	EQU	20h

;----------{ functions }----------
; 
; Передана строчная латинская буква в нижнем регистре? 0 : 1
;
isLetterLC macro letter	
	pushf
	mov al, letter					
	cmp al, 61h
	jl notLetter
	cmp al, 7ah
	jg notLetter
	mov ah, 0
	jmp exitIsLetterLC
notLetter:
	mov ah, 1
exitIsLetterLC:
	popf
	endm
; 
; Передана строчная латинская буква в верхнем регистре? 0 : 1
;
isLetterUC macro letter	
	pushf
	mov al, letter					
	cmp al, 41h
	jl notLetter
	cmp al, 5ah
	jg notLetter
	mov ah, 0
	jmp exitIsLetterUC
notLetter:
	mov ah, 1
exitIsLetterUC:
	popf
	endm
; 
; Передана цифра ? 0 : 1
;
isNumeral macro numeral	
	pushf
	mov al, numeral					
	cmp al, 30h
	jl notNumeral
	cmp al, 39h
	jg notNumeral
	mov ah, 0
	jmp exitIsNumeral
notNumeral:
	mov ah, 1
exitIsNumeral:
	popf
	endm
;
; Передан специальный символ локальной части точка проверяется отдельно)? 0 : 1
;
isCharacter macro char
	pushf
	mov ah, 0
	mov al, char
	cmp al, hyphen
	je exitIsCharacter
	cmp al, underscore
	je exitIsCharacter
	cmp al, plus
	je exitIsCharacter
	cmp al, apostrophe
	je exitIsCharacter
notCharacter:
	mov ah, 1
exitIsCharacter:
	popf
	endm
;
; Печать переданного символа
;
print_letter	macro letter
	push	AX
	push	DX
	mov	DL,	letter
	mov AH, 02
	int 21h
	pop DX
	pop AX
	endm
;
; Печать переданного сообщения
;
print_mes	macro message
	local	msg, nxt
	push	AX
	push	DX
	mov	DX, offset	msg
	mov	AH, 09h
	int	21h
	pop	DX
	pop AX
	jmp nxt
msg	DB	message,'$'
nxt:
	endm

terminator proc	near
LOCALS @@
	cmp Buffer[di],dog
	je @@callcheckb			;если собака то вызываем проверку и выходим без очистки
							;------------------------------------------------------
	cmp Buffer[di],semicolon		;при других ограничителях
	je @@exitcl
	cmp Buffer[di],Space		;выходим и чистим буффер
	je @@exitcl
	cmp Buffer[di],comma		;
	je @@exitcl
	cmp Buffer[di],CR		;каретка
	je @@exitcl
	cmp Buffer[di],LF		;строка
	je @@exitcl
	jmp @@exit
@@callcheckb:
	call checkBuffer
	cmp ah,1				;если вернуло 0 то не чистим
	jne @@exit
@@exitcl:
	call emptyBuffer
@@exit:
	ret

writeBuffer proc near
mov ah,	3fh      ; будем читать из файла
    mov cx,	1        ; 1 байт
	mov di,BufferIndex
    mov dx,offset Buffer[di]      ; в память buf
    int 21h 
ret
	

begin:
	;----------------{ check string of parameters }-----------------
	mov CL, ES:[80h] ; addr. of length parameter in psp
	; is it 0 in buffer?
	cmp CL, 0
	jne $cont ; yes
	;--------------------------------------------------------------- 
	print_mes	'Input File Name > '
	mov	AH,	0Ah  
	mov	DX,	offset FileName
	int  21h 
	print_letter 13
	print_letter 10
	;===============================================================  
	xor BH, BH  
	mov BL,  FileName[1]  
	mov FileName[BX+2], 0 
	;===============================================================  
	mov AX, 3D02h  ; Open file for read/write
	mov DX, offset FileName+2  
	int 21h  
	jnc openOK
	jmp error1
	;=============================================================== 
$cont:
	xor BH, BH
	mov BL, ES:[80h] ; а вот так -> mov BL, [80h]нельзя!!!!
	mov byte ptr [BX+81h], 0
	;---------------------------------------------------------------
	mov CL, ES:80h ; Длина хвоста в PSP
	xor CH, CH ; CX=CL= длина хвоста
	cld ; DF=0 - флаг направления вперед
	mov DI, 81h ; ES:DI-> начало хвоста в PSP
	mov AL,' ' ; Уберем пробелы из начала хвоста
	repe scasb ; Сканируем хвост пока пробелы
	; AL - (ES:DI) -> флаги процессора
	; повторять пока элементы равны
	dec DI ; DI-> на первый символ после пробелов
	;---------------------------------------------------------------
	xor bx, bx
fn_filler:
    cmp bx, 14
    je exit_filler
	mov al, [di+bx]
	mov FileName[bx+2], al
	inc bx
	jmp fn_filler
exit_filler:
	mov AX, 3D00h ; Open file for read
	mov DX, DI
	int 21h  
	jnc openOK
	jmp error1
;=====================================================
openOK:
	MOV Handler, ax ; Сохранение дескриптора	
	mov bx, Handler       ; копируем в bx указатель файла
    xor cx,	cx
    xor dx,	dx
    mov ax,	4200h
    int 21h     ; идем к началу файла
	
out_str:
    call writeBuffer 	;читаем 1 байт в буффер       
    cmp ax,	cx       ; если достигнуть EoF или ошибка чтения
    jnz close       ; то закрываем файл закрываем файл
	call terminator
    ;mov dl,	buf
    ;mov ah,	2        ; выводим символ в dl
    ;int 21h     ; на стандартное устройство вывода
	inc BufferIndex		;увеличим индекс на 1 
    jmp out_str
close:           ; закрываем файл, после чтения
    mov ah,	3eh
    int 21h
	
	
	
exit:            ; завершаем программу
    mov ah,4ch
    int 21h

error1:
	print_mes "File opening/creation error"
	int 20h
	

Buffer DB 40h dup(0)    
Handler DW  ?  
BufferIndex dw 0
FileName    DB  14, 0, 14 dup (0)  

code_seg ends
	end start
; struct student{
; 	name
; 	class
; 	id
; 	grades(xxx.x)
; }

; constant
NAME_LENGTH equ 1
CLASS_LENGTH equ 1
ID_LENGTH equ 2
GRADES_LENGTH equ 4
STUDENT_LENGTH equ NAME_LENGTH + CLASS_LENGTH + ID_LENGTH + GRADES_LENGTH
STUDENT_COUNT equ 5
BUF_LENGTH equ 100

endl macro
	push ax
	push dx

	mov ah, 02h
	mov dl, 0dh ; output \r
	int 21h
	mov dl, 0ah ; output \n
	int 21h

	pop dx
	pop ax
endm

printstr macro addr
	push dx
	push ax

	lea dx, addr
	mov ah, 09h ; output a string end with '$'
	int 21h

	pop ax
	pop dx
endm

putc macro addr
	push ax
	push dx

	mov dl, addr
	mov ah, 02h ; output a char
	int 21h

	pop dx
	pop ax
endm

getchar macro addr ; store a char in addr
	push ax

	mov ah, 01h ; input a char with echo
	int 21h
	mov addr, al

	pop ax
endm

pushr macro
	push ax
	push bx
	push cx
	push dx
endm

popr macro
	pop dx
	pop cx
	pop bx
	pop ax
endm

; exchange [ax] and [bx]
exchange macro
	push bx
	push dx

	push bx
	mov bx, ax
	mov dl, [bx] ; dl = [ax]
	pop bx
	xchg dl, [bx]
	mov bx, ax
	mov [bx], dl

	pop dx
	pop bx
endm

; add bx, STUDENT_LENGTH
nextStudent macro
	push ax
	mov ax, bx
	add ax, STUDENT_LENGTH
	mov bx, ax
	pop ax
endm

; change byte in dl to decimal
byteToDecimal macro
	add dl, '0'
endm

stack segment stack
	dw 100h dup(0)
stack ends

data segment
	students db STUDENT_COUNT * STUDENT_LENGTH dup(0)
	inputNameMsg db 'Please input the student', 27h, 's name:', '$'
	inputClassMsg db 'Please input the student', 27h, 's class:', '$'
	inputIDMsg db 'Please input the student', 27h, 's ID:', '$'
	inputGradesMsg db 'Please input the student', 27h, 's grades:', '$'
	outputNameMsg db 'name:', '$'
	outputClassMsg db 'class:', '$'
	outputIDMsg db 'id:', '$'
	outputGradesMsg db 'grades:', '$'
	outputRawData db 'raw data:', '$'
	outputSortWithID db 'after sort with ID:', '$'
	outputSortWithGrades db 'after sort with grades:', '$'
	outputMeanGrades db 'mean grades of all students:', '$'
	outputStatistic1 db 'grades[<60]:', '$'
	outputStatistic2 db 'grades[60-70]:', '$'
	outputStatistic3 db 'grades[70-80]:', '$'
	outputStatistic4 db 'grades[80-90]:', '$'
	outputStatistic5 db 'grades[>90]:', '$'
	buf db BUF_LENGTH dup(0)
data ends

code segment
	assume cs:code, ds:data, ss:stack
main:
	; load ds
	mov ax, data
	mov ds, ax

	mov cx, STUDENT_COUNT
	lea bx, students
	inputStudentLoop:
		call inputStudent
		nextStudent
		loop inputStudentLoop
	endl

	printstr outputRawData
	endl
	call showAllStudents
	endl

	mov buf[0], 0 ; sort with ID
	call sort
	printstr outputSortWithID
	endl
	call showAllStudents
	endl

	mov buf[0], 1 ; sort with grades
	call sort
	printstr outputSortWithGrades
	endl
	call showAllStudents
	endl

	printstr outputMeanGrades
	call calculateMeanGrade
	endl

	call printStatistic

	; back to system
	mov ax, 4c00h
	int 21h

; input student details
; in:
; - bx: student's address
inputStudent proc
	push bx
	push cx
	; ============================= input name
	printstr inputNameMsg

	mov cx, NAME_LENGTH
	call input
	endl

	; ============================ input class
	printstr inputClassMsg
	
	add bx, NAME_LENGTH
	mov cx, CLASS_LENGTH
	call input
	endl

	; ============================ input ID
	printstr inputIDMsg

	add bx, CLASS_LENGTH
	mov cx, ID_LENGTH
	call input
	endl

	; ============================ input grades
	printstr inputGradesMsg

	add bx, ID_LENGTH
	mov cx, GRADES_LENGTH
	call input
	endl

	pop cx
	pop bx
	ret
inputStudent endp

; input n byte
; in:
; - bx: base address
; - cx: count
input proc
	push bx
	push cx
	push dx

	mov dx, 0 ; counter for cx

	jmp inputJudge
	inputLoop:
		getchar [bx]
		inc bx
		inc dx
	inputJudge:
		cmp cx, dx
		ja inputLoop

	pop dx
	pop cx
	pop bx
	ret
input endp

; locate student[n]
; in:
; - cx: n
; out:
; - bx: address of n-th student
locateStudent proc
	push cx

	; locate
	lea bx, students
	jmp locateStudentJudge
	locateStudentLoop:
		nextStudent
		dec cx
	locateStudentJudge:
		cmp cx, 0
		ja locateStudentLoop

	pop cx
	ret
locateStudent endp

; sortWithID or sortWithGrades
; in:
; - buf[0]: 0 for sortWithID, 1 for sortWithGrades
sort proc
	pushr
	; simple bubble sort

	mov cx, 0 ; counter of loop
	sortLoop:
		push cx

		mov cx, 0
		mov dx, cx ; dx is the index of comparing student
		inc dx
		; ax = address of students[dx], bx = address of students[cx]
		call locateStudent
		mov ax, bx
		sortLoop2:
			add ax, STUDENT_LENGTH
			pushr
			cmp buf[0], 0
			jne sortWithGrades
				; sort with id
				mov cx, ID_LENGTH
				add ax, NAME_LENGTH + CLASS_LENGTH
				add bx, NAME_LENGTH + CLASS_LENGTH
				jmp sortCompare
			sortWithGrades:
				mov cx, GRADES_LENGTH
				add ax, NAME_LENGTH + CLASS_LENGTH + ID_LENGTH
				add bx, NAME_LENGTH + CLASS_LENGTH + ID_LENGTH
			sortCompare:
			call compare
			popr
			je sortContinue
			ja sortNotEqual
				; if students[dx] < students[cx]
				call exchangeStudent
			sortNotEqual:
				mov cx, dx
				mov bx, ax
			sortContinue:
			inc dx
			cmp dx, STUDENT_COUNT
			jb sortLoop2

		pop cx
		inc cx
		cmp cx, STUDENT_COUNT
		jb sortLoop

	popr
	ret
sort endp

; exchange two students
; in:
; - ax: address of student1
; - bx: address of student2
exchangeStudent proc
	pushr

	mov cx, STUDENT_LENGTH
	sortXchg:
		exchange
		inc ax
		inc bx
		loop sortXchg

	popr
	ret
endp

; compare two number of length n
; in:
; - ax: address of number1
; - bx: address of number2
; - cx: length of number1 and number2
compare proc
	pushr

	jmp compareJudge
	compareLoop:
		dec cx
		; set dx to [ax]
		push bx
		mov bx, ax
		mov dl, [bx]
		pop bx
		; compare
		cmp dl, [bx]
		jne compareEnd
		inc bx
		inc ax
	compareJudge:
		cmp cx, 0
		ja compareLoop
	compareEnd:

	popr
	ret
compare endp

showAllStudents proc
	pushr

	mov cx, STUDENT_COUNT
	lea bx, students
	showAllStudentsLoop:
		push cx

		printstr outputNameMsg
		mov cx, NAME_LENGTH
		call puts
		endl
		add bx, NAME_LENGTH
		
		printstr outputClassMsg
		mov cx, CLASS_LENGTH
		call puts
		endl
		add bx, CLASS_LENGTH

		printstr outputIDMsg
		mov cx, ID_LENGTH
		call puts
		endl
		add bx, ID_LENGTH

		printstr outputGradesMsg
		mov cx, GRADES_LENGTH
		call puts
		endl
		add bx, GRADES_LENGTH

		pop cx
		loop showAllStudentsLoop

	popr
	ret
showAllStudents endp

; print a string
; in:
; - bx: base address of the string
; - cx: length of the string
puts proc
	push bx
	push cx

	jmp putsJudge
	putsLoop:
		dec cx
		putc [bx]
		inc bx
	putsJudge:
		cmp cx, 0
		ja putsLoop

	pop cx
	pop bx
	ret
endp

; use buf[0-7]
calculateMeanGrade proc
	pushr

	; clear buf[0-7]
	mov bx, 0
	calculateMeanGradeClearLoop:
		mov buf[bx], '0'
		inc bx
		cmp bx, 8
		jb calculateMeanGradeClearLoop

	; calculate sum
	mov cx, STUDENT_COUNT
	lea bx, students
	calculateMeanGradeLoop:
		call addStudentGrades
		nextStudent
		loop calculateMeanGradeLoop

	; change byte to decimal
	mov ax, 0 ; dx:ax is the decimal result
	mov bx, 0 ; index of buf
	mov cx, 8 ; counter for loop
	mov dx, 0 ; dx:ax is the decimal result
	calculateMeanGradeByteToDecimalLoop:
		push bx
		mov bx, 10
		mul bx
		pop bx
		push cx
		mov ch, 0
		mov cl, buf[bx]
		sub cx, '0'
		add ax, cx
		jnc calculateMeanGradeNotCarry
			; add ax, cx generate carry bit
			inc dx
		calculateMeanGradeNotCarry:
		inc bx
		pop cx
		loop calculateMeanGradeByteToDecimalLoop

	; get mean number in decimal
	push bx
	mov bx, STUDENT_COUNT
	div bx
	pop bx
	mov dx, 0
	; now ax is the result, output it, change decimal to byte
	call printAX

	popr
	ret
endp

; add student's grades to buf
; in:
; - bx: address of student
; - buf[0-7]: previous sum
; out:
; - buf[0-7]: current sum
addStudentGrades proc
	pushr
	
	; bx is pointer of student's grades
	mov ax, bx
	add ax, STUDENT_LENGTH - 1
	mov bx, ax

	mov cx, 8
	addStudentGradesLoop:
		mov al, [bx]
		; set ah to buf[cx - 1]
		push bx
		mov bx, cx ; bx is the pointer of buf
		dec bx
		mov ah, buf[bx]
		; now ah = buf[cx - 1]
		add ah, al
		sub ah, '0'
		mov buf[bx], ah

		mov dx, cx ; may need ++buf[dx]
		sub dx, 2
		jmp addStudentGradesJudge
		addStudentGradesProc:
			; buf[bx] -= 10
			sub ah, 10
			mov buf[bx], ah
			; ++buf[bx - 1]
			dec bx
			mov ah, buf[bx]
			inc ah
			mov buf[bx], ah
		addStudentGradesJudge:
			cmp ah, '9'
			ja addStudentGradesProc
		pop bx ; bx is the pointer of student's grades

		dec bx
		cmp cx, 8 - GRADES_LENGTH + 1
		je addStudentGradesEnd
		loop addStudentGradesLoop

	addStudentGradesEnd:
	popr
	ret
endp

; print ax as decimal
printAX proc
	pushr

	mov bx, 1000
	div bx
	cmp al, 0
	je notShow1
		add al, '0'
		putc al
	notShow1:
	mov ax, dx
	mov bx, 100
	div bl
	cmp al, 0
	je notShow2
		add al, '0'
		putc al
	notShow2:
	mov al, ah
	mov ah, 0
	mov bx, 10
	div bl
	cmp al, 0
	je notShow3
		add al, '0'
		putc al
	notShow3:
	add ah, '0'
	putc ah

	popr
	ret
endp

printStatistic proc
	pushr

	mov ax, 0 ; counter of result
	lea bx, students
	mov cx, STUDENT_COUNT
	printLoop1:
		cmp [bx + STUDENT_LENGTH - 4], '1'
		jnb loop1End
		cmp [bx + STUDENT_LENGTH - 3], '6'
		jnb loop1End
			; < 60
			inc ax
		loop1End:
		nextStudent
		dec cx
		cmp cx, 0
		ja printLoop1
	printstr outputStatistic1
	call printAX
	endl

	mov ax, 0 ; counter of result
	lea bx, students
	mov cx, STUDENT_COUNT
	printLoop2:
		cmp [bx + STUDENT_LENGTH - 4], '1'
		jnb loop2End
		cmp [bx + STUDENT_LENGTH - 3], '6'
		jb loop2End
		cmp [bx + STUDENT_LENGTH - 3], '7'
		jnb loop2End
			; 60-70
			inc ax
		loop2End:
		nextStudent
		dec cx
		cmp cx, 0
		ja printLoop2
	printstr outputStatistic2
	call printAX
	endl

	mov ax, 0 ; counter of result
	lea bx, students
	mov cx, STUDENT_COUNT
	printLoop3:
		cmp [bx + STUDENT_LENGTH - 4], '1'
		jnb loop3End
		cmp [bx + STUDENT_LENGTH - 3], '7'
		jb loop3End
		cmp [bx + STUDENT_LENGTH - 3], '8'
		jnb loop3End
			; 70-80
			inc ax
		loop3End:
		nextStudent
		dec cx
		cmp cx, 0
		ja printLoop3
	printstr outputStatistic3
	call printAX
	endl

	mov ax, 0 ; counter of result
	lea bx, students
	mov cx, STUDENT_COUNT
	printLoop4:
		cmp [bx + STUDENT_LENGTH - 4], '1'
		jnb loop4End
		cmp [bx + STUDENT_LENGTH - 3], '8'
		jb loop4End
		cmp [bx + STUDENT_LENGTH - 3], '9'
		jnb loop4End
			; 80-90
			inc ax
		loop4End:
		nextStudent
		dec cx
		cmp cx, 0
		ja printLoop4
	printstr outputStatistic4
	call printAX
	endl

	mov ax, 0 ; counter of result
	lea bx, students
	mov cx, STUDENT_COUNT
	printLoop5:
		cmp [bx + STUDENT_LENGTH - 4], '1'
		jnb loopInc
		cmp [bx + STUDENT_LENGTH - 3], '9'
		jb loop5End
			; 90-100
		loopInc:
			inc ax
		loop5End:
		nextStudent
		dec cx
		cmp cx, 0
		ja printLoop5
	printstr outputStatistic5
	call printAX
	endl

	popr
	ret
endp

code ends

end main
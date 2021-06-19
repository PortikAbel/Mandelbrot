; Nev: Portik Ábel

; Azonosito: paim1949

; Csoportszam: 513

;nasm -f win32 fraktal_D.asm
;nlink fraktal_D.obj -lio -lmio -lgfx -o fraktal_D.exe

%include 'mio.inc'
%include 'io.inc'
%include 'gfx.inc'

%define WIDTH  1920
%define HEIGHT 1080
%define MAX_IT	256

%define MAX_COLOR_HUE	0xFF
%define IT1		MAX_IT*18/100
%define IT2		MAX_IT*33/100
%define IT3		MAX_IT*49/100
%define IT4		MAX_IT*66/100
%define IT5		MAX_IT*83/100

global main

section .text
main:
	mov		eax, WIDTH
	mov		ebx, HEIGHT
	mov		ecx, 1
	mov		edx, ttl
	call	gfx_init
	call	define_origo_D
	;xor		esi, esi		;starting with simple precision
	
	.loop:
		call	gfx_map
		call	Mandelbrot
		call	gfx_unmap
		call	gfx_draw
		
		.event_loop:
			call	gfx_getevent
			cmp		eax, 27				;ESC => close window
				je	.end
			cmp		eax, 23				;window close button pressed => close window
				je	.end
			call	movements
			call	color
			call	zoom
			;call	precision
		test	eax, eax				; 0 => no  more events
		jnz		.event_loop
	jmp		.loop
	.end:
	call	gfx_destroy
ret

movements:
;handle moving controls
;eax = keyboard event
	cmp		eax, DWORD 'w'				;'w' pressed
	jne		.w_rel
		mov	[bool_up], BYTE	1
	.w_rel:
	
	cmp		eax, DWORD -'w'				;'w' released
	jne		.a
		mov	[bool_up], BYTE	0
	.a:
	
	cmp		eax, DWORD 'a'				;'a' pressed
	jne		.a_rel
		mov	[bool_left], BYTE 1
	.a_rel:
	
	cmp		eax, DWORD -'a'				;'a' released
	jne		.s
		mov	[bool_left], BYTE 0
	.s:
	
	cmp		eax, DWORD 's'				;'s' pressed
	jne		.s_rel
		mov	[bool_down], BYTE 1
	.s_rel:
	
	cmp		eax, DWORD -'s'				;'s' released
	jne		.d
		mov	[bool_down], BYTE 0
	.d:
	
	cmp		eax, DWORD 'd'				;'d' pressed
	jne		.d_rel
		mov	[bool_right], BYTE 1
	.d_rel:
		
	cmp		eax, DWORD -'d'				;'d' released
	jne		.end
		mov	[bool_right], BYTE 0
	.end:
	call	update_offsets
ret
	
update_offsets:
	push	ebx
	sub		esp, 32
	vmovupd	[esp], ymm0
	xor		ebx, ebx
	
	;if bool_mov_up -> increases offset_y
	movzx	ebx, BYTE [bool_up]
	test	ebx, ebx
	jz		.no_up		
		vmovupd	ymm0, [offset_y_D]
		vaddpd	ymm0, [add_offset_D]
		vmovupd	[offset_y_D], ymm0
	.no_up:
	
	;if bool_mov_down -> decreases offset_y
	movzx	ebx, BYTE [bool_down]
	test	ebx, ebx
	jz		.no_down		
		vmovupd	ymm0, [offset_y_D]
		vsubpd	ymm0, [add_offset_D]
		vmovupd	[offset_y_D], ymm0
	.no_down:
	
	;if bool_mov_left -> decreases offset_x
	movzx	ebx, BYTE [bool_left]
	test 	ebx, ebx
	jz		.no_left		
		vmovupd	ymm0, [offset_x_D]
		vsubpd	ymm0, [add_offset_D]
		vmovupd	[offset_x_D], ymm0
	.no_left:
	
	;if bool_mov_right -> increases offset_x
	movzx	ebx, BYTE [bool_right]
	test	ebx, ebx
	jz		.no_right		
		vmovupd	ymm0, [offset_x_D]
		vaddpd	ymm0, [add_offset_D]
		vmovupd	[offset_x_D], ymm0
	.no_right:
	
	vmovupd	ymm0, [esp]
	add		esp, 32
	pop		ebx
ret

color:
	cmp		eax, DWORD 'c'				;'c' pressed
	jne		.c_rel
		mov	[bool_pos_color_chg], BYTE 1
	.c_rel:
	
	cmp		eax, DWORD -'c'				;'c' released
	jne		.x
		mov	[bool_pos_color_chg], BYTE 0
	.x:
	
	cmp		eax, DWORD 'x'				;'x' pressed
	jne		.x_rel
		mov	[bool_neg_color_chg], BYTE 1
	.x_rel:
		
	cmp		eax, DWORD -'x'				;'x' released
	jne		.end
		mov	[bool_neg_color_chg], BYTE 0
	.end:
	call	update_color_const
ret

update_color_const:
	push	ebx
	
	;if bool_pos_color_chg -> increase color_const
	movzx	ebx, BYTE [bool_pos_color_chg]
	test 	ebx, ebx
	jz		.no_pos_chg
		mov	ebx, [color_const]
		inc	ebx
		mov	[color_const], ebx
	.no_pos_chg:
	
	;if bool_neg_color_chg -> decrease color_const
	movzx	ebx, BYTE [bool_neg_color_chg]
	test	ebx, ebx
	jz		.no_neg_chg
		mov	ebx, [color_const]
		dec	ebx
		mov	[color_const], ebx
	.no_neg_chg:
	
	pop		ebx
ret

zoom:
	sub		esp, 32
	vmovupd	[esp], ymm0
	
	cmp	eax, 4
	je	.zoom_in
	cmp	eax, 5
	je	.zoom_out
	cmp	eax, '+'
	je	.zoom_in
	cmp	eax, '-'
	je	.zoom_out
	cmp	eax, 'i'
	je	.zoom_in
	cmp	eax, 'o'
	je	.zoom_out
	jmp	.end
	.zoom_in:
		;double prec:
		vmovupd	ymm0, [scale_D]
		vmulpd	ymm0, [scale_zoom_D]
		vmovupd	[scale_D], ymm0
		
		vmovupd	ymm0, [add_offset_D]
		vdivpd	ymm0, [scale_zoom_D]
		vmovupd	[add_offset_D], ymm0
	jmp	.end
	.zoom_out:
		;double prec:
		vmovupd	ymm0, [scale_D]
		vdivpd	ymm0, [scale_zoom_D]
		vmovupd	[scale_D], ymm0
		
		vmovupd	ymm0, [add_offset_D]
		vmulpd	ymm0, [scale_zoom_D]
		vmovupd	[add_offset_D], ymm0
	.end:
	
	vmovupd	[esp], ymm0
	add		esp, 32
ret

precision:
	cmp		eax, 'p'
	jne		.end
		not	esi
	.end:
ret

define_origo_D:
;[origo_x] <- line number of the Origo pixel
;[origo_y] <- column number of the Origo pixel
	push	eax
	push	ecx
	push	edx
	mov		ecx, DWORD 2
	
	mov		eax, WIDTH
	cdq
	div		ecx	
	cvtsi2sd	xmm0, eax
	movsd	[origo_x_D], xmm0
	
	mov		eax, HEIGHT
	cdq
	div		ecx
	cvtsi2sd	xmm0, eax
	movsd	[origo_y_D], xmm0
	
	pop		edx
	pop		ecx
	pop		eax
ret

get_coordinates_D:
;edx = row number of first pixel
;ecx = column number of first pixel
;return x coordinates in ymm0
;return y coordinates in ymm1
	sub		esp, 32
	vmovupd	[esp], ymm2
	sub		esp, 32
	vmovupd	[esp], ymm3
	
	cvtsi2sd	xmm0, edx
	cvtsi2sd	xmm1, ecx
	vbroadcastsd	ymm0, xmm0
	vbroadcastsd	ymm1, xmm1
	vaddpd			ymm0, [sequence_D]	;making from 4 identical pixel coordinates 4 sequential pixel coordinates
	
	vbroadcastsd	ymm2, [origo_x_D]
	vbroadcastsd	ymm3, [origo_y_D]
	vsubpd			ymm0, ymm2			;ymm0 have the x coordinates of the pixels acoording to the origo
	vsubpd			ymm1, ymm3			;ymm1 have the y coordinates of the pixels acoording to the origo
	vmulpd			ymm1, [negate_D]
	
	vdivpd			ymm0, [scale_D]		;dividing by scale (initially 512 pixels mean 1 unit)	 
	vdivpd			ymm1, [scale_D]		;the scale was changed by zooming in/out
	
	vaddpd			ymm0, [offset_x_D]			;adding the offsets to the coordinates
	vaddpd			ymm1, [offset_y_D]
	
	vmovupd	ymm3, [esp]
	add		esp, 32
	vmovupd	ymm2, [esp]
	add		esp, 32
ret

Mandelbrot:
;eax = pointer to first pixel
;ecx count the rows
;edx count the column
;esi =	0	-> simple precision
;esi = -1 	-> double precision
	push	ecx
	push	edx
	xor		ecx, ecx
	
	.y_loop:
		cmp	ecx, HEIGHT
		jge	.y_end
		
		xor	edx, edx
		.x_loop:
			cmp	edx, WIDTH
			jge	.x_end
			
			call	Mand_D
			add		edx, 4
			add		eax, 16
		jmp	.x_loop
		
		.x_end:
		inc ecx
	jmp	.y_loop
	
	.y_end:
	pop		edx
	pop		ecx
ret

Mand_D:
;edx = row number of first pixel
;ecx = column number of first pixel
	push	ebx
	push	ecx
	sub		esp, 32
	vmovupd	[esp], ymm2				;for storing distances from origo
	sub		esp, 32
	vmovupd	[esp], ymm3				;for masking the counter vector with ones
	sub		esp, 32
	vmovupd	[esp], ymm4				;for counting the iterations
	sub		esp, 32
	vmovupd	[esp], ymm7				;for testing if the point is out of the set
	
	call	get_coordinates_D
	
	vmovupd	[current_x_D], ymm0		;current_x and current_y hold the horizontal and vertical coordinates of every pixel
	vmovupd	[current_y_D], ymm1
	vmovupd	ymm3, [one_vector_D]	;ymm3 is needed for masking the vector that calculates the iterations
	vxorpd	ymm4, ymm4				;ymm4 calculates the number of iterations	
	mov		ecx, MAX_IT
	
	.mand_loop:
		call		dist_from_origo_D
		vcmplepd	ymm7, ymm2, [limit_D]	;if distance is out of limit set 0 all bits		else set 1 all bits (-1 in complementer) in coresponding part of ymm7
		vmovmskpd	ebx, ymm7				;moving the sign bits of vector components into ebx
		test	ebx, ebx					;zero if all points out of limit
		jz	.end
		vandpd	ymm7, ymm3				;masking the counter vector (-1 -> 1	0 -> 0)
		vaddpd	ymm4, ymm7				;counting those which are in the range of limit
		
		vmovupd	ymm2, [two_vector_D]
		vmulpd	ymm2, ymm0				;ymm2 = 2*a
		vmulpd	ymm2, ymm1				;ymm2 = 2*a*b
		vmulpd	ymm0, ymm0				;ymm0 = a^2
		vmulpd	ymm1, ymm1 				;ymm1 = b^2
		vsubpd	ymm0, ymm1				;ymm0 = a^2 - b^2
		vaddpd	ymm0, [current_x_D]		;ymm0 = a^2 - b^2 + x		Mandelbrot-set
		vaddpd	ymm2, [current_y_D]		;ymm2 = 2*a*b + y		Mandelbrot-set
		vmovupd	ymm1, ymm2				;ymm1 = 2*a*b + y
	loop .mand_loop
	
	.end:
		vmovupd	[iterations_D], ymm4		;store the number of iterations
		call	define_color_D				;color the pixels according to number of iterations
		
	vmovupd	ymm7, [esp]
	add		esp, 32
	vmovupd	ymm4, [esp]
	add		esp, 32
	vmovupd	ymm3	, [esp]
	add		esp, 32
	vmovupd	ymm2, [esp]
	add		esp, 32
	pop		ecx
	pop		ebx
ret

dist_from_origo_D:
;get 4 x and y coordinates in ymm0 and ymm1
;return 4 distances in ymm2 vector
	sub		esp, 32
	vmovupd	[esp], ymm0
	sub		esp, 32
	vmovupd	[esp], ymm1
	
	vmulpd	ymm0, ymm0	;ymm0 = x^2
	vmulpd	ymm1, ymm1	;ymm1 = y^2
	vmovupd	ymm2, ymm0	
	vaddpd	ymm2, ymm1	;ymm2 = x^2 + y^2
	vsqrtpd	ymm2, ymm2	;ymm2 = {d(Ai,O) | 1 <= i <= 8}
	
	vmovupd	ymm1, [esp]
	add		esp, 32
	vmovupd	ymm0, [esp]
	add		esp, 32
ret

define_color_D:
;get the pointer to first pixel in eax
	push ecx
	push esi
	push edi
	
	mov edi, eax		;placing the pointer of 1. pixel in edi
	
	mov ecx, 4			;counting pixels in ecx - working with 4 pixels
	xor esi, esi
	
	.loop:
		call	build_rgb_D
		add		esi, 8		;esi holds the offset from the 1. pixel
		add 	edi, 4		;edi holds the pointer of the pixel
	loop .loop
	
	pop edi
	pop esi
	pop ecx
	
ret

build_rgb_D:
;get the offset from the 1. pixel in esi
;get the pointer of the pixel in edi
;buld up the RGB components in ebx
	push	eax
	push	ecx
	push	edx

	mov eax, dword [iterations_D+esi]
	
	cmp eax, MAX_IT					;If the current pixel made maximal iterations => it belongs to the set => gets black
	je	.black
	
	add eax, [color_const]			;always adding some const to the number of iterations (for making possible the color change)
	xor edx, edx
	mov ecx, MAX_IT
	div ecx
	mov eax, edx					;calculate the remainder of the division by the number of maximum iterations
	
	;6 cases where the color components are increasing/decreasing
	;lower case characters	-> the color component is 0
	;upper case characters	-> the color component is maximal
	;the i/d after an r/g/b / R/G/B char -> the color component increases/decreases
	cmp eax, IT1					
	jl .ri_g_B
	cmp eax, IT2
	jl .R_g_Bd
	cmp eax, IT3
	jl .R_gi_b
	cmp eax, IT4
	jl .Rd_G_b
	cmp eax, IT5
	jl .r_G_bi
	jmp .r_Gd_B
	
	.ri_g_B:
		mov ebx, MAX_COLOR_HUE
		mul ebx			;nr. of iterations -> color hue
		
		mov ecx, IT1
		div ecx			;define hue of inc component
		
		mov ebx, eax	;setting the inc component
		shl ebx, 16		;leave green 0 + making place for blue
		add ebx, MAX_COLOR_HUE	;set blue maximal
	jmp .place
	
	.R_g_Bd:
		mov ebx, MAX_COLOR_HUE
		sub eax, IT1
		mul ebx			;nr. of iterations -> color hue
		
		mov ebx, IT1
		mov ecx, IT2
		sub ecx, ebx
		div ecx			;define hue of dec component
		
		mov ebx, MAX_COLOR_HUE	;set red max
		shl ebx, 16				;leave green 0 + making place for blue
		add ebx, MAX_COLOR_HUE	;starting from maximal value
		sub ebx, eax			;setting the dec component
	jmp .place

	.R_gi_b:
		mov ebx, MAX_COLOR_HUE
		sub eax, IT2
		mul ebx			;nr. of iterations -> color hue
		
		mov ebx, IT2
		mov ecx, IT3
		sub ecx, ebx
		div ecx			;define hue of inc component
		
		mov ebx, MAX_COLOR_HUE	;set red max
		shl ebx, 8				;making place for green
		add	ebx, eax			;setting the inc component
		shl	ebx, 8				;leave blue 0
	jmp .place
	
	.Rd_G_b:
		mov ebx, MAX_COLOR_HUE
		sub eax, IT3
		mul ebx			;nr. of iterations -> color hue
		
		mov ebx, IT3
		mov ecx, IT4
		sub ecx, ebx
		div ecx			;define hue of dec component
		
		mov ebx, MAX_COLOR_HUE	;set red max
		sub ebx, eax			;setting the dec component
		shl ebx, 8				;making place for green
		add ebx, MAX_COLOR_HUE	;set green max
		shl	ebx, 8				;leave blue 0
	jmp .place
	
	.r_G_bi:
		mov ebx, MAX_COLOR_HUE
		sub eax, IT4
		mul ebx			;nr. of iterations -> color hue
		
		mov ebx, IT4
		mov ecx, IT5
		sub ecx, ebx
		div ecx			;define hue of inc component
		
		xor	ebx, ebx
		mov ebx, MAX_COLOR_HUE	;set green max	(we don't shift 0xFF till red comp.)
		shl ebx, 8				;making place for blue
		add ebx, eax			;setting the inc component
	jmp .place
	
	.r_Gd_B:
		mov ebx, MAX_COLOR_HUE
		sub eax, IT5
		mul ebx			;nr. of iterations -> color hue
		
		mov ebx, IT5
		mov ecx, MAX_IT
		sub ecx, ebx
		div ecx			;define hue of dec component
		
		xor	ebx, ebx
		add ebx, MAX_COLOR_HUE	;starting green from maximal value
		sub ebx, eax			;setting the dec component
		shl	ebx, 8				;making place for blue
		add	ebx, MAX_COLOR_HUE	;set blue max
	jmp .place

	.black:
		mov ebx, 0
		
	.place:
		mov [edi], ebx
		pop	edx
		pop ecx
		pop	eax
ret

section .data
	;strings:
	ttl			db	"Mandelbrot fractal", 0
	error_msg	db	"", 0

	;for movements:
	offset_x	dd	0.0,	0.0,	0.0,	0.0,	0.0,	0.0,	0.0,	0.0
	offset_y	dd	0.0,	0.0,	0.0,	0.0,	0.0,	0.0,	0.0,	0.0
	add_offset	dd	0.05,	0.05,	0.05,	0.05,	0.05,	0.05,	0.05,	0.05
	offset_x_D		dq	0.0,	0.0,	0.0,	0.0
	offset_y_D		dq	0.0,	0.0,	0.0,	0.0
	add_offset_D	dq	0.05,	0.05,	0.05,	0.05

	bool_up		db	0
	bool_left	db	0
	bool_down	db	0
	bool_right	db	0

	;for changing the colour:
	bool_pos_color_chg	db	0
	bool_neg_color_chg	db	0
	color_const	db	0

	;to make a pixel sequence from a first pixel:
	sequence	dd	0.0,	1.0,	2.0,	3.0,	4.0,	5.0,	6.0,	7.0
	sequence_D	dq	0.0,	1.0,	2.0,	3.0

	;for arithmetic operations:
	negate			dd	-1.0,	-1.0,	-1.0,	-1.0,	-1.0,	-1.0,	-1.0,	-1.0
	one_vector		dd	1,		1,		1,		1,		1,		1,		1,		1
	two_vector		dd	2.0,	2.0,	2.0,	2.0,	2.0,	2.0,	2.0,	2.0
	negate_D		dq	-1.0,	-1.0,	-1.0,	-1.0
	one_vector_D	dq	1,		1,		1,		1
	two_vector_D	dq	2.0,	2.0,	2.0,	2.0

	limit		dd	2.0,	2.0,	2.0,	2.0,	2.0,	2.0,	2.0,	2.0
	limit_D		dq	2.0,	2.0,	2.0,	2.0

	;for zooming in/out:
	scale		dd	512.0,	512.0,	512.0,	512.0,	512.0,	512.0,	512.0,	512.0
	scale_zoom	dd	1.25,	1.25,	1.25,	1.25,	1.25,	1.25,	1.25,	1.25
	scale_D			dq	512.0,	512.0,	512.0,	512.0
	scale_zoom_D	dq	1.25,	1.25,	1.25,	1.25

section .bss
	origo_x		resd	1
	origo_y		resd	1
	origo_x_D	resq	1
	origo_y_D	resq	1

	current_x	resd	8
	current_y	resd	8
	current_x_D	resq	4
	current_y_D	resq	4

	iterations		resd	8
	iterations_D	resq	4
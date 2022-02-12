#include "textflag.h"

// copy from go_tls.h
#define get_tls(r)	MOVL TLS, r
#define g(r)	0(r)(TLS*1)

// rt0 is the entry point of the kernel, which invokes kernel.preinit.
TEXT ·rt0(SB), NOSPLIT, $0-0
	// switch to new stack
	MOVQ $0x80000, SP
	XORQ BP, BP

	// DI and SI store multiboot magic and info passed by bootloader
	SUBQ $0x10, SP
	MOVQ DI, 0(SP)
	MOVQ SI, 8(SP)

	// NOTE: the SSE instruction set must be initialized prior to invoking the
	// first Go function, since any transition from asm -> Go will be handled by
	// an autogenerated Go function wrapper for the given function (e.g.
	// kernel.preinit<autogenerated>). The autogenerated function invokes
	// `xorps %xmm15, %xmm15` which crashes the machine unless the FPU has been
	// initialized.
	CALL ·sseInit(SB)

	// NOTE: the fs segment register must be set prior to invoking the first Go
	// function, since any transition from asm -> Go will be handled by an
	// autogenerated Go function wrapper for the given function (e.g.
	// kernel.preinit<autogenerated>). The autogenerated function invokes
	// `%fs:0xfffffffffffffff8,%r14` which crashes the machine unless the fs
	// segment register has been set.
	CALL ·initFakeFS(SB)

	CALL ·preinit(SB)
	INT  $3

	// never return

// go_entry invokes _rt0_amd64_linux of the Go runtime.
TEXT ·go_entry(SB), NOSPLIT, $0
	SUBQ  $256, SP
	PUSHQ SP
	CALL  ·prepareArgs(SB)
	ADDQ  $8, SP
	JMP   _rt0_amd64_linux(SB)

// initFakeFS initializes a valid fake %fs segment register as required by the
// <autogenerated> function wrappers of the Go 1.17 calling convention
// (see icexin/eggos#100) when invoked before kernel.thread0Init.
TEXT ·initFakeFS(SB), NOSPLIT, $0
	// HACK: just use a memory pointer on the stack that we are unlikely to
	// overwrite untill we run thread0Init, at which point, %fs will be set to
	// its real value.
	SUBQ $100000, SP        // TODO: figure out a better way to handle %fs, use a memory address that will never be used before by other instructions before thread0Init.

	MOVL $0xc0000100, CX // _MSR_FS_BASE
	MOVL SP, AX          // low, just to get a valid address to.
	//ADDL $0x3, AX      // low, set lower 2 bits to prevent EIO error
	MOVL $0x0, DX        // high
	WRMSR

	ADDQ  $100000, SP
	RET

// sseInit initializes the SSE instruction set.
TEXT ·sseInit(SB), NOSPLIT, $0
	MOVL CR0, AX
	ANDW $0xFFFB, AX
	ORW  $0x2, AX
	MOVL AX, CR0
	MOVL CR4, AX
	ORW  $3<<9, AX
	MOVL AX, CR4
	RET

// avxInit initializes the AVX instruction set.
TEXT ·avxInit(SB), NOSPLIT, $0
	// enable XGETBV and XSETBV
	MOVL CR4, AX
	ORL  $1<<18, AX
	MOVL AX, CR4

	// enable avx
	XORQ CX, CX
	XGETBV

	ORQ  $7, AX
	XORQ CX, CX
	XSETBV
	RET

// rdmsr(reg uint32) (ax, dx uint32) - Read from Model Specific Register.
TEXT ·rdmsr(SB), NOSPLIT, $0-16
	MOVL reg+0(FP), CX
	RDMSR
	MOVL AX, lo+8(FP)
	MOVL DX, hi+12(FP)
	RET

// wrmsr(reg, lo, hi uint32) - Write to Model Specific Register.
TEXT ·wrmsr(SB), NOSPLIT, $0-16
	MOVL reg+0(FP), CX
	MOVL lo+8(FP), AX
	MOVL hi+12(FP), DX
	WRMSR
	RET

// getg() uint64 - returns G from thread local storage of the current thread.
TEXT ·getg(SB), NOSPLIT, $0-8
	get_tls(CX)
	MOVQ g(CX), BX
	MOVQ BX, ret+0(FP)
	RET

// cpuid(fn, cx uint32) (ax, bx, cx, dx uint32) - CPU Identification.
TEXT ·cpuid(SB), NOSPLIT, $0-24
	MOVL fn+0(FP), AX
	MOVL cx+4(FP), CX
	CPUID
	MOVL AX, eax+8(FP)
	MOVL BX, ebx+12(FP)
	MOVL CX, ecx+16(FP)
	MOVL DX, edx+20(FP)
	RET

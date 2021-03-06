; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: %cheri_purecap_llc -cheri-cap-table-abi=plt %s -O2 -o - | %cheri_FileCheck %s -enable-var-scope -check-prefixes PLT,CHECK
; RUN: %cheri_purecap_llc -cheri-cap-table-abi=pcrel %s -O2 -o - | %cheri_FileCheck %s -enable-var-scope -check-prefixes PCREL,CHECK


; Check that $cgp is restored prior to calling other functions in the same TU
; after an external call (since that clobbers $cgp)

declare i32 @external_func() addrspace(200)
declare i32 @external_func2() addrspace(200)
@fn_ptr = internal unnamed_addr addrspace(200) global i32 () addrspace(200)* @external_func, align 32

define internal i32 @local_func() addrspace(200) nounwind noinline {
; CHECK-LABEL: local_func:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    cincoffset $c11, $c11, -[[STACKFRAME_SIZE:16|32]]
; CHECK-NEXT:    csc $c17, $zero, 0($c11)
; PCREL-NEXT:    lui $1, %hi(%neg(%captab_rel(local_func)))
; PCREL-NEXT:    daddiu $1, $1, %lo(%neg(%captab_rel(local_func)))
; PCREL-NEXT:    cincoffset $c1, $c12, $1
; CHECK-NEXT:    clcbi $c12, %capcall20(external_func)($c{{1|26}})
; CHECK-NEXT:    cjalr $c12, $c17
; CHECK-NEXT:    nop
; CHECK-NEXT:    clc $c17, $zero, 0($c11)
; CHECK-NEXT:    cjr $c17
; CHECK-NEXT:    cincoffset $c11, $c11, [[STACKFRAME_SIZE]]
entry:
  %call = call i32 @external_func()
  ret i32 %call
}

; FIXME: this is inefficient (enabling machine scheduler by default fixes it but makes many other things worse)
define i32 @test1() addrspace(200) nounwind {
; CHECK-LABEL: test1:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    cincoffset $c11, $c11, -[[STACKFRAME_SIZE:48|96]]
; CHECK-NEXT:    csd $16, $zero, [[@EXPR STACKFRAME_SIZE - 8]]($c11)
; CHECK-NEXT:    csc $c18, $zero, [[@EXPR 1 * $CAP_SIZE]]($c11)
; CHECK-NEXT:    csc $c17, $zero, 0($c11)
; PCREL-NEXT:    lui $1, %hi(%neg(%captab_rel(test1)))
; PCREL-NEXT:    daddiu $1, $1, %lo(%neg(%captab_rel(test1)))
; PCREL-NEXT:    cincoffset $c18, $c12, $1
; PLT-NEXT:      cmove $c18, $c26
; CHECK-NEXT:    clcbi $c12, %capcall20(external_func)($c18)
; FIXME: this move should go into the delay slot!
; $cgp only needs to be restored when not using the pc-relative ABI
; CHECK-NEXT:    cjalr $c12, $c17
; PLT-NEXT:      cmove $c26, $c18
; PCREL-NEXT:    nop
; PLT-NEXT:      move $16, $2
; CHECK-NEXT:    clcbi $c12, %capcall20(local_func)($c18)
; $cgp only needs to be restored when not using the pc-relative ABI
; CHECK-NEXT:    cjalr $c12, $c17
; PLT-NEXT:      cmove $c26, $c18
; PCREL-NEXT:    move $16, $2
; CHECK-NEXT:    addu $2, $16, $2
; CHECK-NEXT:    clc $c17, $zero, 0($c11)
; CHECK-NEXT:    clc $c18, $zero, [[@EXPR 1 * $CAP_SIZE]]($c11)
; CHECK-NEXT:    cld $16, $zero, [[@EXPR STACKFRAME_SIZE - 8]]($c11)
; CHECK-NEXT:    cjr $c17
; CHECK-NEXT:    cincoffset $c11, $c11, [[STACKFRAME_SIZE]]
entry:
  %call = call i32 @external_func()
  %call2 = call i32 @local_func()
  %result = add i32 %call, %call2
  ret i32 %result
}

; Same when calling an external func (since it could be in the same DSO/executable)
define i32 @test2() addrspace(200) nounwind {
; CHECK-LABEL: test2:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    cincoffset $c11, $c11, -[[STACKFRAME_SIZE:48|96]]
; CHECK-NEXT:    csd $16, $zero, [[@EXPR STACKFRAME_SIZE - 8]]($c11)
; CHECK-NEXT:    csc $c18, $zero, [[@EXPR 1 * $CAP_SIZE]]($c11)
; CHECK-NEXT:    csc $c17, $zero, 0($c11)
; PCREL-NEXT:    lui $1, %hi(%neg(%captab_rel(test2)))
; PCREL-NEXT:    daddiu $1, $1, %lo(%neg(%captab_rel(test2)))
; PCREL-NEXT:    cincoffset $c18, $c12, $1
; PLT-NEXT:      cmove $c18, $c26
; CHECK-NEXT:    clcbi $c12, %capcall20(external_func)($c18)
; $cgp only needs to be restored when not using the pc-relative ABI
; CHECK-NEXT:    cjalr $c12, $c17
; PLT-NEXT:      cmove $c26, $c18
; PCREL-NEXT:    nop
; PLT-NEXT:      move $16, $2
; CHECK-NEXT:    clcbi $c12, %capcall20(external_func2)($c18)
; $cgp only needs to be restored when not using the pc-relative ABI
; CHECK-NEXT:    cjalr $c12, $c17
; PLT-NEXT:      cmove $c26, $c18
; PCREL-NEXT:    move $16, $2
; CHECK-NEXT:    addu $2, $16, $2
; CHECK-NEXT:    clc $c17, $zero, 0($c11)
; CHECK-NEXT:    clc $c18, $zero, [[@EXPR 1 * $CAP_SIZE]]($c11)
; CHECK-NEXT:    cld $16, $zero, [[@EXPR STACKFRAME_SIZE - 8]]($c11)
; CHECK-NEXT:    cjr $c17
; CHECK-NEXT:    cincoffset $c11, $c11, [[STACKFRAME_SIZE]]
entry:
  %call = call i32 @external_func()
  %call2 = call i32 @external_func2()
  %result = add i32 %call, %call2
  ret i32 %result
}

; TODO: could omit this when calling a local func before an external func
; But this could cause subtle bugs when code is reorderd so just always pass $cgp
define i32 @test3() addrspace(200) nounwind {
; CHECK-LABEL: test3:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    cincoffset $c11, $c11, -[[STACKFRAME_SIZE:48|96]]
; CHECK-NEXT:    csd $16, $zero, [[@EXPR STACKFRAME_SIZE - 8]]($c11)
; CHECK-NEXT:    csc $c18, $zero, [[@EXPR 1 * $CAP_SIZE]]($c11)
; CHECK-NEXT:    csc $c17, $zero, 0($c11)
; PCREL-NEXT:    lui $1, %hi(%neg(%captab_rel(test3)))
; PCREL-NEXT:    daddiu $1, $1, %lo(%neg(%captab_rel(test3)))
; PCREL-NEXT:    cincoffset $c18, $c12, $1
; PLT-NEXT:    cmove $c18, $c26
; CHECK-NEXT:    clcbi $c12, %capcall20(local_func)($c18)
; $cgp only needs to be restored when not using the pc-relative ABI
; CHECK-NEXT:    cjalr $c12, $c17
; PLT-NEXT:      cmove $c26, $c18
; PCREL-NEXT:    nop
; PLT-NEXT:      move $16, $2
; CHECK-NEXT:    clcbi $c12, %capcall20(external_func)($c18)
; $cgp only needs to be restored when not using the pc-relative ABI
; CHECK-NEXT:    cjalr $c12, $c17
; PLT-NEXT:      cmove $c26, $c18
; PCREL-NEXT:    move $16, $2
; CHECK-NEXT:    addu $2, $16, $2
; CHECK-NEXT:    clc $c17, $zero, 0($c11)
; CHECK-NEXT:    clc $c18, $zero, [[@EXPR 1 * $CAP_SIZE]]($c11)
; CHECK-NEXT:    cld $16, $zero, [[@EXPR STACKFRAME_SIZE - 8]]($c11)
; CHECK-NEXT:    cjr $c17
; CHECK-NEXT:    cincoffset $c11, $c11, [[STACKFRAME_SIZE]]
entry:
  %call = call i32 @local_func()
  %call2 = call i32 @external_func()
  %result = add i32 %call, %call2
  ret i32 %result
}

; No need to restore $cgp when calling a function pointer since that will always use a trampoline
define i32 @test4() addrspace(200) nounwind {
; CHECK-LABEL: test4:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    cincoffset $c11, $c11, -[[STACKFRAME_SIZE:48|96]]
; CHECK-NEXT:    csd $16, $zero, [[@EXPR STACKFRAME_SIZE - 8]]($c11)
; CHECK-NEXT:    csc $c18, $zero, [[@EXPR 1 * $CAP_SIZE]]($c11)
; CHECK-NEXT:    csc $c17, $zero, 0($c11)
; PCREL-NEXT:    lui $1, %hi(%neg(%captab_rel(test4)))
; PCREL-NEXT:    daddiu $1, $1, %lo(%neg(%captab_rel(test4)))
; PCREL-NEXT:    cincoffset $c18, $c12, $1
; PLT-NEXT:      cmove $c18, $c26
; CHECK-NEXT:    clcbi $c12, %capcall20(external_func)($c18)
; $cgp only needs to be restored when not using the pc-relative ABI
; CHECK-NEXT:    cjalr $c12, $c17
; PLT-NEXT:      cmove $c26, $c18
; PCREL-NEXT:    nop
; CHECK-NEXT:    clcbi $c1, %captab20(fn_ptr)($c18)
; CHECK-NEXT:    clc $c12, $zero, 0($c1)
; CHECK-NEXT:    cjalr $c12, $c17
; CHECK-NEXT:    move $16, $2
; CHECK-NEXT:    addu $2, $16, $2
; CHECK-NEXT:    clc $c17, $zero, 0($c11)
; CHECK-NEXT:    clc $c18, $zero, [[@EXPR 1 * $CAP_SIZE]]($c11)
; CHECK-NEXT:    cld $16, $zero, [[@EXPR STACKFRAME_SIZE - 8]]($c11)
; CHECK-NEXT:    cjr $c17
; CHECK-NEXT:    cincoffset $c11, $c11, [[STACKFRAME_SIZE]]
entry:
  %call = call i32 @external_func()
  %fn = load i32 () addrspace(200)*, i32 () addrspace(200)* addrspace(200)* @fn_ptr, align 32
  %call2 = call i32 %fn()
  %result = add i32 %call, %call2
  ret i32 %result
}


; Some more test cases (not a call but a global variable, etc)
@global = local_unnamed_addr addrspace(200) global i8 123, align 8

declare void @external_call1() addrspace(200)
declare void @external_call2() addrspace(200)
declare i32 @external_i32() addrspace(200)

define i8 addrspace(200)* @access_global_after_external_call() addrspace(200) nounwind {
; CHECK-LABEL: access_global_after_external_call:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    cincoffset $c11, $c11, -[[STACKFRAME_SIZE:32|64]]
; CHECK-NEXT:    csc $c18, $zero, [[@EXPR 1 * $CAP_SIZE]]($c11)
; CHECK-NEXT:    csc $c17, $zero, 0($c11)
; PCREL-NEXT:    lui $1, %hi(%neg(%captab_rel(access_global_after_external_call)))
; PCREL-NEXT:    daddiu $1, $1, %lo(%neg(%captab_rel(access_global_after_external_call)))
; PCREL-NEXT:    cincoffset $c18, $c12, $1
; PLT-NEXT:      cmove $c18, $c26
; CHECK-NEXT:    clcbi $c12, %capcall20(external_call1)($c18)
; CHECK-NEXT:    cjalr $c12, $c17
; PLT-NEXT:      cmove $c26, $c18
; PCREL-NEXT:    nop
; CHECK-NEXT:    clcbi $c3, %captab20(global)($c18)
; CHECK-NEXT:    clc $c17, $zero, 0($c11)
; CHECK-NEXT:    clc $c18, $zero, [[@EXPR 1 * $CAP_SIZE]]($c11)
; CHECK-NEXT:    cjr $c17
; CHECK-NEXT:    cincoffset $c11, $c11, [[STACKFRAME_SIZE]]
; We need to save $cgp before the call so it is moved to $c18 (callee-save)
entry:
  call addrspace(200) void @external_call1()
  ret i8 addrspace(200)* @global
}

define void @call_two_functions() addrspace(200) nounwind {
; CHECK-LABEL: call_two_functions:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    cincoffset $c11, $c11, -[[STACKFRAME_SIZE:32|64]]
; CHECK-NEXT:    csc $c18, $zero, [[@EXPR 1 * $CAP_SIZE]]($c11)
; CHECK-NEXT:    csc $c17, $zero, 0($c11)
; PCREL-NEXT:    lui $1, %hi(%neg(%captab_rel(call_two_functions)))
; PCREL-NEXT:    daddiu $1, $1, %lo(%neg(%captab_rel(call_two_functions)))
; PCREL-NEXT:    cincoffset $c18, $c12, $1
; PLT-NEXT:      cmove $c18, $c26
; CHECK-NEXT:    clcbi $c12, %capcall20(external_call1)($c18)
; CHECK-NEXT:    cjalr $c12, $c17
; PLT-NEXT:      cmove $c26, $c18
; PCREL-NEXT:    nop
; CHECK-NEXT:    clcbi $c12, %capcall20(external_call2)($c18)
; CHECK-NEXT:    cjalr $c12, $c17
; PLT-NEXT:      cmove $c26, $c18
; PCREL-NEXT:    nop
; CHECK-NEXT:    clc $c17, $zero, 0($c11)
; CHECK-NEXT:    clc $c18, $zero, [[@EXPR 1 * $CAP_SIZE]]($c11)
; CHECK-NEXT:    cjr $c17
; CHECK-NEXT:    cincoffset $c11, $c11, [[STACKFRAME_SIZE]]
entry:
  call addrspace(200) void @external_call1()
  call addrspace(200) void @external_call2()
  ret void
}

define i32 @not_needed_after_call(i32 %arg1, i32 %arg2) addrspace(200) nounwind {
; CHECK-LABEL: not_needed_after_call:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    cincoffset $c11, $c11, -[[STACKFRAME_SIZE:32|64]]
; CHECK-NEXT:    csd $17, $zero, {{24|56}}($c11) # 8-byte Folded Spill
; CHECK-NEXT:    csd $16, $zero, {{16|48}}($c11) # 8-byte Folded Spill
; CHECK-NEXT:    csc $c17, $zero, 0($c11)
; CHECK-NEXT:    move $16, $5
; PCREL-NEXT:    lui $1, %hi(%neg(%captab_rel(not_needed_after_call)))
; PCREL-NEXT:    daddiu $1, $1, %lo(%neg(%captab_rel(not_needed_after_call)))
; PCREL-NEXT:    cincoffset $c1, $c12, $1
; CHECK-NEXT:    clcbi $c12, %capcall20(external_call1)($c{{1|26}})
; CHECK-NEXT:    cjalr $c12, $c17
; CHECK-NEXT:    move $17, $4
; CHECK-NEXT:    sll $1, $16, 0
; CHECK-NEXT:    sll $2, $17, 0
; CHECK-NEXT:    addu $2, $2, $1
; CHECK-NEXT:    clc $c17, $zero, 0($c11)
; CHECK-NEXT:    cld $16, $zero, {{16|48}}($c11) # 8-byte Folded Reload
; CHECK-NEXT:    cld $17, $zero, {{24|56}}($c11) # 8-byte Folded Reload
; CHECK-NEXT:    cjr $c17
; CHECK-NEXT:    cincoffset $c11, $c11, [[STACKFRAME_SIZE]]
entry:
  call addrspace(200) void @external_call1()
  %ret = add i32 %arg1, %arg2
  ret i32 %ret
}

define void @tailcall_external(i32 %arg1, i32 %arg2) addrspace(200) nounwind {
; CHECK-LABEL: tailcall_external:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    cincoffset $c11, $c11, -[[STACKFRAME_SIZE:16|32]]
; CHECK-NEXT:    csc $c17, $zero, 0($c11)
; PCREL-NEXT:    lui $1, %hi(%neg(%captab_rel(tailcall_external)))
; PCREL-NEXT:    daddiu $1, $1, %lo(%neg(%captab_rel(tailcall_external)))
; PCREL-NEXT:    cincoffset $c1, $c12, $1
; CHECK-NEXT:    clcbi $c12, %capcall20(external_call1)($c{{1|26}})
; CHECK-NEXT:    cjalr $c12, $c17
; CHECK-NEXT:    nop
; CHECK-NEXT:    clc $c17, $zero, 0($c11)
; CHECK-NEXT:    cjr $c17
; CHECK-NEXT:    cincoffset $c11, $c11, [[STACKFRAME_SIZE]]
entry:
  tail call addrspace(200) void @external_call1()
  ret void
}


; TODO: why can't this be optimized to a jump?
define internal i32 @tailcall_local(i32 %arg1, i32 %arg2) addrspace(200) nounwind {
; CHECK-LABEL: tailcall_local:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    cincoffset $c11, $c11, -[[STACKFRAME_SIZE:16|32]]
; CHECK-NEXT:    csc $c17, $zero, 0($c11)
; PCREL-NEXT:    lui $1, %hi(%neg(%captab_rel(tailcall_local)))
; PCREL-NEXT:    daddiu $1, $1, %lo(%neg(%captab_rel(tailcall_local)))
; PCREL-NEXT:    cincoffset $c1, $c12, $1
; CHECK-NEXT:    clcbi $c12, %capcall20(local_func)($c{{1|26}})
; CHECK-NEXT:    cjalr $c12, $c17
; CHECK-NEXT:    nop
; CHECK-NEXT:    clc $c17, $zero, 0($c11)
; CHECK-NEXT:    cjr $c17
; CHECK-NEXT:    cincoffset $c11, $c11, [[STACKFRAME_SIZE]]
entry:
  %ret = tail call addrspace(200) i32 @local_func()
  ret i32 %ret
}




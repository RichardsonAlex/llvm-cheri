; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: %cheri_llc -o - %s -O2 | FileCheck -check-prefix PURECAP
; RUN: %cheri_purecap_llc -o - %s -O2 | FileCheck -check-prefix HYBRID

; libc++ member pointer calls were broken due to using ctoptr instead of cgetaddr for ptrtoint
; Check that we generate the right ctoptr/cgetaddr

define i64 @test(i8 addrspace(200)* %__vp) {
; PURECAP-LABEL: test:
; PURECAP:       # %bb.0: # %entry
; PURECAP-NEXT:    jr $ra
; PURECAP-NEXT:    ctoptr $2, $c3, $ddc
;
; HYBRID-LABEL: test:
; HYBRID:       # %bb.0: # %entry
; HYBRID-NEXT:    cjr $c17
; HYBRID-NEXT:    cgetaddr $2, $c3
entry:
  %ret = ptrtoint i8 addrspace(200)* %__vp to i64
  ret i64 %ret
}

define i32 @test32(i8 addrspace(200)* %__vp) {
; PURECAP-LABEL: test32:
; PURECAP:       # %bb.0: # %entry
; PURECAP-NEXT:    ctoptr $1, $c3, $ddc
; PURECAP-NEXT:    jr $ra
; PURECAP-NEXT:    sll $2, $1, 0
;
; HYBRID-LABEL: test32:
; HYBRID:       # %bb.0: # %entry
; HYBRID-NEXT:    cgetaddr $1, $c3
; HYBRID-NEXT:    cjr $c17
; HYBRID-NEXT:    sll $2, $1, 0
entry:
  %ret = ptrtoint i8 addrspace(200)* %__vp to i32
  ret i32 %ret
}

define i16 @test16(i8 addrspace(200)* %__vp) {
; PURECAP-LABEL: test16:
; PURECAP:       # %bb.0: # %entry
; PURECAP-NEXT:    ctoptr $1, $c3, $ddc
; PURECAP-NEXT:    jr $ra
; PURECAP-NEXT:    sll $2, $1, 0
;
; HYBRID-LABEL: test16:
; HYBRID:       # %bb.0: # %entry
; HYBRID-NEXT:    cgetaddr $1, $c3
; HYBRID-NEXT:    cjr $c17
; HYBRID-NEXT:    sll $2, $1, 0
entry:
  %ret = ptrtoint i8 addrspace(200)* %__vp to i16
  ret i16 %ret
}

define i32 @trunc(i64 %arg) {
; PURECAP-LABEL: trunc:
; PURECAP:       # %bb.0: # %entry
; PURECAP-NEXT:    jr $ra
; PURECAP-NEXT:    sll $2, $4, 0
;
; HYBRID-LABEL: trunc:
; HYBRID:       # %bb.0: # %entry
; HYBRID-NEXT:    cjr $c17
; HYBRID-NEXT:    sll $2, $4, 0
entry:
  %ret = trunc i64 %arg to i32
  ret i32 %ret
}

//===- PDBSymbolTypeCustom.h - custom compiler type information -*- C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_DEBUGINFO_PDB_PDBSYMBOLTYPECUSTOM_H
#define LLVM_DEBUGINFO_PDB_PDBSYMBOLTYPECUSTOM_H

#include "PDBSymbol.h"
#include "PDBTypes.h"

namespace llvm {

class raw_ostream;
namespace pdb {

class PDBSymbolTypeCustom : public PDBSymbol {
  DECLARE_PDB_SYMBOL_CONCRETE_TYPE(PDB_SymType::CustomType)
public:
  void dump(PDBSymDumper &Dumper) const override;

  FORWARD_SYMBOL_METHOD(getOemId)
  FORWARD_SYMBOL_METHOD(getOemSymbolId)
};

} // namespace llvm
}

#endif // LLVM_DEBUGINFO_PDB_PDBSYMBOLTYPECUSTOM_H

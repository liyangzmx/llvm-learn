// Selected complete records from builtin-records.td; unrelated records omitted.

def Builtin_Integer {	// Constraint TypeConstraint Type DialectType AttrOrTypeDef TypeDef Builtin_Type
  Pred predicate = anonymous_7;
  string summary = "Integer type with arbitrary precision up to a fixed limit";
  string cppClassName = "IntegerType";
  code description = [{
    Syntax:

    ```
    // Sized integers like i1, i4, i8, i16, i32.
    signed-integer-type ::= `si` [1-9][0-9]*
    unsigned-integer-type ::= `ui` [1-9][0-9]*
    signless-integer-type ::= `i` [1-9][0-9]*
    integer-type ::= signed-integer-type |
                     unsigned-integer-type |
                     signless-integer-type
    ```

    Integer types have a designated bit width and may optionally have signedness
    semantics.

    **Rationale:** low precision integers (like `i2`, `i4` etc) are useful for
    low-precision inference chips, and arbitrary precision integers are useful
    for hardware synthesis (where a 13 bit multiplier is a lot cheaper/smaller
    than a 16 bit one).
  }];
  string builderCall = "";
  Dialect dialect = Builtin_Dialect;
  string cppBaseClassName = "::mlir::Type";
  string storageClass = "IntegerTypeStorage";
  string storageNamespace = "detail";
  bit genStorageClass = 0;
  bit hasStorageCustomConstructor = 0;
  dag parameters = (ins "unsigned":$width, "SignednessSemantics":$signedness);
  list<AttrOrTypeBuilder> builders = [anonymous_346];
  list<Trait> traits = [];
  string mnemonic = ?;
  string assemblyFormat = ?;
  bit hasCustomAssemblyFormat = 0;
  bit genAccessors = 1;
  bit skipDefaultBuilders = 1;
  bit genVerifyDecl = 1;
  code extraClassDeclaration = [{
    /// Signedness semantics.
    enum SignednessSemantics : uint32_t {
      Signless, /// No signedness semantics
      Signed,   /// Signed integer
      Unsigned, /// Unsigned integer
    };

    /// Return true if this is a signless integer type.
    bool isSignless() const { return getSignedness() == Signless; }
    /// Return true if this is a signed integer type.
    bool isSigned() const { return getSignedness() == Signed; }
    /// Return true if this is an unsigned integer type.
    bool isUnsigned() const { return getSignedness() == Unsigned; }

    /// Get or create a new IntegerType with the same signedness as `this` and a
    /// bitwidth scaled by `scale`.
    /// Return null if the scaled element type cannot be represented.
    IntegerType scaleElementBitwidth(unsigned scale);

    /// Integer representation maximal bitwidth.
    /// Note: This is aligned with the maximum width of llvm::IntegerType.
    static constexpr unsigned kMaxWidth = (1 << 24) - 1;
  }];
  code extraClassDefinition = [{}];
  string cppType = "::mlir::IntegerType";
  string typeName = "builtin.integer";
}

def anonymous_345 {	// CArg
  string type = "SignednessSemantics";
  string defaultValue = "Signless";
}

def anonymous_346 {	// AttrOrTypeBuilder TypeBuilder
  dag dagParams = (ins "unsigned":$width, anonymous_345:$signedness);
  string body = "";
  string returnType = "";
  bit hasInferredContextParam = 0;
}

// Selected complete records from arith-records.td; unrelated records omitted.

def Arith_AddIOp {	// Op Arith_Op Arith_ArithOp Arith_BinaryOp Arguments Results Arith_IntBinaryOpWithOverflowFlags
  Dialect opDialect = Arith_Dialect;
  string opName = "addi";
  string cppNamespace = "::mlir::arith";
  string summary = "integer addition operation";
  code description = [{
    Performs N-bit addition on the operands. The operands are interpreted as 
    unsigned bitvectors. The result is represented by a bitvector containing the 
    mathematical value of the addition modulo 2^n, where `n` is the bitwidth. 
    Because `arith` integers use a two's complement representation, this operation 
    is applicable on both signed and unsigned integer operands.

    The `addi` operation takes two operands and returns one result, each of
    these is required to be the same type. This type may be an integer scalar type, 
    a vector whose element type is integer, or a tensor of integers.

    This op supports `nuw`/`nsw` overflow flags which stands stand for
    "No Unsigned Wrap" and "No Signed Wrap", respectively. If the `nuw` and/or
    `nsw` flags are present, and an unsigned/signed overflow occurs
    (respectively), the result is poison.

    Example:

    ```mlir
    // Scalar addition.
    %a = arith.addi %b, %c : i64

    // Scalar addition with overflow flags.
    %a = arith.addi %b, %c overflow<nsw, nuw> : i64

    // SIMD vector element-wise addition.
    %f = arith.addi %g, %h : vector<4xi32>

    // Tensor element-wise addition.
    %x = arith.addi %y, %z : tensor<4x?xi8>
    ```
  }];
  OpDocGroup opDocGroup = ?;
  dag arguments = (ins SignlessIntegerLike:$lhs, SignlessIntegerLike:$rhs, anonymous_458:$overflowFlags);
  dag results = (outs SignlessIntegerLike:$result);
  dag regions = (region);
  dag successors = (successor);
  list<OpBuilder> builders = ?;
  bit skipDefaultBuilders = 0;
  code assemblyFormat = [{ $lhs `,` $rhs (`overflow` `` $overflowFlags^)?
                          attr-dict `:` type($result) }];
  bit hasCustomAssemblyFormat = 0;
  bit hasVerifier = 0;
  bit hasRegionVerifier = 0;
  bit hasCanonicalizer = 1;
  bit hasCanonicalizeMethod = 0;
  bit hasFolder = 1;
  bit useCustomPropertiesEncoding = 0;
  list<Trait> traits = [Commutative, Pure, anonymous_442, anonymous_457, SameOperandsAndResultType, anonymous_441, NoMemoryEffect, Elementwise, Scalarizable, Vectorizable, Tensorizable];
  string extraClassDeclaration = ?;
  string extraClassDefinition = ?;
}

def anonymous_441 {	// DeclareInterfaceMethods Interface Trait NativeTrait InterfaceTrait OpInterfaceTrait OpInterface DeclareOpInterfaceMethods
  list<string> alwaysOverriddenMethods = [];
  code description = [{
    Encodes properties of an operation on vectors that can be unrolled.
  }];
  string cppInterfaceName = "VectorUnrollOpInterface";
  string cppNamespace = "::mlir";
  list<InterfaceMethod> methods = [anonymous_419];
  string extraClassDeclaration = "";
  string extraSharedClassDeclaration = "";
  string extraClassOf = "";
  list<Interface> baseInterfaces = [];
  string trait = "VectorUnrollOpInterface::Trait";
  code extraConcreteClassDeclaration = [{}];
  code extraConcreteClassDefinition = [{}];
  string extraTraitClassDeclaration = "";
  code verify = [{}];
  bit verifyWithRegions = 0;
  list<Trait> dependentTraits = [];
}

def anonymous_442 {	// DeclareInterfaceMethods Interface Trait NativeTrait InterfaceTrait OpInterfaceTrait OpInterface DeclareOpInterfaceMethods
  list<string> alwaysOverriddenMethods = [];
  code description = [{
    Allows operations to participate in range analysis for scalar integer values by
    providing a methods that allows them to specify lower and upper bounds on their
    result(s) given lower and upper bounds on their input(s) if known.
  }];
  string cppInterfaceName = "InferIntRangeInterface";
  string cppNamespace = "::mlir";
  list<InterfaceMethod> methods = [anonymous_400];
  string extraClassDeclaration = "";
  string extraSharedClassDeclaration = "";
  string extraClassOf = "";
  list<Interface> baseInterfaces = [];
  string trait = "InferIntRangeInterface::Trait";
  code extraConcreteClassDeclaration = [{}];
  code extraConcreteClassDefinition = [{}];
  string extraTraitClassDeclaration = "";
  code verify = [{}];
  bit verifyWithRegions = 0;
  list<Trait> dependentTraits = [];
}

def anonymous_457 {	// DeclareInterfaceMethods Interface Trait NativeTrait InterfaceTrait OpInterfaceTrait OpInterface DeclareOpInterfaceMethods
  list<string> alwaysOverriddenMethods = [];
  code description = [{
    Access to op integer overflow flags.
  }];
  string cppInterfaceName = "ArithIntegerOverflowFlagsInterface";
  string cppNamespace = "::mlir::arith";
  list<InterfaceMethod> methods = [anonymous_395, anonymous_396, anonymous_397, anonymous_398];
  string extraClassDeclaration = "";
  string extraSharedClassDeclaration = "";
  string extraClassOf = "";
  list<Interface> baseInterfaces = [];
  string trait = "ArithIntegerOverflowFlagsInterface::Trait";
  code extraConcreteClassDeclaration = [{}];
  code extraConcreteClassDefinition = [{}];
  string extraTraitClassDeclaration = "";
  code verify = [{}];
  bit verifyWithRegions = 0;
  list<Trait> dependentTraits = [];
}

def anonymous_458 {	// Constraint AttrConstraint Attr DefaultValuedAttr
  Pred predicate = anonymous_392;
  string summary = "Integer overflow arith flags";
  string storageType = "::mlir::arith::IntegerOverflowFlagsAttr";
  string returnType = "::mlir::arith::IntegerOverflowFlags";
  string convertFromStorage = "$_self.getValue()";
  string constBuilderCall = "::mlir::arith::IntegerOverflowFlagsAttr::get($_builder.getContext(), $0)";
  string defaultValue = "::mlir::arith::IntegerOverflowFlags::none";
  Type valueType = ?;
  bit isOptional = 0;
  Attr baseAttr = Arith_IntegerOverflowAttr;
  string cppNamespace = "";
  string description = "";
}

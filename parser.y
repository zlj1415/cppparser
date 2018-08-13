/*
The MIT License (MIT)

Copyright (c) 2014

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

%{
#include "cpptoken.h"
#include "cppdom.h"
#include "parser.tab.h"
#include "cppobjfactory.h"

#include <stack>

//////////////////////////////////////////////////////////////////////////

#ifndef NDEBUG
#  define YYDEBUG 1
#else 
#  define YYDEBUG 0
#endif //#ifndef NDEBUG

#define YYERROR_DETAILED

#define YYDELETEPOSN(x, y)
#define YYDELETEVAL(x, y)

#ifndef TRUE // Need this to fix BtYacc compilation error.
#  define TRUE true
#endif

static int gLog = 0;
#define ZZVALID   \
  if (gLog) \
    printf("YYVALID @line#%d\n", __LINE__); \
  YYVALID
  
/** {Globals} */
/**
 * A program unit is the entire parse tree of a source/header file
 */
static CppCompound*  gProgUnit;

/**
 * A stack to know where (i.e. how deep inside class defnition) the current parsing activity is taking place.
 */
typedef std::stack<CppToken>        CppCompoundStack;
static CppCompoundStack             gCompoundStack;

static CppObjProtLevel              gCurProtLevel;
static std::stack<CppObjProtLevel>  gProtLevelStack;

extern CppObjFactory*               gObjFactory;

/** {End of Globals} */

template<typename... Params>
CppCompound* newCompound(Params... params)
{
  return gObjFactory->CreateCompound(params...);
}

template<typename... Params>
CppConstructor* newConstructor(Params... params)
{
  return gObjFactory->CreateConstructor(params...);
}

template<typename... Params>
CppDestructor* newDestructor(Params... params)
{
  return gObjFactory->CreateDestructor(params...);
}

template<typename... Params>
CppFunction* newFunction(Params... params)
{
  return gObjFactory->CreateFunction(params...);
}

#define YYPOSN char*
/**
 * To track the line being parsed so that we can emit precise location of parsing error.
 */
int gLineNo = 1;

extern int yylex();

// Yacc generated code causes warnings that need suppression.
// This pragma should be at the end.
#if defined(__clang__) || defined(__GNUC__)
# pragma GCC diagnostic ignored "-Wwrite-strings"
#endif

%}

%union {
  CppToken              str;
  CppObj*               cppObj;
  CppTypeModifier       typeModifier;
  CppVarType*           cppVarType;
  CppVar*               cppVarObj;
  CppEnum*              cppEnum;
  CppEnumItem*          enumItem;
  CppEnumItemList*      enumItemList;
  CppTypedefName*       typedefName;
  CppTypedefList*       typedefList;
  CppUsingDecl*         usingDecl;
  CppUsingNamespaceDecl*  usingNamespaceDecl;
  CppCompound*          cppCompundObj;
  CppTemplateArgList*   templSpec;
  CppTemplateArg*       templArg;
  CppDocComment*        docCommentObj;
  CppFwdClsDecl*        fwdDeclObj;
  CppVarList*           cppVarObjList;
  CppUnRecogPrePro*     unRecogPreProObj;
  CppExpr*              cppExprObj;
  CppFunction*          cppFuncObj;
  CppFunctionPtr*       cppFuncPointerObj;
  CppVarOrFuncPtrType   varOrFuncPtr;
  CppParamList*         paramList;
  CppConstructor*       cppCtorObj;
  CppDestructor*        cppDtorObj;
  CppTypeCoverter*      cppTypeConverter;
  CppMemInitList*       memInitList;
  CppInheritanceList*   inheritList;
  CppIdentifierList*    identifierList;
  CppFuncThrowSpec*     funcThrowSpec;
  CppCompoundType       compoundType;
  unsigned short        ptrLevel;
  CppRefType            refType;
  unsigned int          attr;
  CppObjProtLevel       protLevel;

  CppExprList*          exprList;

  CppIfBlock*           ifBlock;
  CppWhileBlock*        whileBlock;
  CppDoWhileBlock*      doWhileBlock;
  CppForBlock*          forBlock;
  CppSwitchBlock*       switchBlock;
  CppSwitchBody*        switchBody;

  CppDefine*            hashDefine;
  CppUndef*             hashUndef;
  CppInclude*           hashInclude;
  CppHashIf*            hashIf;
  CppPragma*            hashPragma;
}

%token  <str>   tknID tknStrLit tknCharLit tknNumber
%token  <str>   tknTypedef tknUsing
%token  <str>   tknLong
%token  <str>   tknEnum
%token  <str>   tknPreProDef
%token  <str>   tknClass tknStruct tknUnion tknNamespace
%token  <str>   tknTemplate tknTypename
%token  <str>   tknDocBlockComment tknDocLineComment
%token  <str>   tknScopeResOp
%token  <str>   tknNumSignSpec // signed/unsigned
%token  <str>   tknPublic tknProtected tknPrivate
%token  <str>   tknExternC
%token  <str>   tknUnRecogPrePro
%token  <str>   tknStdHdrInclude
%token  <str>   tknPragma
%token  <str>   tknEllipsis
%token  <str>   tknConstCast tknStaticCast tknDynamicCast tknReinterpretCast
%token  <str>   tknTry tknCatch tknThrow
%token  <str>   tknOperator tknPlusEq tknMinusEq tknMulEq tknDivEq tknPerEq tknXorEq tknAndEq tknOrEq
%token  <str>   tknLShift tknRShift tknLShiftEq tknRShiftEq tknCmpEq tknNotEq tknLessEq tknGreaterEq
%token  <str>   tkn3WayCmp tknAnd tknOr tknInc tknDec tknArrow tknArrowStar
%token  <str>   '<' '>' // We will need the position of these operators in stream when used for declaring template instance.
%token  <str>   '+' '-' '*' '/' '%' '^' '&' '|' '~' '!' '=' ',' '(' ')' '[' ']'
%token  <str>   tknNew tknDelete
%token  <str>   tknConst // For templateparam parsing it is made as str type.
%token  <str>   tknVoid // For the cases when void is used as function parameter.

%token  tknStatic tknExtern tknVirtual tknOverride tknInline tknExplicit tknFriend tknVolatile tknFinal tknNoExcept

%token  tknPreProHash /* When # is encountered for pre processor definition */
%token  tknDefine tknUndef
%token  tknInclude tknStdHdrInclude
%token  tknIf tknIfDef tknIfNDef tknElse tknElIf tknEndIf
%token  tknFor tknWhile tknDo tknSwitch tknCase tknDefault
%token  tknReturn

%token  tknBlankLine

%type  <str>                optapidocer apidocer
%type  <str>                identifier typeidentifier templidentifier optid basefuncname funcname typenamespecifier
%type  <str>                doccommentstr
%type  <cppObj>             stmt functptrtype
%type  <typeModifier>       typemodifier
%type  <cppEnum>            enumdefn enumfwddecl
%type  <enumItem>           enumitem
%type  <enumItemList>       enumitemlist
%type  <fwdDeclObj>         fwddecl
%type  <cppVarType>         vartype
%type  <cppVarObj>          vardecl varinit vardeclstmt
%type  <varOrFuncPtr>       param
%type  <str>                templateparam templateparamlist /* For time being. We may need to make it more robust in future. */
%type  <cppVarObjList>      vardecllist vardeclliststmt
%type  <paramList>          paramlist
%type  <typedefName>        typedefname typedefnamestmt
%type  <typedefList>        typedeflist typedefliststmt
%type  <usingNamespaceDecl> usingnamespacedecl
%type  <usingDecl>          usingdecl
%type  <cppCompundObj>      stmtlist progunit classdefn classdefnstmt externcblock block
%type  <templSpec>          templatespecifier temparglist
%type  <templArg>           temparg tempargwodefault tempargwdefault
%type  <docCommentObj>      doccomment
%type  <cppExprObj>         expr exprstmt optexpr
%type  <ifBlock>            ifblock;
%type  <whileBlock>         whileblock;
%type  <doWhileBlock>       dowhileblock;
%type  <forBlock>           forblock;
%type  <switchBlock>        switchstmt;
%type  <switchBody>         caselist;
%type  <cppFuncPointerObj>  functionpointer funcpointerdecl
%type  <cppFuncObj>         funcdecl funcdeclstmt funcdefn
%type  <cppCtorObj>         ctordecl ctordeclstmt ctordefn
%type  <cppDtorObj>         dtordecl dtordeclstmt dtordefn
%type  <cppTypeConverter>   typeconverter typeconverterstmt
%type  <memInitList>        meminitlist
%type  <compoundType>       compoundSpecifier
%type  <attr>               optattr varattrib exptype funcattrib functype
%type  <inheritList>        inheritlist
%type  <protLevel>          protlevel changeprotlevel
%type  <identifierList>     identifierlist
%type  <funcThrowSpec>      functhrowspec

%type  <exprList>           exprlist
%type  <hashDefine>         define
%type  <hashUndef>          undef
%type  <hashInclude>        include
%type  <hashIf>             hashif
%type  <hashPragma>         pragma

%right  '=' CMPEQUAL
%left   '+' '-'
%left   '*' '/' '%'
%right  LSHIFT RSHIFT
%left   '&' '|'
%left   '.' ARROW

%nonassoc PREFIX
%nonassoc POSTFIX '(' '['

/*
These are required to remove following ambiguity in the grammer.
Consider the following example:
  x * y;
Now it can be parsed as:
  (1) y is a pointer to type-x.
  (2) Or, the expression is multiplication of x and y.
Same ambiguity exists for:
  x * y = z;
  x & y;
  x & y = z;
  x && y;
  x && y = z;
PTRDECL and REFDECL solve this problem by giving variable declaration higher precedence.
*/
%left PTRDECL REFDECL

/*
These are required to remove following ambiguity in the grammer.
Consider the following example:
  class A
  {
    A();  // ctor declaration
    ~A(); // dtor declaration
  };

Now A() can be parsed in two different ways:
  (1) As a constructor declaration.
  (2) Or, as a function call.
Also, ~A() can be parsed as:
  (1) As a destructor declaration.
  (2) Or, as an expression where bit toggle operation is done on a return value of function call.
CTORDECL and DTORDECL solve this problem by giving constructor and destructor declarations higher precedence.
*/
%left CTORDECL DTORDECL


%%

/* A program unit is a source file, be it header file or implementation file */
progunit          : stmtlist  {
                    gProgUnit = $$ = $1;
                    if (gProgUnit)
                      gProgUnit->compoundType_ = kCppFile;
                  }
                  ;

stmtlist          : { $$ = 0; }
                  | stmt {
                    $$ = newCompound(gProtLevelStack.empty() ? gCurProtLevel : gProtLevelStack.top());
                    if ($1)
                    {
                      $1->owner_ = $$;
                      $$->addMember($1);
                    }
                  }
                  | stmtlist stmt {
                    $$ = ($1 == 0) ? newCompound(gProtLevelStack.empty() ? gCurProtLevel : gProtLevelStack.top()) : $1;
                    if ($2)
                    {
                      $2->owner_ = $$;
                      $$->addMember($2);
                    }
                  }
                  | stmtlist changeprotlevel { $$ = $1; gCurProtLevel = $2; } // Change of protection level is not a statement but this way it is easier to implement.
                  ;

stmt              : vardeclstmt     { $$ = $1; }
                  | vardeclliststmt { $$ = $1; }
                  | enumdefn        { $$ = $1; }
                  | enumfwddecl     { $$ = $1; }
                  | typedefnamestmt { $$ = $1; }
                  | typedefliststmt { $$ = $1; }
                  | classdefnstmt   { $$ = $1; }
                  | fwddecl         { $$ = $1; }
                  | doccomment      { $$ = $1; }
                  | exprstmt        { $$ = $1; }
                  | ifblock         { $$ = $1; }
                  | whileblock      { $$ = $1; }
                  | dowhileblock    { $$ = $1; }
                  | forblock        { $$ = $1; }
                  | funcpointerdecl { $$ = $1; }
                  | funcdeclstmt    { $$ = $1; }
                  | funcdefn        { $$ = $1; }
                  | ctordeclstmt    { $$ = $1; }
                  | ctordefn        { $$ = $1; }
                  | dtordeclstmt    { $$ = $1; }
                  | dtordefn        { $$ = $1; }
                  | typeconverterstmt { $$ = $1; }
                  | externcblock    { $$ = $1; }
                  | functptrtype    { $$ = $1; }
                  | define          { $$ = $1; }
                  | undef           { $$ = $1; }
                  | include         { $$ = $1; }
                  | hashif          { $$ = $1; }
                  | pragma          { $$ = $1; }
                  | block           { $$ = $1; }
                  | switchstmt      { $$ = $1; }
                  | usingdecl       { $$ = $1; }
                  | usingnamespacedecl { $$ = $1; }
                  | ';' /* blank statement */ { $$ = nullptr; }
                  ;

switchstmt        : tknSwitch '(' expr ')' '{' caselist '}' {
                    $$ = new CppSwitchBlock($3, $6);
                  }
                  ;

caselist          : {
                    $$ = new CppSwitchBody;
                  }
                  | caselist tknCase expr ':' stmtlist {
                    $$ = $1;
                    $$->emplace_back($3, $5);
                  }
                  | caselist tknDefault ':' stmtlist {
                    $$ = $1;
                    $$->emplace_back(nullptr, $4);
                  }
                  ;

block             : '{' stmtlist '}' {
                    $$ = $2 ? $2 : newCompound(kUnknownProt, kBlock);
                  }
                  | doccomment block {
                    $$ = $2;
                  }
                  ;

ifblock           : tknIf '(' expr ')' stmt {
                    $$ = new CppIfBlock($3);
                    $$->body_ = $5;
                  }
                  | ifblock tknElse stmt {
                    $$ = $1;
                    $$->else_ = $3;
                  }
                  ;

whileblock        : tknWhile '(' expr ')' stmt {
                    $$ = new CppWhileBlock($3);
                    $$->body_ = $5;
                  }
                  ;

dowhileblock      : tknDo stmt tknWhile '(' expr ')' {
                    $$ = new CppDoWhileBlock($5);
                    $$->body_ = $2;
                  }
                  ;

forblock          : tknFor '(' optexpr ';' optexpr ';' optexpr ')' stmt {
                    $$ = new CppForBlock($3, $5, $7, $9);
                  }
                  | tknFor '(' varinit ';' optexpr ';' optexpr ')' stmt {
                    $$ = new CppForBlock($3, $5, $7, $9);
                  }
;

optexpr           : {
                    $$ = nullptr;
                  }
                  | expr {
                    $$ = $1;
                  }
                  ;

define            : tknPreProHash tknDefine tknID tknID         [ZZVALID;] { // Simple rename using #define
                    $$ = new CppDefine($3, $4);
                    $$->defType_ = CppDefine::kRename;
                  }
                  | tknPreProHash tknDefine tknID               [ZZVALID;] { // blank define
                    $$ = new CppDefine($3);
                    $$->defType_ = CppDefine::kRename;
                  }
                  | tknPreProHash tknDefine tknID tknNumber     [ZZVALID;] {// Constant definition
                    $$ = new CppDefine($3, $4);
                    $$->defType_ = CppDefine::kConstNumDef;
                  }
                  | tknPreProHash tknDefine tknID tknStrLit     [ZZVALID;] {
                    $$ = new CppDefine($3, $4);
                    $$->defType_ = CppDefine::kConstStrDef;
                  }
                  | tknPreProHash tknDefine tknID tknCharLit    [ZZVALID;] {
                    $$ = new CppDefine($3, $4);
                    $$->defType_ = CppDefine::kConstCharDef;
                  }
                  | tknPreProHash tknDefine tknID tknPreProDef  [ZZVALID;] {
                    $$ = new CppDefine($3, $4);
                    $$->defType_ = CppDefine::kComplexMacro;
                  }
                  ;

undef             : tknPreProHash tknUndef tknID                [ZZVALID;]  { $$ = new CppUndef($3); }
                  ;

include           : tknPreProHash tknInclude tknStrLit          [ZZVALID;]  { $$ = new CppInclude((std::string) $3); }
                  | tknPreProHash tknInclude tknStdHdrInclude   [ZZVALID;]  { $$ = new CppInclude((std::string) $3); }
                  ;
/*
preprocessor    : tknPreProHash tknUnRecogPrePro tknPreProDef { $$ = new CppUnRecogPrePro((std::string) $2, (std::string) $3); }
          ;
*/
hashif            : tknPreProHash tknIf tknPreProDef            [ZZVALID;]  { $$ = new CppHashIf(CppHashIf::kIf,      $3); }
                  | tknPreProHash tknIfDef tknID                [ZZVALID;]  { $$ = new CppHashIf(CppHashIf::kIfDef,   $3); }
                  | tknPreProHash tknIfNDef tknID               [ZZVALID;]  { $$ = new CppHashIf(CppHashIf::kIfNDef,  $3); }
                  | tknPreProHash tknElse                       [ZZVALID;]  { $$ = new CppHashIf(CppHashIf::kElse       ); }
                  | tknPreProHash tknElIf  tknPreProDef         [ZZVALID;]  { $$ = new CppHashIf(CppHashIf::kElIf,    $3); }
                  | tknPreProHash tknEndIf                      [ZZVALID;]  { $$ = new CppHashIf(CppHashIf::kEndIf      ); }
                  ;

pragma            : tknPreProHash tknPragma tknPreProDef        [ZZVALID;]  { $$ = new CppPragma($3); }
                  ;

doccomment        : doccommentstr  [ZZVALID;] { $$ = new CppDocComment((std::string) $1, gCurProtLevel); }
                  ;

doccommentstr     : tknDocBlockComment  [ZZVALID;] { $$ = $1; }
                  | tknDocLineComment   [ZZVALID;] { $$ = $1; }
                  | doccommentstr tknDocBlockComment [ZZVALID;] { $$ = mergeCppToken($1, $2); }
                  | doccommentstr tknDocLineComment  [ZZVALID;] { $$ = mergeCppToken($1, $2); }
                  ;

identifier        : tknID                                 { $$ = $1; }
                  | tknScopeResOp identifier              { $$ = mergeCppToken($1, $2); }
                  | identifier tknScopeResOp identifier   { $$ = mergeCppToken($1, $3); }
                  | templidentifier                       { $$ = $1; }
                  ;

typeidentifier    : identifier                            { $$ = $1; }
                  | tknLong                               { $$ = $1; }
                  | tknVoid                               { $$ = $1; }
                  | tknLong typeidentifier                { $$ = mergeCppToken($1, $2); }
                  | tknNumSignSpec                        { $$ = $1; }
                  | tknNumSignSpec typeidentifier         { $$ = mergeCppToken($1, $2); }
                  | tknClass identifier                   { $$ = mergeCppToken($1, $2); }
                  | tknStruct identifier                  { $$ = mergeCppToken($1, $2); }
                  | tknUnion identifier                   { $$ = mergeCppToken($1, $2); }
                  | tknEnum  identifier                   { $$ = mergeCppToken($1, $2); }
                  | tknEllipsis                           { $$ = $1; }
                  | identifier tknEllipsis                { $$ = mergeCppToken($1, $2); }
                  ;

templidentifier   : identifier '<' templateparamlist '>' {
                    $$ = mergeCppToken($1, $4);
                  }
                  ;

optid             : { $$ = makeCppToken(nullptr, 0U); }
                  | tknID      { $$ = $1; }
                  ;

enumitem          : tknID           { $$ = new CppEnumItem($1);     }
                  | tknID '=' expr  { $$ = new CppEnumItem($1, $3); }
                  | doccomment      { $$ = new CppEnumItem($1);     }
                  | hashif          { $$ = new CppEnumItem($1);     }
                  ;

enumitemlist      : { $$ = 0; }
                  | enumitemlist enumitem {
                    $$ = $1 ? $1 : new CppEnumItemList;
                    $$->push_back($2);
                  }
                  | enumitemlist ',' enumitem {
                    $$ = $1 ? $1 : new CppEnumItemList;
                    $$->push_back($3);
                  }
                  | enumitemlist ',' {
                    $$ = $1;
                  }
                  ;

enumdefn          : tknEnum optid '{' enumitemlist '}' ';'                          [ZZVALID;] {
                    $$ = new CppEnum(gCurProtLevel, $2, $4);
                  }
                  | tknEnum tknID ':' identifier '{' enumitemlist '}' ';'           [ZZVALID;] {
                    $$ = new CppEnum(gCurProtLevel, $2, $6, false, $4);
                  };
                  | tknEnum tknClass tknID ':' identifier '{' enumitemlist '}' ';'  [ZZVALID;] {
                    $$ = new CppEnum(gCurProtLevel, $3, $7, true, $5);
                  }
                  | tknEnum tknClass tknID '{' enumitemlist '}' ';'                 [ZZVALID;] {
                    $$ = new CppEnum(gCurProtLevel, $3, $5, true);
                  }
                  | tknTypedef tknEnum optid '{' enumitemlist '}' tknID ';'         [ZZVALID;] {
                    $$ = new CppEnum(gCurProtLevel, $7, $5);
                  }

enumfwddecl       : tknEnum tknID ':' identifier ';'                                [ZZVALID;] {
                    $$ = new CppEnum(gCurProtLevel, $2, nullptr, false, $4);
                  }
                  | tknEnum tknClass tknID ':' identifier ';'                       [ZZVALID;] {
                    $$ = new CppEnum(gCurProtLevel, $3, nullptr, true, $5);
                  }
                  | tknEnum tknClass tknID ';'                                      [ZZVALID;] {
                    $$ = new CppEnum(gCurProtLevel, $3, nullptr, true);
                  }
                  ;

typedefnamestmt   : typedefname ';'     [ZZVALID;] { $$ = $1; }
                  ;

typedefliststmt   : typedeflist ';' [ZZVALID;] { $$ = $1; }
                  ;

typedeflist       : tknTypedef vardecllist { $$ = new CppTypedefList($2); }
                  ;

typedefname       : tknTypedef vardecl { $$ = new CppTypedefName($2); }
                  ;

usingdecl         : tknUsing tknID '=' vartype ';' {
                    $$ = new CppUsingDecl($2, $4);
                  }
                  | tknUsing tknID '=' functionpointer ';' {
                    $$ = new CppUsingDecl($2, $4);
                  }
                  | tknUsing tknID '=' classdefn ';' {
                    $$ = new CppUsingDecl($2, $4);
                  }
                  ;

usingnamespacedecl: tknUsing tknNamespace identifier ';' {
                    $$ = new CppUsingNamespaceDecl($3);
                  }
                  ;

vardeclliststmt   : vardecllist ';' [ZZVALID;] { $$ = $1; }
                  ;

vardeclstmt       : vardecl ';'             [ZZVALID;] { $$ = $1; }
                  | varinit ';'             [ZZVALID;] { $$ = $1; }
                  | optapidocer vardecl ';' [ZZVALID;] { $$ = $2; $$->apidocer_ = $1; }
                  | exptype vardeclstmt     [ZZVALID;] { $$ = $2; $$->varType_->typeAttr_ |= $1; }
                  | optapidocer exptype vardeclstmt     [ZZVALID;] {
                    $$ = $3;
                    $$->varType_->typeAttr_ |= $2;
                    $$->apidocer_ = $1;
                  }
                  ;

vardecllist       : typeidentifier typemodifier tknID ',' typemodifier tknID {
                    $$ = new CppVarList($1);
                    $$->addVarDecl(CppVarDeclInList($2, {$3}));
                    $$->addVarDecl(CppVarDeclInList($5, {$6}));
                  }
                  | vardecllist ',' typemodifier tknID {
                    $$ = $1;
                    $$->addVarDecl(CppVarDeclInList($3, {$4}));
                  }
                  ;

varinit           : vardecl '=' expr {
                    $$ = $1;
                    $$->varDecl_.assign_.reset($3);
                  }
                  ;

vardecl           : vartype tknID {
                    $$ = new CppVar($1, $2.toString());
                  }
                  | classdefn tknID {
                    $$ = new CppVar($1, $2.toString());
                  }
                  | vardecl '[' expr ']' {
                    $$ = $1;
                    $$->varDecl_.arraySizes_.push_back(std::unique_ptr<CppExpr>($3));
                  }
                  | vardecl '[' ']' {
                    $$ = $1;
                    $$->varDecl_.arraySizes_.push_back(nullptr);
                  }
                  | vardecl ':' expr {
                    $$ = $1;
                    $$->varDecl_.bitField_.reset($3);
                  }
                  ;

vartype           : typeidentifier typemodifier {
                    $$ = new CppVarType(gCurProtLevel, $1, $2);
                  }
                  | varattrib vartype {
                    $$ = $2;
                    $$->typeAttr_ |= $1;
                  }
                  ;

typemodifier      : { $$ = CppTypeModifier(); }
                  | typemodifier tknConst {
                    $$ = $1;
                    $$.constBits_ |= (1 << $$.ptrLevel_);
                  }
                  | typemodifier '*' %prec PTRDECL {
                    $$ = $1;
                    $$.ptrLevel_++;
                  }
                  | typemodifier '&' %prec REFDECL {
                    $$ = $1;
                    $$.refType_ = kByRef;
                  }
                  | typemodifier tknAnd %prec REFDECL {
                    $$ = $1;
                    $$.refType_ = kRValRef;
                  }
                  ;

exptype           : tknStatic  { $$ = kStatic;  }
                  | tknExtern  { $$ = kExtern;  }
                  | tknExternC { $$ = kExternC; }
                  ;

varattrib         : tknConst    { $$ = kConst; }
                  | tknVolatile { $$ = kVolatile; }
                  ;

typeconverter     : tknOperator vartype '(' optvoid ')' {
                    $$ = new CppTypeCoverter($2, std::string());
                  }
                  | identifier tknScopeResOp tknOperator vartype '(' optvoid ')' {
                    $$ = new CppTypeCoverter($4, mergeCppToken($1, $2));
                  }
                  | functype tknOperator vartype '(' optvoid ')' {
                    $$ = new CppTypeCoverter($3, std::string());
                    $$->attr_ |= $1;
                  }
                  | functype apidocer tknOperator vartype '(' optvoid ')' {
                    $$ = new CppTypeCoverter($4, std::string());
                    $$->attr_ |= $1;
                    $$->apidocer_ = $2;
                  }
                  | functype identifier tknScopeResOp tknOperator vartype '(' optvoid ')' {
                    $$ = new CppTypeCoverter($5, mergeCppToken($2, $3));
                    $$->attr_ |= $1;
                  }
                  | typeconverter tknConst {
                    $$ = $1;
                    $$->attr_ |= kConst;
                  }
                  | apidocer typeconverter {
                    $$ = $2;
                    $$->apidocer_ = $1;
                  }
                  ;

typeconverterstmt : typeconverter ';' [ZZVALID;] {
                    $$ = $1;
                  }
                  | typeconverter block [ZZVALID;] {
                    $$ = $1;
                    $$->defn_ = $2;
                  }
                  ;

funcdeclstmt      : funcdecl ';' [ZZVALID;] { $$ = $1; }
                  ;

funcdefn          : funcdecl block [ZZVALID;] {
                    $$ = $1;
                    $$->defn_ = $2 ? $2 : newCompound(kUnknownProt, kBlock);
                  }
                  ;

functptrtype      : tknTypedef functionpointer ';' [ZZVALID;] {
                    $2->attr_ |= kTypedef;
                    $$ = $2;
                  }

functionpointer   : optapidocer functype vartype '(' optapidocer '*' optid ')' '(' paramlist ')' {
                    $$ = new CppFunctionPtr(gCurProtLevel, $7, $3, $10, $2);
                    $$->docer1_ = $1;
                    $$->docer2_ = $5;
                  }
                  | optapidocer vartype '(' optapidocer '*' optid ')' '(' paramlist ')' {
                    $$ = new CppFunctionPtr(gCurProtLevel, $6, $2, $9, 0);
                    $$->docer1_ = $1;
                    $$->docer2_ = $4;
                  }
                  ;

funcpointerdecl   : functionpointer ';' [ZZVALID;] { $$ = $1;}
                  ;

funcdecl          : functype optapidocer vartype optapidocer funcname '(' paramlist ')' funcattrib {
                    $$ = newFunction(gCurProtLevel, $5, $3, $7, $1 | $9);
                    $$->docer1_ = $2;
                    $$->docer2_ = $4;
                  }
                  | optapidocer functype vartype optapidocer funcname '(' paramlist ')' funcattrib {
                    $$ = newFunction(gCurProtLevel, $5, $3, $7, $2 | $9);
                    $$->docer1_ = $1;
                    $$->docer2_ = $4;
                  }

                  | optapidocer vartype optapidocer funcname '(' paramlist ')' funcattrib {
                    $$ = newFunction(gCurProtLevel, $4, $2, $6, $8);
                    $$->docer1_ = $1;
                    $$->docer2_ = $3;
                  }
                  | templatespecifier funcdecl {
                    $$ = $2;
                    $$->templSpec_ = $1;
                  }
                  | templatespecifier tknInline funcdecl {
                    $$ = $3;
                    $$->templSpec_ = $1;
                  }
                  | tknInline funcdecl {
                    $$ = $2;
                    $$->attr_ |= kInline;
                  }
                  | funcdecl '=' tknDelete {
                    $$ = $1;
                    $$->attr_ |= kDelete;
                  }
                  | funcdecl '=' tknDefault {
                    $$ = $1;
                    $$->attr_ |= kDefault;
                  }
                  | funcdecl functhrowspec {
                    $$ = $1;
                    $$->throwSpec_ = $2;
                  }
                  ;

funcname          : basefuncname { $$ = $1; }
                  | identifier   { $$ = $1; }
                  | identifier tknScopeResOp basefuncname { $$ = mergeCppToken($1, $3); }
                  | tknScopeResOp funcname { $$ = mergeCppToken($1, $2); }
                  ;

basefuncname      : tknID { $$ = $1; }
                  | tknOperator '+' { $$ = mergeCppToken($1, $2); }
                  | tknOperator '-' { $$ = mergeCppToken($1, $2); }
                  | tknOperator '*' { $$ = mergeCppToken($1, $2); }
                  | tknOperator '/' { $$ = mergeCppToken($1, $2); }
                  | tknOperator '%' { $$ = mergeCppToken($1, $2); }
                  | tknOperator '^' { $$ = mergeCppToken($1, $2); }
                  | tknOperator '&' { $$ = mergeCppToken($1, $2); }
                  | tknOperator '|' { $$ = mergeCppToken($1, $2); }
                  | tknOperator '~' { $$ = mergeCppToken($1, $2); }
                  | tknOperator '!' { $$ = mergeCppToken($1, $2); }
                  | tknOperator '=' { $$ = mergeCppToken($1, $2); }
                  | tknOperator '<' { $$ = mergeCppToken($1, $2); }
                  | tknOperator '>' { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknPlusEq { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknMinusEq { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknMulEq { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknDivEq { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknPerEq { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknXorEq { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknAndEq { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknOrEq { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknLShift { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknRShift { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknLShiftEq { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknRShiftEq { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknCmpEq { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknNotEq { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknLessEq { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknGreaterEq { $$ = mergeCppToken($1, $2); }
                  | tknOperator tkn3WayCmp { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknAnd { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknOr { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknInc { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknDec { $$ = mergeCppToken($1, $2); }
                  | tknOperator ',' { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknArrow { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknArrowStar { $$ = mergeCppToken($1, $2); }
                  | tknOperator '(' ')' { $$ = mergeCppToken($1, $3); }
                  | tknOperator '[' ']' { $$ = mergeCppToken($1, $3); }
                  | tknOperator tknNew { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknNew '[' ']' { $$ = mergeCppToken($1, $4); }
                  | tknOperator tknDelete { $$ = mergeCppToken($1, $2); }
                  | tknOperator tknDelete '[' ']' { $$ = mergeCppToken($1, $4); }
                  ;

paramlist         : { $$ = 0; }
                  | param {
                    $$ = new CppParamList;
                    $$->push_back($1);
                  }
                  | paramlist ',' param {
                    $1->push_back($3);
                    $$ = $1;
                  }
                  ;

param             : varinit                 { $$ = $1; $1->varType_->typeAttr_ |= kFuncParam;  }
                  | vartype '=' expr        { /* When there is no named param but default value, e.g. `int = 3`*/
                    auto var = new CppVar($1, std::string());
                    var->varType_->typeAttr_ |= kFuncParam;
                    var->varDecl_.assign_.reset($3);
                    $$ = var;
                  }
                  | vardecl                 { $$ = $1; $1->varType_->typeAttr_ |= kFuncParam;  }
                  | vartype                 {
                    auto var = new CppVar($1, std::string());
                    var->varType_->typeAttr_ |= kFuncParam;
                    $$ = var;
                  }
                  | functionpointer         { $$ = $1; $1->attr_ |= kFuncParam;     }
                  | doccomment param        { $$ = $2; }
                  | vartype '[' expr ']' {
                    auto var = new CppVar($1, std::string());
                    var->varType_->typeAttr_ |= kFuncParam;
                    var->varDecl_.arraySizes_.push_back(std::unique_ptr<CppExpr>($3));
                    $$ = var;
                  }
                  | vartype '[' ']' {
                    auto var = new CppVar($1, std::string());
                    var->varType_->typeAttr_ |= kFuncParam;
                    var->varDecl_.arraySizes_.push_back(std::unique_ptr<CppExpr>(nullptr));
                    $$ = var;
                  }
                  ;

templateparam     :                               { $$ = makeCppToken(nullptr, 0U); }
                  | typeidentifier                { $$ = $1; }
                  | tknConst templateparam        { $$ = mergeCppToken($1, $2); }
                  | templateparam '*'             {
                    auto p = $1.sz + $1.len;
                    while (*p && (*p != '*'))
                      ++p;
                    if (*p == '*')
                      ++p;
                    $$ = makeCppToken($1.sz, p - $1.sz);
                  }
                  ;

templateparamlist : templateparam { $$ = $1; }
                  | templateparamlist ',' templateparam  { $$ = mergeCppToken($1, $3); }
                  ;

functype          : /* empty */             { $$ = 0;           }
                  | functype tknStatic      { $$ |= kStatic;    }
                  | functype tknInline      { $$ |= kInline;    }
                  | functype tknVirtual     { $$ |= kVirtual;   }
                  | functype tknExtern      { $$ |= kExtern;    }
                  | functype tknExternC     { $$ |= kExternC;   }
                  | functype tknExplicit    { $$ |= kExplicit;  }
                  | functype tknFriend      { $$ |= kFriend;    }
                  ;

funcattrib        :                           { $$ = 0; }
                  | funcattrib tknConst       { $$ = $1 | kConst; }
                  | funcattrib tknOverride    { $$ = $1 | kOverride; }
                  | funcattrib tknFinal       { $$ = $1 | kFinal; }
                  | funcattrib '=' tknNumber  [if($3.len != 1 || $3.sz[0] != '0') YYABORT; else ZZVALID;]
                                              { $$ = $1 | kPureVirtual; }
                  | funcattrib tknNoExcept    { $$ = $1 | kNoExcept; }
                  ;

functhrowspec     : tknThrow '(' identifierlist ')' {
                    $$ = $3 ? $3 : new CppFuncThrowSpec;
                  }
                  ;

identifierlist    : { $$ = nullptr; }
                  | identifier {
                    $$ = new CppIdentifierList;
                    $$->push_back($1);
                  }
                  | identifierlist ',' identifier {
                    $$ = $1;
                    $$->push_back($3);
                  }
                  ;

optattr           : { $$ = 0; }
                  | tknConst { $$ = kConst; }
                  | tknVolatile { $$ = kVolatile; }
                  ;

ctordeclstmt      : ctordecl';' [ZZVALID;] { $$ = $1; }
                  ;

ctordefn          : ctordecl meminitlist
                    '{'
                      stmtlist
                    '}' [ZZVALID;]
                  {
                    $$ = $1;
                    $$->memInitList_  = $2;
                    $$->defn_      = $4 ? $4 : newCompound(kUnknownProt, kBlock);
                  }
                  | tknID tknScopeResOp tknID [if($1 != $3) YYERROR; else ZZVALID;]
                    '(' paramlist ')' meminitlist
                    '{'
                      stmtlist
                    '}' [ZZVALID;]
                  {
                    $$ = newConstructor(gCurProtLevel, mergeCppToken($1, $3), $6, $8, 0);
                    $$->defn_      = $10 ? $10 : newCompound(kUnknownProt, kBlock);
                  }
                  | identifier tknScopeResOp tknID tknScopeResOp tknID [if($3 != $5) YYERROR; else ZZVALID;]
                    '(' paramlist ')' meminitlist
                    '{'
                      stmtlist
                    '}' [ZZVALID;]
                  {
                    $$ = newConstructor(gCurProtLevel, mergeCppToken($1, $5), $8, $10, 0);
                    $$->defn_      = $12 ? $12 : newCompound(gCurProtLevel, kBlock);
                  }
                  | tknID '<' templateparamlist '>' tknScopeResOp tknID [if($1 != $6) YYERROR; else ZZVALID;]
                    '(' paramlist ')' meminitlist
                    '{'
                      stmtlist
                    '}' [ZZVALID;]
                  {
                    $$ = newConstructor(gCurProtLevel, mergeCppToken($1, $6), $9, $11, 0);
                    $$->defn_      = $13 ? $13 : newCompound(gCurProtLevel, kBlock);
                  }
                  | tknInline ctordefn {
                    $$ = $2;
                    $$->attr_ |= kInline;
                  }
                  | templatespecifier ctordefn {
                    $$ = $2;
                    $$->templSpec_ = $1;
                  }
                  ;

ctordecl          : tknID '(' paramlist ')' %prec CTORDECL
                  [
                    if(gCompoundStack.empty())
                      YYERROR;
                    if(gCompoundStack.top() != $1)
                      YYERROR;
                    else
                      ZZVALID;
                  ]
                  {
                    $$ = newConstructor(gCurProtLevel, $1, $3, nullptr, 0);
                  }
                  | functype tknID [if(gCompoundStack.empty()) YYERROR; if(gCompoundStack.top() != $2) YYERROR; else ZZVALID;] '(' paramlist ')'
                  {
                    $$ = newConstructor(gCurProtLevel, $2, $5, nullptr, $1);
                  }
                  | templatespecifier ctordecl {
                    $$ = $2;
                    $$->templSpec_ = $1;
                  }
                  | tknInline ctordecl {
                    $$ = $2;
                    $$->attr_ |= kInline;
                  }
                  | ctordecl '=' tknDelete {
                    $$ = $1;
                    $$->attr_ |= kDelete;
                  }
                  | ctordecl '=' tknDefault {
                    $$ = $1;
                    $$->attr_ |= kDefault;
                  }
                  | ctordecl functhrowspec {
                    $$ = $1;
                    $$->throwSpec_ = $2;
                  }
                  ;

meminitlist       : { $$ = NULL; }
                  | ':' identifier '(' exprlist ')'        { $$ = new CppMemInitList; $$->push_back(CppMemInit($2, $4)); }
                  | ':' tknID '(' ')'        { $$ = new CppMemInitList; $$->push_back(CppMemInit($2, nullptr)); }
                  | meminitlist ',' tknID '(' exprlist ')'  { $$ = $1; $$->push_back(CppMemInit($3, $5)); }
                  ;

dtordeclstmt      : dtordecl ';' [ZZVALID;] { $$ = $1; }
                  ;

dtordefn          : dtordecl block [ZZVALID;]
                  {
                    $$ = $1;
                    $$->defn_ = $2 ? $2 : newCompound(kUnknownProt, kBlock);
                  }
                  | tknID tknScopeResOp '~' tknID [if($1 != $4) YYERROR; else ZZVALID;]
                    '(' ')' block
                  {
                    $$ = newDestructor(gCurProtLevel, mergeCppToken($1, $4), 0);
                    $$->defn_      = $8 ? $8 : newCompound(kUnknownProt, kBlock);
                  }
                  | identifier tknScopeResOp tknID tknScopeResOp '~' tknID [if($3 != $6) YYERROR; else ZZVALID;]
                    '(' ')' block
                  {
                    $$ = newDestructor(gCurProtLevel, mergeCppToken($1, $6), 0);
                    $$->defn_      = $10 ? $10 : newCompound(kUnknownProt, kBlock);
                  }
                  | tknID '<' templateparamlist '>' tknScopeResOp '~' tknID [if($1 != $7) YYERROR; else ZZVALID;]
                    '(' ')' block
                  {
                    $$ = newDestructor(gCurProtLevel, mergeCppToken($1, $7), 0);
                    $$->defn_      = $11 ? $11 : newCompound(kUnknownProt, kBlock);
                  }
                  | tknInline dtordefn {
                    $$ = $2;
                    $$->attr_ |= kInline;
                  }
                  | templatespecifier dtordefn {
                    $$ = $2;
                    $$->templSpec_ = $1;
                  }
                  ;

dtordecl          : optapidocer '~' tknID '(' optvoid ')' %prec DTORDECL
                  [
                    if(gCompoundStack.empty())
                      YYERROR;
                    if(gCompoundStack.top() != $3)
                      YYERROR;
                    else
                      ZZVALID;
                  ]
                  {
                    const char* tildaStartPos = $3.sz-1;
                    while(*tildaStartPos != '~') --tildaStartPos;
                    $$ = newDestructor(gCurProtLevel, makeCppToken(tildaStartPos, $3.sz+$3.len-tildaStartPos), 0);
                  }
                  | optapidocer functype '~' tknID '(' optvoid ')' %prec DTORDECL
                  [
                    if(gCompoundStack.empty())
                      YYERROR;
                    if(gCompoundStack.top() != $4)
                      YYERROR;
                    else
                      ZZVALID;
                  ]
                  {
                    const char* tildaStartPos = $4.sz-1;
                    while(*tildaStartPos != '~') --tildaStartPos;
                    $$ = newDestructor(gCurProtLevel, makeCppToken(tildaStartPos, $4.sz+$4.len-tildaStartPos), $2);
                  }
                  | optapidocer tknVirtual '~' tknID '(' optvoid ')' '=' tknNumber
                  [
                    if(gCompoundStack.empty())
                      YYERROR;
                    if(gCompoundStack.top() != $4)
                      YYERROR;
                    else
                      ZZVALID;
                  ]
                  {
                    const char* tildaStartPos = $4.sz-1;
                    while(*tildaStartPos != '~') --tildaStartPos;
                    $$ = newDestructor(gCurProtLevel, makeCppToken(tildaStartPos, $4.sz+$4.len-tildaStartPos), kPureVirtual);
                  }
                  | dtordecl '=' tknDelete {
                    $$ = $1;
                    $$->attr_ |= kDelete;
                  }
                  | dtordecl '=' tknDefault {
                    $$ = $1;
                    $$->attr_ |= kDefault;
                  }
                  ;

optvoid           :
                  | tknVoid
                  ;

optcomment        : {
                  }
                  | doccomment [ZZVALID;] {
                  }
                  ;

classdefnstmt     : classdefn ';' [ZZVALID;] { $$ = $1;}
                  | classdefn
                      [
                        if ($1->compoundType_ == kNamespace)
                        {
                          ZZVALID;
                        }
                      ]
                      {
                        $$ = $1;
                      }
                  ;

classdefn         : compoundSpecifier optapidocer identifier inheritlist optcomment
                    '{' [gCompoundStack.push($3); ZZVALID;] { gProtLevelStack.push(gCurProtLevel); gCurProtLevel = kUnknownProt; }
                      stmtlist
                    '}' [gCompoundStack.pop(); ZZVALID;]
                  {
                    gCurProtLevel = gProtLevelStack.top();
                    gProtLevelStack.pop();

                    $$ = $8 ? $8 : newCompound(gCurProtLevel);
                    $$->compoundType_  = $1;
                    $$->apidocer_    = $2;
                    $$->name_      = $3;
                    $$->inheritList_  = $4;
                  }
                  | compoundSpecifier inheritlist optcomment
                    '{' { gProtLevelStack.push(gCurProtLevel); gCurProtLevel = kUnknownProt; }
                      stmtlist
                    '}' [ ZZVALID;]
                  {
                    gCurProtLevel = gProtLevelStack.top();
                    gProtLevelStack.pop();

                    $$ = $6 ? $6 : newCompound(gCurProtLevel);
                    $$->compoundType_  = $1;
                    $$->inheritList_  = $2;
                  }
                  | templatespecifier classdefn {
                    $$ = $2;
                    $$->templSpec_ = $1;
                  }
                  ;

inheritlist       : { $$ = 0; }
                  | ':' protlevel identifier [ZZVALID;]        { $$ = new CppInheritanceList; $$->push_back(CppInheritInfo((std::string) $3, $2)); }
                  | inheritlist ',' protlevel identifier [ZZVALID;]  { $$ = $1; $$->push_back(CppInheritInfo((std::string) $4, $3)); }
                  ;

protlevel         :        { $$ = kUnknownProt;}
                  | tknPublic    { $$ = kPublic;    }
                  | tknProtected  { $$ = kProtected;  }
                  | tknPrivate  { $$ = kPrivate;  }
                  ;

fwddecl           : compoundSpecifier identifier ';' [ZZVALID;] { $$ = new CppFwdClsDecl(gCurProtLevel, $2, $1); }
                  | compoundSpecifier optapidocer identifier ';' [ZZVALID;] { $$ = new CppFwdClsDecl(gCurProtLevel, $3, $1); }
                  | templatespecifier fwddecl {
                    // TODO: Assign template declaration to fwddecl.
                    $$ = $2;
                  }
                  | tknFriend fwddecl [ZZVALID;]  { $$ = $2; $$->attr_ = kFriend; }
                  ;

compoundSpecifier : tknClass    { $$ = kClass;    }
                  | tknStruct    { $$ = kStruct;    }
                  | tknUnion    { $$ = kUnion;    }
                  | tknNamespace  { $$ = kNamespace;  }
                  ;

templatespecifier : tknTemplate '<' temparglist '>' {
                    $$ = $3;
                  }
                  ;

temparglist       : temparg {
                    $$ = new CppTemplateArgList;
                    $$->push_back($1);
                  }
                  | temparglist ',' temparg {
                    $$ = $1;
                    $$->push_back($3);
                  }
                  ;

temparg           : tempargwodefault  { $$ = $1; }
                  | tempargwdefault   { $$ = $1; }
                  ;

tempargwodefault  : typenamespecifier tknID [ZZVALID;] {
                    $$ = new CppTemplateArg{$1, $2, nullptr};
                  }
                  | identifier tknID {
                    $$ = new CppTemplateArg{$1, $2, nullptr};
                  }
                  ;

tempargwdefault   : tempargwodefault '=' expr {
                    $$ = $1;
                    $$->defaultArgVal_ = $3;
                  }
                  ;

typenamespecifier : tknTypename { $$ = $1; }
                  | tknClass    { $$ = $1; }
                  ;

optapidocer       :                     { $$ = makeCppToken(nullptr, 0U); }
                  | apidocer            { $$ = $1; }
                  ;

apidocer          : tknID               { $$ = $1; }
                  | tknID '(' tknID ')' { $$ = mergeCppToken($1, $4); }
                  | tknID tknID         { $$ = mergeCppToken($1, $2); }
                  ;

changeprotlevel   : tknPublic     ':'  [ZZVALID;] { $$ = kPublic;     }
                  | tknProtected  ':'  [ZZVALID;] { $$ = kProtected;  }
                  | tknPrivate    ':'  [ZZVALID;] { $$ = kPrivate;    }
                  ;

externcblock      : tknExternC block [ZZVALID;] {$$ = $2; $$->compoundType_ = kExternCBlock; }
                  ;

exprlist          : expr              { $$ = new CppExprList(); $$->push_back($1);  }
                  | exprlist ',' expr { $$ = $1; $$->push_back($3);                 }
                  ;

expr              : tknStrLit                         { $$ = new CppExpr((std::string) $1, kNone);          }
                  | tknCharLit                        { $$ = new CppExpr((std::string) $1, kNone);          }
                  | tknNumber                         { $$ = new CppExpr((std::string) $1, kNone);          }
                  | funcname                          { $$ = new CppExpr((std::string) $1, kNone);          }
                  | '{' exprlist '}'                  { $$ = new CppExpr($2, CppExpr::kInitializer);        }
                  | '-' expr %prec PREFIX             { $$ = new CppExpr($2, kUnaryMinus);                  }
                  | '~' expr %prec PREFIX             { $$ = new CppExpr($2, kBitToggle);                   }
                  | '!' expr %prec PREFIX             { $$ = new CppExpr($2, kLogNot);                      }
                  | '*' expr %prec PREFIX             { $$ = new CppExpr($2, kDerefer);                     }
                  | '&' expr %prec PREFIX             { $$ = new CppExpr($2, kRefer);                       }
                  | tknInc expr                       { $$ = new CppExpr($2, kPreIncrement);                }
                  | expr tknInc                       { $$ = new CppExpr($1, kPostIncrement);               }
                  | tknDec expr                       { $$ = new CppExpr($2, kPreDecrement);                }
                  | expr tknDec                       { $$ = new CppExpr($1, kPostDecrement);               }
                  | expr '+' expr                     { $$ = new CppExpr($1, kPlus, $3);                    }
                  | expr '-' expr                     { $$ = new CppExpr($1, kMinus, $3);                   }
                  | expr '*' expr                     { $$ = new CppExpr($1, kMul, $3);                     }
                  | expr '/' expr                     { $$ = new CppExpr($1, kDiv, $3);                     }
                  | expr '%' expr                     { $$ = new CppExpr($1, kPercent, $3);                     }
                  | expr '&' expr                     { $$ = new CppExpr($1, kBitAnd, $3);                  }
                  | expr '|' expr                     { $$ = new CppExpr($1, kBitOr, $3);                   }
                  | expr '^' expr                     { $$ = new CppExpr($1, kXor, $3);                  }
                  | expr '=' expr                     { $$ = new CppExpr($1, kEqual, $3);                   }
                  | expr '<' expr                     { $$ = new CppExpr($1, kLess, $3);                    }
                  | expr '>' expr                     { $$ = new CppExpr($1, kGreater, $3);                 }
                  | expr '?' expr ':' expr            { $$ = new CppExpr($1, $3, $5);                       }
                  | expr tknPlusEq expr               { $$ = new CppExpr($1, kPlusEqual, $3);               }
                  | expr tknMinusEq expr              { $$ = new CppExpr($1, kMinusEqual, $3);              }
                  | expr tknMulEq expr                { $$ = new CppExpr($1, kMulEqual, $3);                }
                  | expr tknDivEq expr                { $$ = new CppExpr($1, kDivEqual, $3);                }
                  | expr tknPerEq expr                { $$ = new CppExpr($1, kPerEqual, $3);                }
                  | expr tknXorEq expr                { $$ = new CppExpr($1, kXorEqual, $3);                }
                  | expr tknAndEq expr                { $$ = new CppExpr($1, kAndEqual, $3);                }
                  | expr tknOrEq expr                 { $$ = new CppExpr($1, kOrEqual, $3);                 }
                  | expr tknLShift expr %prec LSHIFT  { $$ = new CppExpr($1, kLeftShift, $3);               }
                  | expr tknRShift expr %prec RSHIFT  { $$ = new CppExpr($1, kRightShift, $3);              }
                  | expr tknLShiftEq expr             { $$ = new CppExpr($1, kLShiftEqual, $3);             }
                  | expr tknRShiftEq expr             { $$ = new CppExpr($1, kRShiftEqual, $3);             }
                  | expr tknCmpEq expr %prec CMPEQUAL { $$ = new CppExpr($1, kCmpEqual, $3);                }
                  | expr tknNotEq expr                { $$ = new CppExpr($1, kNotEqual, $3);                }
                  | expr tknLessEq expr               { $$ = new CppExpr($1, kLessEqual, $3);               }
                  | expr tknGreaterEq expr            { $$ = new CppExpr($1, kGreaterEqual, $3);            }
                  | expr tkn3WayCmp expr              { $$ = new CppExpr($1, k3WayCmp, $3);                 }
                  | expr tknAnd expr                  { $$ = new CppExpr($1, kAnd, $3);                     }
                  | expr tknOr expr                   { $$ = new CppExpr($1, kOr, $3);                      }
/*                | expr ',' expr                     { $$ = new CppExpr($1, kComma, $3);                   } */
                  | expr '.' expr                     { $$ = new CppExpr($1, kDot, $3);                     }
                  | expr tknArrow expr %prec ARROW    { $$ = new CppExpr($1, kArrow, $3);                   }
                  | expr tknArrowStar expr            { $$ = new CppExpr($1, kArrowStar, $3);               }
                  | expr '[' expr ']' %prec POSTFIX   { $$ = new CppExpr($1, kArrayElem, $3);               }
                  | expr '(' ')'                      { $$ = new CppExpr($1, kFunctionCall);                }
                  | expr '(' exprlist ')'             { $$ = new CppExpr($1, kFunctionCall, $3);            }
                  | '(' vartype ')' expr              { $$ = new CppExpr($2, kCStyleCast, $4);              }
                  | tknConstCast '<' vartype '>' '(' expr ')' { $$ = new CppExpr($3, kConstCast, $6);       }
                  | tknStaticCast '<' vartype '>' '(' expr ')' { $$ = new CppExpr($3, kStaticCast, $6);     }
                  | tknDynamicCast '<' vartype '>' '(' expr ')' { $$ = new CppExpr($3, kDynamicCast, $6);   }
                  | tknReinterpretCast '<' vartype '>' '(' expr ')' { $$ = new CppExpr($3, kReinterpretCast, $6); }
                  | '(' expr ')'                      { $$ = $2; $2->flags_ |= CppExpr::kBracketed;         }
                  | tknNew expr                       { $$ = $2; $2->flags_ |= CppExpr::kNew;               }
                  | tknNew expr expr                  { $$ = new CppExpr($2, kPlacementNew, $3);            }
                  | tknScopeResOp tknNew expr expr    { $$ = new CppExpr($3, kPlacementNew, $4);            }
                  | tknDelete  expr                   { $$ = $2; $2->flags_ |= CppExpr::kDelete;            }
                  | tknDelete  '[' ']' expr           { $$ = $4; $4->flags_ |= CppExpr::kDeleteArray;       }
                  | tknReturn  expr                   { $$ = $2; $2->flags_ |= CppExpr::kReturn;            }
                  | tknReturn                         { $$ = new CppExpr(CppExprAtom(), CppExpr::kReturn);  }
                  | tknThrow  expr                    { $$ = $2; $2->flags_ |= CppExpr::kThrow;             }
                  | tknThrow                          { $$ = new CppExpr(CppExprAtom(), CppExpr::kThrow);   }
                  ;

exprstmt          : expr ';'  [ZZVALID;]              { $$ = $1; }
                  ;

%%

//////////////////////////////////////////////////////////////////////////

/**
 * yyparser() invokes this function when it encounters unexpected token.
 */
void yyerror_detailed  (  char* text,
              int errt,
              YYSTYPE& errt_value,
              YYPOSN& errt_posn
            )
{
  extern const char* get_start_of_buffer();
  extern int get_context();

  const char* lineStart = errt_posn;
  const char* buffStart = get_start_of_buffer();
  while(lineStart > buffStart)
  {
    if(lineStart[-1] == '\n' || lineStart[-1] == '\r')
      break;
    --lineStart;
  }
  char* lineEnd = errt_posn;
  char endReplaceChar = 0;
  while(*lineEnd)
  {
    if(*lineEnd == '\r' || *lineEnd == '\n')
    {
      endReplaceChar = *lineEnd;
      *lineEnd = '\0'; // So that printing of lineStart does not print things beyond current line.
    }
    else
    {
      ++lineEnd;
    }
  }
  char spacechars[1024] = {0}; // For printing enough whitespace chars so that we can show a ^ below the start of unexpected token.
  for(const char* p = lineStart; p < errt_posn; ++p)
    spacechars[p-lineStart] = *p == '\t' ? '\t' : ' ';
  char errmsg[1024];
  sprintf(errmsg, "%s%s%s%d%s%d%c%s%c%s%c%c",
    "Error: Unexpected token '", errt_posn, "', while in context=", get_context(), ", found at line#", gLineNo, '\n', // The error message
    lineStart, '\n',    // Line that contains the error.
    spacechars, '^', '\n');  // A ^ below the beginning of unexpected token.
  printf("%s", errmsg);
  // Replace back the end char
  if(endReplaceChar)
    *lineEnd = endReplaceChar;
}

CppCompound* parseStream(char* stm, size_t stmSize)
{
  gProgUnit = nullptr;
  gCurProtLevel = kUnknownProt;
  
  void setupScanBuffer(char* buf, size_t bufsize);
  void cleanupScanBuffer();
  setupScanBuffer(stm, stmSize);
  gLineNo = 1; // Reset so that we do not start counting beyond previous parsing.
  yyparse();
  cleanupScanBuffer();
  
  return gProgUnit;
}

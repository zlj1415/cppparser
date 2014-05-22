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

#ifndef __CPPPARSER_CPPDOM_H__
#define __CPPPARSER_CPPDOM_H__

#include "const.h"

#include <string>
#include <vector>
#include <list>
#include <xutility>

//////////////////////////////////////////////////////////////////////////

struct CppCompound;

/**
 * An abstract class that is used as base class of all other classes.
 */
struct CppObj
{
	enum Type {
		kUnknown			= 0x0000,
		kBlankLine,			// Blank line containing nothing other than may be whitespace.
		kVarType,			// Just the type of variable.
		kVar,				// A variable declaration.
		kVarList,			// List of variables declared as comma separated identifiers.
		kHashIf,			// #if, #ifdef, #ifndef, #else, #elif.
		kHashInclude,		// #include
		kHashDefine,		// #define
		kHashUndef,			// #undef
		kHashPragma,		// #pragma
		kUnRecogPrePro,		// Any unrecognized pre-processor.
		kDocComment,
		kTypedef,
		kEnum,
		kCompound,			// file, namespace, class, struct, union, block.
		kFwdClsDecl,		// Forward declaration of compound type.
		kFunction,
		kConstructor,
		kDestructor,
		kFunctionPtr,		// Function proc declaration using typedef. e.g. typedef void (*fp) (void);
		kExpression,		// A C++ expression
		kFuncCall,			// A function call expression
		kBlob,				// Some unparsed/unrecognized part of C++ source code.
	};

	Type			objType_;
	CppCompound*	owner_;
	CppObjProtLevel	prot_;	///< All objects do not need this but for simplicity we will have this in all objects.

	CppObj(Type type, CppObjProtLevel prot)
	: objType_	(type)
	, owner_	(NULL)
	, prot_		(prot)
	{
	}

	virtual ~CppObj() = 0 {}
};

/**
 * A blank line in a C/C++ program.
 */
struct CppBlankLine : public CppObj
{
	int numLines_;

	CppBlankLine()
		: CppObj(kBlankLine, kUnknownProt)
		, numLines_(1)
	{
	}
};

typedef std::list<CppObj*> CppObjArray;

struct CppDefine : public CppObj
{
	enum DefType {
		kRename,
		kConstNumDef,
		kConstStrDef,
		kConstCharDef,
		kComplexMacro,
	};
	DefType		defType_;
	std::string	name_;
	std::string	defn_; ///< This will contain everything after name.

	CppDefine(std::string name, std::string defn = std::string())
		: CppObj	(kHashDefine, kUnknownProt)
		, name_		(std::move(name))
		, defn_		(std::move(defn))
	{
	}
};

struct CppUndef : public CppObj
{
	std::string	name_;

	CppUndef(std::string name)
		: CppObj	(kHashUndef, kUnknownProt)
		, name_		(std::move(name))
	{
	}
};

struct CppInclude : public CppObj
{
	std::string	name_;

	CppInclude(std::string name)
		: CppObj	(kHashInclude, kUnknownProt)
		, name_		(std::move(name))
	{
	}
};

/**
 * \brief Represents all variants of #if preprocessors.
 * It includes #if, #ifdef, #ifndef.
 * It also includes #else, #elif, and #endif.
 */
struct CppHashIf : public CppObj
{
	enum CondType {
		kIf, kElse, kIfDef, kIfNDef, kElIf, kEndIf
	};

	CondType	condType_;
	std::string	cond_;

	CppHashIf(CondType condType, std::string cond)
		: CppObj	(kHashIf, kUnknownProt)
		, condType_	(condType)
		, cond_		(std::move(cond))
	{
	}

	CppHashIf(CondType condType)
		: CppObj	(kHashIf, kUnknownProt)
		, condType_	(condType)
	{
	}
};

struct CppPragma : public CppObj
{
	std::string defn_;

	CppPragma(std::string defn)
		: CppObj(CppObj::kHashPragma, kUnknownProt)
		, defn_(std::move(defn))
	{
	}
};

/**
 * Any other C/C++ preprocessor for which there is no class defined.
 */
struct CppUnRecogPrePro : public CppObj
{
	std::string name_;
	std::string	defn_;

	CppUnRecogPrePro(std::string name, std::string defn)
		: CppObj(CppObj::kUnRecogPrePro, kUnknownProt)
		, name_	(std::move(name))
		, defn_	(std::move(defn))
	{
	}
};

struct CppExpr;
struct CppVarType : public CppObj
{
	std::string		baseType_; // This is the basic data type of var e.g. for 'const int*& pi' base-type is int.
	unsigned int	typeAttr_; // Attribute associated with type, e.g. const int* x.
	unsigned short  ptrLevel_; // Pointer level. e.g. int** ppi has pointer level of 2.
	CppRefType		refType_;
	CppExpr*		arraySize_; // Should be NULL for non-array vars

	CppVarType(CppObjProtLevel prot, std::string baseType, unsigned int typeAttr, unsigned short ptrLevel, CppRefType refType)
		: CppObj(CppObj::kVarType, prot)
		, baseType_(std::move(baseType))
		, typeAttr_(typeAttr)
		, ptrLevel_(ptrLevel)
		, refType_(refType)
		, arraySize_(NULL)
	{
	}

	CppVarType(std::string baseType, unsigned int typeAttr = 0, unsigned short ptrLevel = 0, CppRefType refType = kNoRef)
		: CppObj(CppObj::kVarType, kUnknownProt)
		, baseType_(std::move(baseType))
		, typeAttr_(typeAttr)
		, ptrLevel_(ptrLevel)
		, refType_(refType)
		, arraySize_(NULL)
	{
	}

	bool isVoid() const
	{
		if(typeAttr_ != 0 || ptrLevel_ != 0 || refType_ != kNoRef)
			return false;
		return (baseType_.compare("void") == 0);
	}

protected:
	CppVarType(CppObj::Type type, CppObjProtLevel prot, std::string baseType, unsigned int typeAttr, unsigned short ptrLevel, CppRefType refType)
		: CppObj(type, prot)
		, baseType_(std::move(baseType))
		, typeAttr_(typeAttr)
		, ptrLevel_(ptrLevel)
		, refType_(refType)
		, arraySize_(NULL)
	{
	}
};

struct CppExpr;
/**
 * Class to represent C++ variables.
 * A variable can be global, local or member of a struct, class, namespace, or union.
 * It can also be a function parameter.
 */
struct CppVar : public CppVarType
{
	std::string		name_;
	unsigned int	varAttr_;  // Attribute associated with var, e.g. int* const p.
	CppExpr*		assign_; // Value assigned at declaration.
	std::string		apidocer_; // It holds things like WINAPI, __declspec(dllexport), etc.

	CppVar(CppObjProtLevel prot, std::string baseType, unsigned int typeAttr, unsigned int varAttr, unsigned short ptrLevel, CppRefType refType, std::string name)
	: CppVarType(CppObj::kVar, prot, std::move(baseType), typeAttr, ptrLevel, refType)
	, varAttr_	(varAttr)
	, name_		(std::move(name))
	, assign_	(NULL)
	{
	}
};

typedef std::list<CppVar*> CppVarObjList;

/**
 * \brief List of variables declared in a line without repeating its type, e.g. int i, j; is a var-list.
 */
struct CppVarList : public CppObj
{
	CppVarObjList varlist_;

	CppVarList(CppObjProtLevel prot = kUnknownProt)
		: CppObj(CppObj::kVarList, prot)
	{
	}

	~CppVarList() {
		for(CppVarObjList::iterator itr = varlist_.begin(); itr != varlist_.end(); ++itr)
			delete *itr;
	}

	void addVar(CppVar* var) {
		varlist_.push_back(var);
	}
};

struct CppTypedef : public CppVarType
{
	std::list<std::string>	names_;

	CppTypedef(CppObjProtLevel prot, std::string baseType, unsigned int typeAttr, unsigned short ptrLevel, CppRefType refType)
		: CppVarType(CppObj::kTypedef, prot, std::move(baseType), typeAttr, ptrLevel, refType)
	{
	}
};

struct CppFwdClsDecl : public CppObj
{
	CppCompoundType cmpType_;
	std::string		name_;

	CppFwdClsDecl(CppObjProtLevel prot, std::string name, CppCompoundType cmpType)
		: CppObj	(CppObj::kFwdClsDecl, prot)
		, cmpType_	(cmpType)
		, name_		(std::move(name))
	{
	}
};

struct CppInheritInfo {
	std::string baseName;
	CppObjProtLevel inhType;

	CppInheritInfo(std::string _baseName, CppObjProtLevel _inhType)
		: baseName(std::move(_baseName))
		, inhType(_inhType)
	{
	}
};

typedef std::list<CppInheritInfo> CppInheritanceList;

/**
 * All classes, structs, unions, and namespaces can be classified as a Compound object.
 * An entire C/C++ source file too is a compound object. A block of statements inside { } is also a compound object.
 */
struct CppCompound : public CppObj
{
public:
	std::string			name_;
	CppObjArray			members_;	// Objects arranged in sequential order from top to bottom.
	CppCompoundType		compoundType_;
	CppInheritanceList*	inheritList_;
	std::string			apidocer_;

	CppCompound(CppObjProtLevel prot, CppCompoundType type = kUnknownCompound)
	: CppObj		(CppObj::kCompound, prot)
	, compoundType_	(type)
	, inheritList_	(NULL)
	{
	}

	CppCompound(CppCompoundType type)
		: CppObj		(CppObj::kCompound, kUnknownProt)
		, compoundType_	(type)
		, inheritList_	(NULL)
	{
	}

	CppCompound(std::string name, CppCompoundType type)
		: CppObj		(CppObj::kCompound, kUnknownProt)
		, compoundType_	(type)
		, name_			(std::move(name))
		, inheritList_	(NULL)
	{
	}

	~CppCompound()
	{
		delete inheritList_;
		for(CppObjArray::iterator itr = members_.begin(); itr != members_.end(); ++itr)
			delete *itr;
	}

	bool isNamespace() const { return compoundType_ == kNamespace;	}
	bool isClass	() const { return compoundType_ == kClass;		}
	bool isStruct	() const { return compoundType_ == kStruct;		}
	bool isUnion	() const { return compoundType_ == kUnion;		}
	bool isCppFile	() const { return compoundType_	== kCppFile;	}
	bool isBlock	() const { return compoundType_ == kBlock;		}

	void addMember	(CppObj* mem) { members_.push_back(mem); }
	CppObjProtLevel defaultProtLevel() const { return isClass() ? kPrivate : kPublic; }
	void addBaseClass(std::string baseName, CppObjProtLevel inheritType)
	{
		if(inheritList_ == NULL)
			inheritList_ = new CppInheritanceList;
		inheritList_->push_back(CppInheritInfo(baseName, inheritType));
	}
};

struct CppFunctionPtr;

/**
 * At some place either a var-type or function pointer is expected
 * For example typedef and function parameter.
 */
union CppVarOrFuncPtrType
{
	CppObj*			cppObj; ///< This should be used just for type checking.
	CppVar*			varObj;
	CppFunctionPtr*	funcPtr;
	CppObj* operator = (CppObj* rhs)
	{
		cppObj = rhs;
		return cppObj;
	}

#if ALLOW_UNION_CTOR
	CppVarOrFuncPtrType(CppObj* _cppObj)
		: cppObj(_cppObj)
	{
	}
#endif //#if ALLOW_UNION_CTOR
};

/**
 * A function parameter object.
 */
typedef CppVarOrFuncPtrType	CppParam;

#if !ALLOW_UNION_CTOR
inline CppParam makeCppParam(CppObj* obj)
{
	CppParam param = {obj};
	return param;
}
#endif //#if !ALLOW_UNION_CTOR

struct CppParamList : public std::list<CppParam>
{
	~CppParamList()
	{
		for(iterator itr = begin(); itr != end(); ++itr)
			delete itr->cppObj;
	}
};

/**
 * \brief A C/C++ function. It can be class method as well.
 */
struct CppFunction : public CppObj
{
	std::string		name_;
	CppVarType*		retType_;
	CppParamList*	params_;
	unsigned int	attr_; // e.g.: const, static, virtual, inline, etc.
	CppCompound*	defn_; // If it is NULL then this object is just for declaration.
	std::string		docer1_; // e.g. __declspec(dllexport)
	std::string		docer2_; // e.g. __stdcall

	CppFunction(CppObjProtLevel prot, std::string name, CppVarType* retType, CppParamList* params, unsigned int attr)
		: CppObj(CppObj::kFunction, prot)
		, name_		(std::move(name))
		, retType_	(retType)
		, params_	(params)
		, attr_		(attr)
		, defn_		(0)
	{
	}

	CppFunction(CppObjProtLevel prot, std::string name, CppVarType* retType, CppParam param1, CppParam param2, unsigned int attr = 0)
		: CppObj(CppObj::kFunction, prot)
		, name_		(std::move(name))
		, retType_	(retType)
		, params_	(new CppParamList)
		, attr_		(attr)
		, defn_		(0)
	{
		params_->push_back(param1);
		params_->push_back(param2);
	}

	CppFunction(CppObjProtLevel prot, std::string name, CppVarType* retType, CppParam param1, CppParam param2, CppParam param3, unsigned int attr = 0)
		: CppObj(CppObj::kFunction, prot)
		, name_		(std::move(name))
		, retType_	(retType)
		, params_	(new CppParamList)
		, attr_		(attr)
		, defn_		(0)
	{
		params_->push_back(param1);
		params_->push_back(param2);
		params_->push_back(param3);
	}

	~CppFunction()
	{
		delete retType_;
		delete params_;
		delete defn_;
	}

protected:
	CppFunction(CppObj::Type type, CppObjProtLevel prot, std::string name, CppVar* retType, CppParamList* params, unsigned int attr)
		: CppObj(type, prot)
		, name_		(std::move(name))
		, retType_	(retType)
		, params_	(params)
		, attr_		(attr)
		, defn_		(0)
	{
	}
};

/**
 * Function pointer type definition using typedef, e.g. 'typedef void (*funcPtr)(int);'

 * It has all the attributes of a function object and so it is simply derived from CppFunction.
 */
struct CppFunctionPtr : public CppFunction
{
	CppFunctionPtr(CppObjProtLevel prot, std::string name, CppVar* retType, CppParamList* args, unsigned int attr)
		: CppFunction(CppObj::kFunctionPtr, prot, std::move(name), retType, args, attr)
	{
	}
};

struct CppExpr;
/**
 * Class data member initialization as part of class constructor.
 */
typedef std::pair<std::string, CppExpr*>	CppMemInit;
/**
 * Entire member initialization list.
 */
typedef std::list<CppMemInit>				CppMemInitList;

struct CppConstructor : public CppObj
{
	std::string		name_;
	CppParamList*	args_;
	CppMemInitList* memInitList_;
	CppCompound*	defn_; // If it is NULL then this object is just for declaration.
	unsigned int	attr_; // e.g. inline, explicit, etc.

	CppConstructor(CppObjProtLevel prot, std::string name)
		: CppObj(CppObj::kConstructor, prot)
		, name_	(std::move(name))
		, args_(0)
		, memInitList_(NULL)
		, defn_(0)
		, attr_(0)
	{
	}

	~CppConstructor()
	{
		delete args_;
		delete memInitList_;
		delete defn_;
	}
};

struct CppDestructor : public CppObj
{
	std::string		name_;
	CppCompound*	defn_; // If it is NULL then this object is just for declaration.
	unsigned int	attr_; // e.g. inline, virtual, etc.

	CppDestructor(CppObjProtLevel prot, std::string name)
		: CppObj(CppObj::kDestructor, prot)
		, name_	(std::move(name))
		, defn_(0)
		, attr_(0)
	{
	}

	~CppDestructor()
	{
		delete defn_;
	}
};

struct CppDocComment : public CppObj
{
	std::string	doc_; ///< Entire comment text

	CppDocComment(std::string doc)
	: CppObj(CppObj::kDocComment, kUnknownProt)
	, doc_(std::move(doc))
	{
	}
};

struct CppExprAtom;
struct CppExpr;
/**
 * \brief Represents a list of expressions.
 *
 * It is mainly used for:
 * - function call, in that case the expression list is enclosed inside ().
 * - and array/struct initialization, in such case expression list is enclosed inside {}.
 * \see CppExpr.
 */
struct CppExprList : public std::list<CppExpr*>
{
public:
	CppExprList() {}
	CppExprList(const CppExprAtom& e1);
	CppExprList(const CppExprAtom& e1, const CppExprAtom& e2);
	CppExprList(const CppExprAtom& e1, const CppExprAtom& e2, const CppExprAtom& e3);

	void push(const CppExprAtom& e);

	~CppExprList(); // Need this to delete list items
};

struct CppExpr;
/**
 * An individual expression.
 */
struct  CppExprAtom
{
	enum {
		kInvalid, kAtom, kExpr, kExprList
	}						type;
	union {
		std::string*		atom;
		CppExpr*			expr;
		CppExprList*		list;
	};

	bool isExpr() const { return (type&kExpr) == kExpr; }

	CppExprAtom(const char* sz, size_t l)
		: atom(new std::string(sz, l))
		, type(kAtom)
	{
	}
	CppExprAtom(const char* sz)
		: atom(new std::string(sz))
		, type(kAtom)
	{
	}
	CppExprAtom(std::string tok)
		: atom(new std::string(std::move(tok)))
		, type(kAtom)
	{
	}
	CppExprAtom(CppExpr* e)
		: expr(e)
		, type(kExpr)
	{
	}
	CppExprAtom(CppExprList* l)
		: list(l)
		, type(kExprList)
	{
	}
	CppExprAtom()
		: atom(0)
		, type(kInvalid)
	{
	}
};

/**
 * \brief An expression in a C/C++ program.
 *
 * In C/C++ an expression is a complicated beast that needs to be tamed to parse it correctly.
 * An expression can be as simple as a word, e.g. x, 5 are valid expressions.
 * It can be a function call.
 * It can be an initialization list for an array or struct. e.g. POINT pt = {100, 500};
 * It can be a list of expressions used to call a function e.g. gcd(36, 42);
 * new/delete statements are also expressions.
 * It can be any of the arithmetic expression, e.g. a+b.
 * To make things simple we treat a return statement as an expression.
 *
 * structs CppExprAtom, CppExpr, and CppExprList are required to tame this difficult beast called expression in C/C++.
 */
struct CppExpr : public CppObj
{
	enum Flag {
		kReturn			= 0x01,
		kNew			= 0x02,
		//kNewArray		= 0x04, // This is not needed.
		kDelete			= 0x08,
		kDeleteArray	= 0x10,
		kBracketed		= 0x20,
		kInitializer	= 0x40,
	};
	CppExprAtom expr1_;
	CppExprAtom expr2_;
	CppOperType oper_;
	short		flags_; // ORed combination of Flag constants.

	CppExpr(CppExprAtom e1, CppOperType op, CppExprAtom e2 = CppExprAtom())
		: CppObj(CppObj::kExpression, kUnknownProt)
		, expr1_(e1)
		, oper_(op)
		, expr2_(e2)
		, flags_(0)
	{
	}

	CppExpr(CppExprAtom e1, short flags)
		: CppObj(CppObj::kExpression, kUnknownProt)
		, expr1_(e1)
		, oper_(kNone)
		, expr2_(CppExprAtom())
		, flags_(flags)
	{
	}

	~CppExpr()
	{
		if(oper_ == kNone)
		{
			delete expr1_.atom;
		}
		else
		{
			delete expr1_.expr;
			delete expr2_.expr;
		}
	}
};

/**
 * \brief A stream of text that represents some content in a C++ program.

 * It is basically a quick way to create C++ content while generating source programatically.
 */
struct CppBlob : public CppObj
{
	std::string blob_;

	CppBlob(std::string blob)
		: CppObj(CppObj::kBlob, kUnknownProt)
		, blob_(std::move(blob))
	{
	}
};

//////////////////////////////////////////////////////////////////////////

inline void CppExprList::push(const CppExprAtom& e)
{
	if(e.isExpr()) push_back(e.expr);
	else push_back(new CppExpr(e, kNone));
}

inline CppExprList::CppExprList(const CppExprAtom& e1)
{
	push(e1);
}
inline CppExprList::CppExprList(const CppExprAtom& e1, const CppExprAtom& e2)
{
	push(e1);
	push(e2);
}
inline CppExprList::CppExprList(const CppExprAtom& e1, const CppExprAtom& e2, const CppExprAtom& e3)
{
	push(e1);
	push(e2);
	push(e3);
}

inline CppExprList::~CppExprList()
{
	for(iterator i = begin(); i != end(); ++i)
		delete *i;
}

#endif //__CPPPARSER_CPPDOM_H__

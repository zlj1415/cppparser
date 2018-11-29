//
//////////////////////////////////////////////////////////////////////////////
//
//  Copyright 2018 Autodesk, Inc.  All rights reserved.
//
//  Use of this software is subject to the terms of the Autodesk license 
//  agreement provided at the time of installation or download, or which 
//  otherwise accompanies this software in either electronic or hard copy form.   
//
//////////////////////////////////////////////////////////////////////////////
//
// dbid.h
//
// DESCRIPTION:
//
// This file contains lightweight id classes distinguishing between
// different types of object id's. A distinction is made between an
// owned object and a reference or "pointer to" an object, as well as
// whether the relationship protects the object from purge (hard/soft).
//
// Hard-owner:  
//
// An owned object protected from purge. A layer symbol table and
// layer 0 is an example of a hard-owner relationship.
//
// Soft-owner:
//
// An owned object not protected from purge. All symbol tables own
// their records, but that relationship does not usually protect
// the records from purge.
//
// Hard-pointer:
//
// A reference to an object that is not owned, but protected from
// purge. An entity, for example, does not own the layer it is on
// but its reference to it protects it from purge.
//
// Soft-pointer:
//
// A reference to an object that is not owned, and not protected
// from purge. 
#ifndef _AD_DBID_H
#	define _AD_DBID_H	1
#	include "adesk.h"
#	include "dbhandle.h"
#	include "AcDbCore2dDefs.h"
#	pragma  pack(push, 8)
class AcDbDatabase;
class AcDbStub;
class AcRxClass;
class AcDbObjectId
{
public:
	AcDbObjectId();
	AcDbObjectId(const AcDbStub*);
	static const AcDbObjectId kNull;
	bool isNull() const;
	void setNull();
	Adesk::IntDbId asOldId() const;
	AcDbObjectId& setFromOldId(Adesk::IntDbId oldId);
#	if  (defined(_WIN64) || defined(_AC64)) && defined(_ADESK_WINDOWS_)
private:
    // catch attempts to store the id in and set it from a 32-bit long
	AcDbObjectId& setFromOldId(long);
public:
    // need this overload to allow passing of unsigned 64-bit
	inline AcDbObjectId& setFromOldId(Adesk::UIntPtr nUnsignedId)
	{
		const Adesk::IntDbId nSignedId = static_cast<Adesk::IntDbId>(nUnsignedId);
		return this->setFromOldId(nSignedId);
	}
#	endif
/// <summary>
/// Checks, in a safe way (using an exception handler), whether this AcDbObjectId is valid.
/// Valid ids are non-null and map to a non-null AcDbHandle (and to an AcDbObject) in an
/// existing AcDbDatabase.
/// </summary>
/// <returns>True if the id is valid, false otherwise.
/// </returns>
/// <remarks>Even though an id is valid, the AcDbObject it refers to may fail to open.
///          This method may have performance overhead if called in a tight loop.
/// </remarks>
///
	ACDBCORE2D_PORT bool isValid() const;
/// <summary>
/// Checks, in a safe way (using an exception handler), whether this AcDbObjectId
/// is "well behaved".
/// Well-behaved ids may be null, valid or "stale", or they may be a garbage value
/// which happens to fail gracefully (without crashing) when operated on.
/// </summary>
/// <returns>True if this id is well-behaved, false otherwise.
/// </returns>
/// <remarks>It is safe to call functions like acdbOpenObject() and methods like
///          objectClass(), database() and handle() on any well-behaved id.
///          Non-well-behaved ids, however, can cause crashes in these functions.
///          "Stale" ids are those which were once valid but whose owning
///          AcDbDatabase has been destroyed, making them now invalid
///          This method may have performance overhead if called in a tight loop.
/// </remarks>
///
	ACDBCORE2D_PORT bool isWellBehaved() const;
	AcDbObjectId& operator =(const AcDbObjectId&);
	AcDbObjectId& operator =(const AcDbStub*);
	bool operator <(const AcDbObjectId&) const;
	bool operator >(const AcDbObjectId&) const;
	bool operator >=(const AcDbObjectId&) const;
	bool operator <=(const AcDbObjectId&) const;
	bool operator ==(const AcDbObjectId&) const;
	bool operator !=(const AcDbObjectId&) const;
	bool operator <(const AcDbStub*) const;
	bool operator >(const AcDbStub*) const;
	bool operator >=(const AcDbStub*) const;
	bool operator <=(const AcDbStub*) const;
	bool operator ==(const AcDbStub*) const;
	bool operator !=(const AcDbStub*) const;
	operator AcDbStub*() const;
	AcDbDatabase* database() const;
	AcDbDatabase* originalDatabase() const;
/// <summary>
/// Change this id's value to the host id value, if this id is currently being
/// redirected (forwarded) from an xref database to one in the host database.
/// Otherwise, do nothing.
/// </summary>
/// <returns>True if the id was redirected, otherwise false.
/// </returns>
/// <remarks>Only ids of symbol table records can be redirected
/// </remarks>
///
	ACDBCORE2D_PORT bool convertToRedirectedId();
	bool isErased() const;
	bool isEffectivelyErased() const;
	bool isResident() const;
	bool objectLeftOnDisk() const;
	AcDbHandle handle() const;
	AcDbHandle nonForwardedHandle() const;
	AcRxClass* objectClass() const;
protected:
	AcDbStub* mId;
};
class AcDbHardOwnershipId : public AcDbObjectId
{
public:
	AcDbHardOwnershipId();
	AcDbHardOwnershipId(const AcDbObjectId&);
	AcDbHardOwnershipId(const AcDbStub*);
	AcDbHardOwnershipId& operator =(const AcDbHardOwnershipId&);
	AcDbHardOwnershipId& operator =(const AcDbObjectId&);
	AcDbHardOwnershipId& operator =(const AcDbStub*);
	bool operator !=(const AcDbObjectId&) const;
	bool operator !=(const AcDbStub*) const;
	bool operator ==(const AcDbObjectId&) const;
	bool operator ==(const AcDbStub*) const;
	operator AcDbStub*() const;
};
class AcDbSoftOwnershipId : public AcDbObjectId
{
public:
	AcDbSoftOwnershipId();
	AcDbSoftOwnershipId(const AcDbObjectId&);
	AcDbSoftOwnershipId(const AcDbStub*);
	AcDbSoftOwnershipId& operator =(const AcDbSoftOwnershipId&);
	AcDbSoftOwnershipId& operator =(const AcDbObjectId&);
	AcDbSoftOwnershipId& operator =(const AcDbStub*);
	bool operator !=(const AcDbObjectId&) const;
	bool operator !=(const AcDbStub*) const;
	bool operator ==(const AcDbObjectId&) const;
	bool operator ==(const AcDbStub*) const;
	operator AcDbStub*() const;
};
class AcDbHardPointerId : public AcDbObjectId
{
public:
	AcDbHardPointerId();
	AcDbHardPointerId(const AcDbObjectId&);
	AcDbHardPointerId(const AcDbStub*);
	AcDbHardPointerId& operator =(const AcDbHardPointerId&);
	AcDbHardPointerId& operator =(const AcDbObjectId&);
	AcDbHardPointerId& operator =(const AcDbStub*);
	bool operator !=(const AcDbObjectId&) const;
	bool operator !=(const AcDbStub*) const;
	bool operator ==(const AcDbObjectId&) const;
	bool operator ==(const AcDbStub*) const;
	operator AcDbStub*() const;
};
class AcDbSoftPointerId : public AcDbObjectId
{
public:
	AcDbSoftPointerId();
	AcDbSoftPointerId(const AcDbObjectId&);
	AcDbSoftPointerId(const AcDbStub*);
	AcDbSoftPointerId& operator =(const AcDbSoftPointerId&);
	AcDbSoftPointerId& operator =(const AcDbObjectId&);
	AcDbSoftPointerId& operator =(const AcDbStub*);
	bool operator !=(const AcDbObjectId&) const;
	bool operator !=(const AcDbStub*) const;
	bool operator ==(const AcDbObjectId&) const;
	bool operator ==(const AcDbStub*) const;
	operator AcDbStub*() const;
};
#	pragma  pack(pop)
//////////////////// AcDbObjectId inlines ////////////////////
__declspec(selectany) const AcDbObjectId AcDbObjectId::kNull;
inline AcDbObjectId::AcDbObjectId()
{
	mId = nullptr;
}
//inline
//AcDbObjectId::AcDbObjectId(const AcDbObjectId& id)
//{ mId = id.mId; }
inline AcDbObjectId::AcDbObjectId(const AcDbStub* pStub)
{
	mId = const_cast<AcDbStub*>(pStub);
}
inline bool AcDbObjectId::isNull() const
{
	return mId == nullptr;
}
inline void AcDbObjectId::setNull()
{
	mId = nullptr;
}
inline Adesk::IntDbId AcDbObjectId::asOldId() const
{
	return reinterpret_cast<Adesk::IntDbId>(this->mId);
}
inline AcDbObjectId& AcDbObjectId::setFromOldId(Adesk::IntDbId oldId)
{
	this->mId = reinterpret_cast<AcDbStub*>(oldId);
	return *this;
}
inline AcDbObjectId& AcDbObjectId::(const AcDbObjectId& id)
{
	mId = id.mId;
	return *this;
}
inline AcDbObjectId& AcDbObjectId::(const AcDbStub* pStub)
{
	mId = const_cast<AcDbStub*>(pStub);
	return *this;
}
operator AcDbStub*()
{
	return mId;
}
inline bool AcDbObjectId::(const AcDbObjectId& id) const
{
	return mId < id.mId;
}
inline bool AcDbObjectId::(const AcDbObjectId& id) const
{
	return mId > id.mId;
}
inline bool AcDbObjectId::(const AcDbObjectId& id) const
{
	return mId <= id.mId;
}
inline bool AcDbObjectId::(const AcDbObjectId& id) const
{
	return mId >= id.mId;
}
inline bool AcDbObjectId::(const AcDbObjectId& id) const
{
	return mId == id.mId;
}
inline bool AcDbObjectId::(const AcDbObjectId& id) const
{
	return mId != id.mId;
}
inline bool AcDbObjectId::(const AcDbStub* pStub) const
{
	return mId < pStub;
}
inline bool AcDbObjectId::(const AcDbStub* pStub) const
{
	return mId > pStub;
}
inline bool AcDbObjectId::(const AcDbStub* pStub) const
{
	return mId <= pStub;
}
inline bool AcDbObjectId::(const AcDbStub* pStub) const
{
	return mId >= pStub;
}
inline bool AcDbObjectId::(const AcDbStub* pStub) const
{
	return mId == pStub;
}
inline bool AcDbObjectId::(const AcDbStub* pStub) const
{
	return mId != pStub;
}
//////////////////// AcDbHardOwnershipId inlines ////////////////////
inline AcDbHardOwnershipId::AcDbHardOwnershipId()
{
}
inline AcDbHardOwnershipId::AcDbHardOwnershipId(const AcDbObjectId& id)
	: AcDbObjectId(id)
{
}
inline AcDbHardOwnershipId::AcDbHardOwnershipId(const AcDbStub* pStub)
	: AcDbObjectId(pStub)
{
}
inline AcDbHardOwnershipId& AcDbHardOwnershipId::(const AcDbHardOwnershipId& id)
{
	AcDbObjectId::(id);
	return *this;
}
inline AcDbHardOwnershipId& AcDbHardOwnershipId::(const AcDbObjectId& id)
{
	AcDbObjectId::(id);
	return *this;
}
inline AcDbHardOwnershipId& AcDbHardOwnershipId::(const AcDbStub* pStub)
{
	mId = const_cast<AcDbStub*>(pStub);
	return *this;
}
inline bool AcDbHardOwnershipId::(const AcDbObjectId& id) const
{
	return AcDbObjectId::(id);
}
inline bool AcDbHardOwnershipId::(const AcDbStub* pStub) const
{
	return AcDbObjectId::(pStub);
}
inline bool AcDbHardOwnershipId::(const AcDbObjectId& id) const
{
	return AcDbObjectId::(id);
}
inline bool AcDbHardOwnershipId::(const AcDbStub* pStub) const
{
	return AcDbObjectId::(pStub);
}
operator AcDbStub*()
{
	return mId;
}
//////////////////// AcDbSoftOwnershipId inlines ////////////////////
inline AcDbSoftOwnershipId::AcDbSoftOwnershipId()
{
}
inline AcDbSoftOwnershipId::AcDbSoftOwnershipId(const AcDbObjectId& id)
	: AcDbObjectId(id)
{
}
inline AcDbSoftOwnershipId::AcDbSoftOwnershipId(const AcDbStub* pStub)
	: AcDbObjectId(pStub)
{
}
inline AcDbSoftOwnershipId& AcDbSoftOwnershipId::(const AcDbSoftOwnershipId& id)
{
	AcDbObjectId::(id);
	return *this;
}
inline AcDbSoftOwnershipId& AcDbSoftOwnershipId::(const AcDbObjectId& id)
{
	AcDbObjectId::(id);
	return *this;
}
inline AcDbSoftOwnershipId& AcDbSoftOwnershipId::(const AcDbStub* pStub)
{
	mId = const_cast<AcDbStub*>(pStub);
	return *this;
}
inline bool AcDbSoftOwnershipId::(const AcDbObjectId& id) const
{
	return AcDbObjectId::(id);
}
inline bool AcDbSoftOwnershipId::(const AcDbStub* pStub) const
{
	return AcDbObjectId::(pStub);
}
inline bool AcDbSoftOwnershipId::(const AcDbObjectId& id) const
{
	return AcDbObjectId::(id);
}
inline bool AcDbSoftOwnershipId::(const AcDbStub* pStub) const
{
	return AcDbObjectId::(pStub);
}
operator AcDbStub*()
{
	return mId;
}
//////////////////// AcDbHardPointerId inlines ////////////////////
inline AcDbHardPointerId::AcDbHardPointerId()
{
}
inline AcDbHardPointerId::AcDbHardPointerId(const AcDbObjectId& id)
	: AcDbObjectId(id)
{
}
inline AcDbHardPointerId::AcDbHardPointerId(const AcDbStub* pStub)
	: AcDbObjectId(pStub)
{
}
inline AcDbHardPointerId& AcDbHardPointerId::(const AcDbHardPointerId& id)
{
	AcDbObjectId::(id);
	return *this;
}
inline AcDbHardPointerId& AcDbHardPointerId::(const AcDbObjectId& id)
{
	AcDbObjectId::(id);
	return *this;
}
inline AcDbHardPointerId& AcDbHardPointerId::(const AcDbStub* pStub)
{
	mId = const_cast<AcDbStub*>(pStub);
	return *this;
}
inline bool AcDbHardPointerId::(const AcDbObjectId& id) const
{
	return AcDbObjectId::(id);
}
inline bool AcDbHardPointerId::(const AcDbStub* pStub) const
{
	return AcDbObjectId::(pStub);
}
inline bool AcDbHardPointerId::(const AcDbObjectId& id) const
{
	return AcDbObjectId::(id);
}
inline bool AcDbHardPointerId::(const AcDbStub* pStub) const
{
	return AcDbObjectId::(pStub);
}
operator AcDbStub*()
{
	return mId;
}
//////////////////// AcDbSoftPointerId inlines ////////////////////
inline AcDbSoftPointerId::AcDbSoftPointerId()
{
}
inline AcDbSoftPointerId::AcDbSoftPointerId(const AcDbObjectId& id)
	: AcDbObjectId(id)
{
}
inline AcDbSoftPointerId::AcDbSoftPointerId(const AcDbStub* pStub)
	: AcDbObjectId(pStub)
{
}
inline AcDbSoftPointerId& AcDbSoftPointerId::(const AcDbSoftPointerId& id)
{
	AcDbObjectId::(id);
	return *this;
}
inline AcDbSoftPointerId& AcDbSoftPointerId::(const AcDbObjectId& id)
{
	AcDbObjectId::(id);
	return *this;
}
inline AcDbSoftPointerId& AcDbSoftPointerId::(const AcDbStub* pStub)
{
	mId = const_cast<AcDbStub*>(pStub);
	return *this;
}
inline bool AcDbSoftPointerId::(const AcDbObjectId& id) const
{
	return AcDbObjectId::(id);
}
inline bool AcDbSoftPointerId::(const AcDbStub* pStub) const
{
	return AcDbObjectId::(pStub);
}
inline bool AcDbSoftPointerId::(const AcDbObjectId& id) const
{
	return AcDbObjectId::(id);
}
inline bool AcDbSoftPointerId::(const AcDbStub* pStub) const
{
	return AcDbObjectId::(pStub);
}
operator AcDbStub*()
{
	return mId;
}
#	define ADSK_ACDBOBJECTID_DEFINED
#	include "acarrayhelper.h"
#endif
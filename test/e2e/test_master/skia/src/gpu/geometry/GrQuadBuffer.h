/*
 * Copyright 2019 Google LLC
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
#ifndef GrQuadBuffer_DEFINED
#  define GrQuadBuffer_DEFINED
#  include "include/private/SkTDArray.h"
#  include "src/gpu/geometry/GrQuad.h"
template <typename T>
class GrQuadBuffer
{
public:
  GrQuadBuffer()
    : fCount(0)
    , fDeviceType(GrQuad::Type::kAxisAligned)
    , fLocalType(GrQuad::Type::kAxisAligned)
  {
        // Pre-allocate space for 1 2D device-space quad, metadata, and header
    fData.reserve(this->entrySize(fDeviceType, nullptr));
  }
    // Reserves space for the given number of entries; if 'needsLocals' is true, space will be
    // reserved for each entry to also have a 2D local quad. The reserved space assumes 2D device
    // quad for simplicity. Since this buffer has a variable bitrate encoding for quads, this may
    // over or under reserve, but pre-allocating still helps when possible.
  GrQuadBuffer(int count, bool needsLocals = false)
    : fCount(0)
    , fDeviceType(GrQuad::Type::kAxisAligned)
    , fLocalType(GrQuad::Type::kAxisAligned)
  {
    int entrySize = this->entrySize(fDeviceType, needsLocals ? &fLocalType : nullptr);
    fData.reserve(count * entrySize);
  }
    // The number of device-space quads (and metadata, and optional local quads) that are in the
    // the buffer.
  int count() const
  {
    return fCount;
  }
    // The most general type for the device-space quads in this buffer
  GrQuad::Type deviceQuadType() const
  {
    return fDeviceType;
  }
    // The most general type for the local quads; if no local quads are ever added, this will
    // return kAxisAligned.
  GrQuad::Type localQuadType() const
  {
    return fLocalType;
  }
    // Append the given 'deviceQuad' to this buffer, with its associated 'metadata'. If 'localQuad'
    // is not null, the local coordinates will also be attached to the entry. When an entry
    // has local coordinates, during iteration, the Iter::hasLocals() will return true and its
    // Iter::localQuad() will be equivalent to the provided local coordinates. If 'localQuad' is
    // null then Iter::hasLocals() will report false for the added entry.
  void append(const GrQuad& deviceQuad, T&& metadata, const GrQuad* localQuad = nullptr);
    // Copies all entries from 'that' to this buffer
  void concat(const GrQuadBuffer<T>& that);
    // Provides a read-only iterator over a quad buffer, giving access to the device quad, metadata
    // and optional local quad.
  class Iter
  {
  public:
    Iter(const GrQuadBuffer<T>* buffer)
      : fDeviceQuad(SkRect::MakeEmpty())
      , fLocalQuad(SkRect::MakeEmpty())
      , fBuffer(buffer)
      , fCurrentEntry(nullptr)
      , fNextEntry(buffer->fData.begin())
    {
    }
    bool next();
    const T& metadata() const
    {
      this->validate();
      return *(fBuffer->metadata(fCurrentEntry));
    }
    const GrQuad& deviceQuad() const
    {
      this->validate();
      return fDeviceQuad;
    }
        // If isLocalValid() returns false, this returns an empty quad (all 0s) so that localQuad()
        // can be called without triggering any sanitizers, for convenience when some other state
        // ensures that the quad will eventually not be used.
    const GrQuad& localQuad() const
    {
      this->validate();
      return fLocalQuad;
    }
    bool isLocalValid() const
    {
      this->validate();
      return fBuffer->header(fCurrentEntry)->fHasLocals;
    }
  private:
        // Quads are stored locally so that calling code doesn't need to re-declare their own quads
    GrQuad fDeviceQuad;
    GrQuad fLocalQuad;
    const GrQuadBuffer<T>* fBuffer;
        // The pointer to the current entry to read metadata/header details from
    const char* fCurrentEntry;
        // The pointer to replace fCurrentEntry when next() is called, cached since it is calculated
        // automatically while unpacking the quad data.
    const char* fNextEntry;
    void validate() const
    {
    }
  };
  Iter iterator() const
  {
    return Iter(this);
  }
    // Provides a *mutable* iterator over just the metadata stored in the quad buffer. This skips
    // unpacking the device and local quads into GrQuads and is intended for use during op
    // finalization, which may require rewriting state such as color.
  class MetadataIter
  {
  public:
    MetadataIter(GrQuadBuffer<T>* list)
      : fBuffer(list)
      , fCurrentEntry(nullptr)
    {
    }
    bool next();
    T& operator*()
    {
      this->validate();
      return *(fBuffer->metadata(fCurrentEntry));
    }
    T* operator->()
    {
      this->validate();
      return fBuffer->metadata(fCurrentEntry);
    }
  private:
    GrQuadBuffer<T>* fBuffer;
    char* fCurrentEntry;
    void validate() const
    {
    }
  };
  MetadataIter metadata()
  {
    return MetadataIter(this);
  }
private:
  struct alignas(int32_t) Header
  {
    unsigned fDeviceType;
    unsigned fLocalType;
    unsigned fHasLocals;
        // Known value to detect if iteration doesn't properly advance through the buffer
  };
  static_assert(sizeof(Header) == sizeof(int32_t), "Header should be 4 bytes");
  static unsigned kSentinel = 0xbaffe;
  static int kMetaSize = sizeof(Header) + sizeof(T);
  static int k2DQuadFloats = 8;
  static int k3DQuadFloats = 12;
    // Each logical entry in the buffer is a variable length tuple storing device coordinates,
    // optional local coordinates, and metadata. An entry always has a header that defines the
    // quad types of device and local coordinates, and always has metadata of type T. The device
    // and local quads' data follows as a variable length array of floats:
    //  [ header    ] = 4 bytes
    //  [ metadata  ] = sizeof(T), assert alignof(T) == 4 so that pointer casts are valid
    //  [ device xs ] = 4 floats = 16 bytes
    //  [ device ys ] = 4 floats
    //  [ device ws ] = 4 floats or 0 floats depending on fDeviceType in header
    //  [ local xs  ] = 4 floats or 0 floats depending on fHasLocals in header
    //  [ local ys  ] = 4 floats or 0 floats depending on fHasLocals in header
    //  [ local ws  ] = 4 floats or 0 floats depending on fHasLocals and fLocalType in header
    // FIXME (michaelludwig) - Since this is intended only for ops, can we use the arena to
    //      allocate storage for the quad buffer? Since this is forward-iteration only, could also
    //      explore a linked-list structure for concatenating quads when batching ops
  SkTDArray<char> fData;
  int fCount;
  GrQuad::Type fDeviceType;
  GrQuad::Type fLocalType;
  inline int entrySize(GrQuad::Type deviceType, const GrQuad::Type* localType) const
  {
    int size = kMetaSize;
    size += (deviceType == GrQuad::Type::kPerspective ? k3DQuadFloats : k2DQuadFloats) * sizeof(float);
    if (localType)
    {
      size += (*localType == GrQuad::Type::kPerspective ? k3DQuadFloats : k2DQuadFloats) * sizeof(float);
    }
    return size;
  }
  inline int entrySize(const Header* header) const
  {
    if (header->fHasLocals)
    {
      GrQuad::Type localType = static_cast<GrQuad::Type>(header->fLocalType);
      return this->entrySize(static_cast<GrQuad::Type>(header->fDeviceType), &localType);
    }
    else 
    {
      return this->entrySize(static_cast<GrQuad::Type>(header->fDeviceType), nullptr);
    }
  }
    // Helpers to access typed sections of the buffer, given the start of an entry
  inline Header* header(char* entry)
  {
    return static_cast<Header*>(static_cast<void*>(entry));
  }
  inline const Header* header(const char* entry) const
  {
    return static_cast<const Header*>(static_cast<const void*>(entry));
  }
  inline T* metadata(char* entry)
  {
    return static_cast<T*>(static_cast<void*>(entry + sizeof(Header)));
  }
  inline const T* metadata(const char* entry) const
  {
    return static_cast<const T*>(static_cast<const void*>(entry + sizeof(Header)));
  }
  inline float* coords(char* entry)
  {
    return static_cast<float*>(static_cast<void*>(entry + kMetaSize));
  }
  inline const float* coords(const char* entry) const
  {
    return static_cast<const float*>(static_cast<const void*>(entry + kMetaSize));
  }
    // Helpers to convert from coordinates to GrQuad and vice versa, returning pointer to the
    // next packed quad coordinates.
  float* packQuad(const GrQuad& quad, float* coords);
  const float* unpackQuad(GrQuad::Type type, const float* coords, GrQuad* quad) const;
#  ifdef SK_DEBUG
  void validate(const char* entry, int expectedCount) const;
#  endif
};
///////////////////////////////////////////////////////////////////////////////////////////////////
// Buffer implementation
///////////////////////////////////////////////////////////////////////////////////////////////////
template <typename T>
float* GrQuadBuffer<T>::packQuad(const GrQuad& quad, float* coords)
{
    // Copies all 12 (or 8) floats at once, so requires the 3 arrays to be contiguous
    // FIXME(michaelludwig) - If this turns out not to be the case, just do 4 copies
  SkASSERT(quad.xs() + 4 == quad.ys() && quad.xs() + 8 == quad.ws());
  if (quad.hasPerspective())
  {
    memcpy(coords, quad.xs(), k3DQuadFloats * sizeof(float));
    return coords + k3DQuadFloats;
  }
  else 
  {
    memcpy(coords, quad.xs(), k2DQuadFloats * sizeof(float));
    return coords + k2DQuadFloats;
  }
}
template <typename T>
const float* GrQuadBuffer<T>::unpackQuad(GrQuad::Type type, const float* coords, GrQuad* quad) const
{
  SkASSERT(quad->xs() + 4 == quad->ys() && quad->xs() + 8 == quad->ws());
  if (type == GrQuad::Type::kPerspective)
  {
        // Fill in X, Y, and W in one go
    memcpy(quad->xs(), coords, k3DQuadFloats * sizeof(float));
    coords = coords + k3DQuadFloats;
  }
  else 
  {
        // Fill in X and Y of the quad, and set W to 1s if needed
    memcpy(quad->xs(), coords, k2DQuadFloats * sizeof(float));
    coords = coords + k2DQuadFloats;
    if (quad->quadType() == GrQuad::Type::kPerspective)
    {
            // The output quad was previously perspective, so its ws are not 1s
      static float kNoPerspectiveWs[4] = {1.f, 1.f, 1.f, 1.f};
      memcpy(quad->ws(), kNoPerspectiveWs, 4 * sizeof(float));
    }
        // Else the quad should already have 1s in w
    SkASSERT(quad->w(0) == 1.f && quad->w(1) == 1.f && quad->w(2) == 1.f && quad->w(3) == 1.f);
  }
  quad->setQuadType(type);
  return coords;
}
template <typename T>
void GrQuadBuffer<T>::append(const GrQuad& deviceQuad, T&& metadata, const GrQuad* localQuad)
{
  GrQuad::Type localType = localQuad ? localQuad->quadType() : GrQuad::Type::kAxisAligned;
  int entrySize = this->entrySize(deviceQuad.quadType(), localQuad ? &localType : nullptr);
    // Fill in the entry, as described in fData's declaration
  char* entry = fData.append(entrySize);
    // First the header
  Header* h = this->header(entry);
  h->fDeviceType = static_cast<unsigned>(deviceQuad.quadType());
  h->fHasLocals = static_cast<unsigned>(localQuad != nullptr);
  h->fLocalType = static_cast<unsigned>(localQuad ? localQuad->quadType() : GrQuad::Type::kAxisAligned);
  static_assert(alignof(T) == 4, "Metadata must be 4 byte aligned");
  *(this->metadata(entry)) = std::move(metadata);
    // Then the variable blocks of x, y, and w float coordinates
  float* coords = this->coords(entry);
  coords = this->packQuad(deviceQuad, coords);
  if (localQuad)
  {
    coords = this->packQuad(*localQuad, coords);
  }
  SkASSERT((char*) coords - entry == entrySize);
    // Entry complete, update buffer-level state
  fCount++;
  if (deviceQuad.quadType() > fDeviceType)
  {
    fDeviceType = deviceQuad.quadType();
  }
  if (localQuad && localQuad->quadType() > fLocalType)
  {
    fLocalType = localQuad->quadType();
  }
}
template <typename T>
void GrQuadBuffer<T>::concat(const GrQuadBuffer<T>& that)
{
  fData.append(that.fData.count(), that.fData.begin());
  fCount += that.fCount;
  if (that.fDeviceType > fDeviceType)
  {
    fDeviceType = that.fDeviceType;
  }
  if (that.fLocalType > fLocalType)
  {
    fLocalType = that.fLocalType;
  }
}
#  ifdef SK_DEBUG
template <typename T>
void GrQuadBuffer<T>::validate(const char* entry, int expectedCount) const
{
    // Triggers if accessing before next() is called on an iterator
  SkASSERT(entry);
    // Triggers if accessing after next() returns false
  SkASSERT(entry < fData.end());
    // Triggers if elements have been added to the buffer while iterating entries
  SkASSERT(expectedCount == fCount);
    // Make sure the start of the entry looks like a header
  SkASSERT(this->header(entry)->fSentinel == kSentinel);
}
#  endif
///////////////////////////////////////////////////////////////////////////////////////////////////
// Iterator implementations
///////////////////////////////////////////////////////////////////////////////////////////////////
template <typename T>
bool GrQuadBuffer<T>::Iter::next()
{
  SkASSERT(fNextEntry);
  if (fNextEntry >= fBuffer->fData.end())
  {
    return false;
  }
    // There is at least one more entry, so store the current start for metadata access
  fCurrentEntry = fNextEntry;
    // And then unpack the device and optional local coordinates into fDeviceQuad and fLocalQuad
  const Header* h = fBuffer->header(fCurrentEntry);
  const float* coords = fBuffer->coords(fCurrentEntry);
  coords = fBuffer->unpackQuad(static_cast<GrQuad::Type>(h->fDeviceType), coords, &fDeviceQuad);
  if (h->fHasLocals)
  {
    coords = fBuffer->unpackQuad(static_cast<GrQuad::Type>(h->fLocalType), coords, &fLocalQuad);
  }
  else 
  {
    static const GrQuad kEmptyLocal(SkRect::MakeEmpty());
    fLocalQuad = kEmptyLocal;
  }
    // At this point, coords points to the start of the next entry
  fNextEntry = static_cast<const char*>(static_cast<const void*>(coords));
  SkASSERT((fNextEntry - fCurrentEntry) == fBuffer->entrySize(h));
  return true;
}
template <typename T>
bool GrQuadBuffer<T>::MetadataIter::next()
{
  if (fCurrentEntry)
  {
        // Advance pointer by entry size
    if (fCurrentEntry < fBuffer->fData.end())
    {
      const Header* h = fBuffer->header(fCurrentEntry);
      fCurrentEntry += fBuffer->entrySize(h);
    }
  }
  else 
  {
        // First call to next
    fCurrentEntry = fBuffer->fData.begin();
  }
    // Nothing else is needed to do but report whether or not the updated pointer is valid
  return fCurrentEntry < fBuffer->fData.end();
}
#endif

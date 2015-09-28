// =================================================================================================
//
//  Starling Framework
//  Copyright 2011-2015 Gamua. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.utils
{
    import flash.display3D.Context3D;
    import flash.display3D.IndexBuffer3D;
    import flash.utils.ByteArray;
    import flash.utils.Endian;

    import starling.core.Starling;
    import starling.errors.MissingContextError;

    /** The IndexData class manages a raw list of vertex indices, allowing direct upload
     *  to Stage3D index buffers. <em>You only have to work with this class if you're writing
     *  your own rendering code (e.g. if you create custom display objects).</em>
     *
     *  <p>To render objects with Stage3D, you have to organize vertices and indices in so-called
     *  vertex- and index buffers. Vertex buffers store the coordinates of the vertices that make
     *  up an object; index buffers reference those vertices to determine which vertices spawn
     *  up triangles. Those buffers reside in graphics memory and can be accessed very
     *  efficiently by the GPU.</p>
     *
     *  <p>Before you can move data into the buffers, you have to set it up in conventional
     *  memory - that is, in a Vector or a ByteArray. Since it's quite cumbersome to manually
     *  create and manipulate those data structures, the IndexData and VertexData classes provide
     *  a simple way to do just that. The data is stored in a ByteArray (one index or vertex after
     *  the other) that can easily be uploaded to a buffer.</p>
     *
     *  @see VertexData
     */
    public class IndexData
    {
        /** The number of bytes per index element. */
        private static const INDEX_SIZE:int = 2;

        private var _rawData:ByteArray;
        private var _numIndices:int;

        // helper object
        private static var sVector:Vector.<uint> = new <uint>[];
        private static var sBytes:ByteArray = new ByteArray();

        /** Creates a new IndexData instance with the given capacity (in indices). The capacity
         *  affects the size of the internal ByteArray, not the <code>numIndices</code> value,
         *  which will always be zero when the constructor returns. For more information about this
         *  behavior, please refer to the documentation of the <code>numIndices</code>-property.
         */
        public function IndexData(initialCapacity:int=24)
        {
            _rawData = new ByteArray();
            _rawData.endian = Endian.LITTLE_ENDIAN;
            _rawData.length = initialCapacity * INDEX_SIZE;
            _numIndices = 0;
        }

        /** Explicitly frees up the memory used by the ByteArray. */
        public function clear():void
        {
            _rawData.clear();
            _numIndices = 0;
        }

        /** Creates a duplicate of either the complete IndexData object, or of a subset.
         *  To clone all indices, call the method without any arguments. */
        public function clone(indexID:int=0, numIndices:int=-1):IndexData
        {
            if (numIndices < 0 || indexID + numIndices > _numIndices)
                numIndices = _numIndices - indexID;

            var clone:IndexData = new IndexData(numIndices);
            clone._rawData.writeBytes(_rawData, indexID * INDEX_SIZE, numIndices * INDEX_SIZE);
            clone._numIndices = numIndices;

            return clone;
        }

        /** Copies the index data (or a range of it, defined by 'indexID' and 'numIndices')
         *  of this instance to another IndexData object, starting at a certain index. If the
         *  target is not big enough, it will be resized to fit all the new indices. */
        public function copyTo(target:IndexData, targetIndexID:int=0,
                               indexID:int=0, numIndices:int=-1):void
        {
            if (numIndices < 0 || indexID + numIndices > _numIndices)
                numIndices = _numIndices - indexID;

            target._rawData.position = targetIndexID * INDEX_SIZE;
            target._rawData.writeBytes(_rawData, indexID * INDEX_SIZE, numIndices * INDEX_SIZE);

            if (target._numIndices < targetIndexID + numIndices)
                target._numIndices = targetIndexID + numIndices;
        }

        /** Sets an index at the specified position. */
        public function setIndex(indexID:int, index:uint):void
        {
            _rawData.position = indexID * INDEX_SIZE;
            _rawData.writeShort(index);

            if (_numIndices < index + 1)
                _numIndices = index + 1;
        }

        /** Reads the index from the specified position. */
        public function getIndex(indexID:int):int
        {
            _rawData.position = indexID * INDEX_SIZE;
            return _rawData.readUnsignedShort();
        }

        /** Adds an offset to all indices in the specified range. */
        public function offsetIndices(offset:int, indexID:int=0, numIndices:int=-1):void
        {
            if (numIndices < 0 || indexID + numIndices > _numIndices)
                numIndices = _numIndices - indexID;

            var endIndex:int = indexID + numIndices;

            for (var i:int=indexID; i<endIndex; ++i)
                setIndex(i, getIndex(i) + offset);
        }

        /** Appends three indices representing a triangle. */
        public function appendTriangle(a:uint, b:uint, c:uint):void
        {
            _rawData.position = _numIndices * INDEX_SIZE;
            _rawData.writeShort(a);
            _rawData.writeShort(b);
            _rawData.writeShort(c);
            _numIndices += 3;
        }

        /** Creates a vector containing all indices. If you pass an existing vector to the method,
         *  its contents will be overwritten. */
        public function toVector(out:Vector.<uint>=null):Vector.<uint>
        {
            if (out == null) out = new Vector.<uint>(_numIndices);
            else out.length = _numIndices;

            _rawData.position = 0;

            for (var i:int=0; i<_numIndices; ++i)
                out[i] = _rawData.readUnsignedShort();

            return out;
        }

        /** Returns a string representation of the IndexData object,
         *  including a comma-separated list of all indices. */
        public function toString():String
        {
            var string:String = StringUtil.format("[IndexData numIndices={0} indices=\"{1}\"]",
                _numIndices, toVector(sVector).join());

            sVector.length = 0;
            return string;
        }

        // IndexBuffer helpers

        /** Creates an index buffer object with the right size to fit the complete data.
         *  Optionally, the current data is uploaded right away. */
        public function createIndexBuffer(upload:Boolean=false,
                                          bufferUsage:String="staticDraw"):IndexBuffer3D
        {
            var context:Context3D = Starling.context;
            if (context == null) throw new MissingContextError();

            var buffer:IndexBuffer3D = context.createIndexBuffer(_numIndices, bufferUsage);

            if (upload) uploadToIndexBuffer(buffer);
            return buffer;
        }

        /** Uploads the complete data (or a section of it) to the given index buffer. */
        public function uploadToIndexBuffer(buffer:IndexBuffer3D, indexID:int=0, numIndices:int=-1):void
        {
            if (numIndices < 0 || indexID + numIndices > _numIndices)
                numIndices = _numIndices - indexID;

            buffer.uploadFromByteArray(_rawData, 0, indexID, numIndices);
        }

        /** Optimizes the ByteArray so that it has exactly the required capacity, without
         *  wasting any memory. If your IndexData object grows larger than the initial capacity
         *  you passed to the constructor, call this method to avoid the 4k memory problem. */
        public function trim():void
        {
            sBytes.length = _rawData.length;
            sBytes.position = 0;
            sBytes.writeBytes(_rawData);

            _rawData.clear();
            _rawData.length = sBytes.length;
            _rawData.writeBytes(sBytes);

            sBytes.clear();
        }

        // properties

        /** The total number of indices. If you make the object bigger, it will be filled up with
         *  indices set to zero.
         *
         *  <p>Beware: ByteArrays organize their memory in a very peculiar way. The first time
         *  you set their length, they adhere to that: a ByteArray with length 20 will take up 20
         *  bytes. When you change it to a smaller length, they will stick to the original value,
         *  i.e. a length of 10 will still take up 20 bytes. However, here comes the surprise:
         *  change them to anything above their original length, and they will allocate a total
         *  of 4096 bytes!</p>
         *
         *  <p>That's why it is important to always make use of the <code>initialCapacity</code>
         *  parameter in the IndexData constructor, as this determines the initial size of the
         *  ByteArray.</p>
         */
        public function get numIndices():int { return _numIndices; }
        public function set numIndices(value:int):void
        {
            if (value != _numIndices)
            {
                _rawData.length = value * INDEX_SIZE;
                _numIndices = value;
            }
        }

        /** The number of triangles that can be spawned up with the contained indices.
         *  (In other words: the number of indices divided by three.) */
        public function get numTriangles():int { return _numIndices / 3; }
        public function set numTriangles(value:int):void { numIndices = value * 3; }

        /** The number of bytes required for each index value. */
        public function get indexSizeInBytes():int { return INDEX_SIZE; }

        /** The raw index data; not a copy! */
        public function get rawData():ByteArray { return _rawData; }
    }
}
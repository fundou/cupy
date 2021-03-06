# distutils: language = c++

"""Thin wrapper of Thrust implementations for CuPy API."""

import numpy

cimport cython  # NOQA
from libc.stdint cimport intptr_t
from libcpp cimport vector

from cupy.cuda cimport common
from cupy.cuda cimport device
from cupy.cuda cimport memory
from cupy.cuda cimport runtime
from cupy.cuda cimport stream


###############################################################################
# Memory Management
###############################################################################

# Before attempting to refactor this part, read the discussion in #3212 first.

cdef class _MemoryManager:
    cdef:
        dict memory

    def __init__(self):
        self.memory = dict()


cdef public char* cupy_malloc(void *m, size_t size) with gil:
    if size == 0:
        return <char *>0
    cdef _MemoryManager mm = <_MemoryManager>m
    mem = memory.alloc(size)
    mm.memory[mem.ptr] = mem
    return <char *>mem.ptr


cdef public void cupy_free(void *m, char* ptr) with gil:
    if ptr == <char *>0:
        return
    cdef _MemoryManager mm = <_MemoryManager>m
    del mm.memory[<size_t>ptr]


###############################################################################
# Extern
###############################################################################

cdef extern from '../cuda/cupy_thrust.h' namespace 'cupy::thrust':
    void _sort[T](void *, size_t *, const vector.vector[ptrdiff_t]&, intptr_t,
                  void *)
    void _lexsort[T](size_t *, void *, size_t, size_t, intptr_t, void *)
    void _argsort[T](size_t *, void *, void *, const vector.vector[ptrdiff_t]&,
                     intptr_t, void *)

    # for half precision
    # TODO(leofang): eliminate the extra delegation call when we have a dtype
    # dispatcher in C++
    void _sort_fp16(void *, size_t *, const vector.vector[ptrdiff_t]&,
                    intptr_t, void *)
    void _lexsort_fp16(size_t *, void *, size_t, size_t, intptr_t, void *)
    void _argsort_fp16(size_t *, void *, void *,
                       const vector.vector[ptrdiff_t]&, intptr_t, void *)

cdef extern from '../cuda/cupy_thrust.h':
    # Build-time version
    int THRUST_VERSION


###############################################################################
# Python interface
###############################################################################

def get_build_version():
    return THRUST_VERSION


cpdef sort(dtype, intptr_t data_start, intptr_t keys_start,
           const vector.vector[ptrdiff_t]& shape) except +:

    cdef void* _data_start = <void*>data_start
    cdef size_t* _keys_start = <size_t*>keys_start
    cdef intptr_t _strm = stream.get_current_stream_ptr()
    cdef _MemoryManager mem_obj = _MemoryManager()
    cdef void* mem = <void*>mem_obj

    if dtype == numpy.float16:
        if int(device.get_compute_capability()) < 53 or \
                runtime.runtimeGetVersion() < 9020:
            raise RuntimeError('either the GPU or the CUDA Toolkit does not '
                               'support fp16')

    if dtype == numpy.int8:
        _sort[common.cpy_byte](_data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.uint8:
        _sort[common.cpy_ubyte](_data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.int16:
        _sort[common.cpy_short](_data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.uint16:
        _sort[common.cpy_ushort](_data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.int32:
        _sort[common.cpy_int](_data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.uint32:
        _sort[common.cpy_uint](_data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.int64:
        _sort[common.cpy_long](_data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.uint64:
        _sort[common.cpy_ulong](_data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.float16:
        _sort_fp16(_data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.float32:
        _sort[common.cpy_float](_data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.float64:
        _sort[common.cpy_double](_data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.complex64:
        _sort[common.cpy_complex64](
            _data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.complex128:
        _sort[common.cpy_complex128](
            _data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.bool:
        _sort[common.cpy_bool](_data_start, _keys_start, shape, _strm, mem)
    else:
        raise NotImplementedError('Sorting arrays with dtype \'{}\' is not '
                                  'supported'.format(dtype))


cpdef lexsort(dtype, intptr_t idx_start, intptr_t keys_start,
              size_t k, size_t n) except +:

    cdef size_t* idx_ptr = <size_t*>idx_start
    cdef void* keys_ptr = <void*>keys_start
    cdef intptr_t _strm = stream.get_current_stream_ptr()
    cdef _MemoryManager mem_obj = _MemoryManager()
    cdef void* mem = <void*>mem_obj

    if dtype == numpy.float16:
        if int(device.get_compute_capability()) < 53 or \
                runtime.runtimeGetVersion() < 9020:
            raise RuntimeError('either the GPU or the CUDA Toolkit does not '
                               'support fp16')

    if dtype == numpy.int8:
        _lexsort[common.cpy_byte](idx_ptr, keys_ptr, k, n, _strm, mem)
    elif dtype == numpy.uint8:
        _lexsort[common.cpy_ubyte](idx_ptr, keys_ptr, k, n, _strm, mem)
    elif dtype == numpy.int16:
        _lexsort[common.cpy_short](idx_ptr, keys_ptr, k, n, _strm, mem)
    elif dtype == numpy.uint16:
        _lexsort[common.cpy_ushort](idx_ptr, keys_ptr, k, n, _strm, mem)
    elif dtype == numpy.int32:
        _lexsort[common.cpy_int](idx_ptr, keys_ptr, k, n, _strm, mem)
    elif dtype == numpy.uint32:
        _lexsort[common.cpy_uint](idx_ptr, keys_ptr, k, n, _strm, mem)
    elif dtype == numpy.int64:
        _lexsort[common.cpy_long](idx_ptr, keys_ptr, k, n, _strm, mem)
    elif dtype == numpy.uint64:
        _lexsort[common.cpy_ulong](idx_ptr, keys_ptr, k, n, _strm, mem)
    elif dtype == numpy.float16:
        _lexsort_fp16(idx_ptr, keys_ptr, k, n, _strm, mem)
    elif dtype == numpy.float32:
        _lexsort[common.cpy_float](idx_ptr, keys_ptr, k, n, _strm, mem)
    elif dtype == numpy.float64:
        _lexsort[common.cpy_double](idx_ptr, keys_ptr, k, n, _strm, mem)
    elif dtype == numpy.complex64:
        _lexsort[common.cpy_complex64](idx_ptr, keys_ptr, k, n, _strm, mem)
    elif dtype == numpy.complex128:
        _lexsort[common.cpy_complex128](idx_ptr, keys_ptr, k, n, _strm, mem)
    elif dtype == numpy.bool:
        _lexsort[common.cpy_bool](idx_ptr, keys_ptr, k, n, _strm, mem)
    else:
        raise TypeError('Sorting keys with dtype \'{}\' is not '
                        'supported'.format(dtype))


cpdef argsort(dtype, intptr_t idx_start, intptr_t data_start,
              intptr_t keys_start,
              const vector.vector[ptrdiff_t]& shape) except +:

    cdef size_t*_idx_start = <size_t*>idx_start
    cdef void* _data_start = <void*>data_start
    cdef size_t* _keys_start = <size_t*>keys_start
    cdef intptr_t _strm = stream.get_current_stream_ptr()
    cdef _MemoryManager mem_obj = _MemoryManager()
    cdef void* mem = <void *>mem_obj

    if dtype == numpy.float16:
        if int(device.get_compute_capability()) < 53 or \
                runtime.runtimeGetVersion() < 9020:
            raise RuntimeError('either the GPU or the CUDA Toolkit does not '
                               'support fp16')

    if dtype == numpy.int8:
        _argsort[common.cpy_byte](
            _idx_start, _data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.uint8:
        _argsort[common.cpy_ubyte](
            _idx_start, _data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.int16:
        _argsort[common.cpy_short](
            _idx_start, _data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.uint16:
        _argsort[common.cpy_ushort](
            _idx_start, _data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.int32:
        _argsort[common.cpy_int](
            _idx_start, _data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.uint32:
        _argsort[common.cpy_uint](
            _idx_start, _data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.int64:
        _argsort[common.cpy_long](
            _idx_start, _data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.uint64:
        _argsort[common.cpy_ulong](
            _idx_start, _data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.float16:
        _argsort_fp16(
            _idx_start, _data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.float32:
        _argsort[common.cpy_float](
            _idx_start, _data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.float64:
        _argsort[common.cpy_double](
            _idx_start, _data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.complex64:
        _argsort[common.cpy_complex64](
            _idx_start, _data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.complex128:
        _argsort[common.cpy_complex128](
            _idx_start, _data_start, _keys_start, shape, _strm, mem)
    elif dtype == numpy.bool:
        _argsort[common.cpy_bool](
            _idx_start, _data_start, _keys_start, shape, _strm, mem)
    else:
        raise NotImplementedError('Sorting arrays with dtype \'{}\' is not '
                                  'supported'.format(dtype))

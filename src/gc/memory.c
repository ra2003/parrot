/*
Copyright (C) 2001-2007, The Perl Foundation.
$Id$

=head1 NAME

src/memory.c - Memory allocation

=head1 DESCRIPTION

The memory (mem) API handles memory allocation,

Basically just a wrapper C<around malloc/calloc/realloc/free()> with an
setup function to initialize the memory pools.

=head2 Functions

*/

#include "parrot/parrot.h"
#include "parrot/memory.h"

/* HEADERIZER TARGET: include/parrot/memory.h */

/*

FUNCDOC: mem_sys_allocate

Uses C<malloc> to allocate system memory.

*/

PARROT_API
void *
mem_sys_allocate(size_t size)
    /* MALLOC, WARN_UNUSED */
{
    void * const ptr = malloc((size_t)size);
#ifdef DETAIL_MEMORY_DEBUG
    fprintf(stderr, "Allocated %i at %p\n", size, ptr);
#endif
    if (!ptr)
        PANIC(NULL, "Out of mem");
    return ptr;
}

void *
mem__internal_allocate(size_t size, const char *file, int line)
    /* MALLOC, WARN_UNUSED */
{
    void * const ptr = malloc((size_t)size);
#ifdef DETAIL_MEMORY_DEBUG
    fprintf(stderr, "Internal malloc %i at %p (%s/%d)\n",
            size, ptr, file, line);
#else
    UNUSED(file);
    UNUSED(line);
#endif
    if (!ptr)
        PANIC(NULL, "Out of mem");
    return ptr;
}

/*

FUNCDOC: mem_sys_allocate_zeroed

Uses C<calloc> to allocate system memory.

*/

PARROT_API
void *
mem_sys_allocate_zeroed(size_t size)
    /* MALLOC, WARN_UNUSED */
{
    void * const ptr = calloc(1, (size_t)size);
#ifdef DETAIL_MEMORY_DEBUG
    fprintf(stderr, "Allocated %i at %p\n", size, ptr);
#endif
    if (!ptr && size)
        PANIC(NULL, "Out of mem");
    return ptr;
}

void *
mem__internal_allocate_zeroed(size_t size, const char *file, int line)
    /* MALLOC, WARN_UNUSED */
{
    void * const ptr = calloc(1, (size_t)size);
#ifdef DETAIL_MEMORY_DEBUG
    fprintf(stderr, "Internal malloc %i at %p (%s/%d)\n",
            size, ptr, file, line);
#else
    UNUSED(file);
    UNUSED(line);
#endif
    if (!ptr && size)
        PANIC(NULL, "Out of mem");
    return ptr;
}

/*

FUNCDOC: mem_sys_realloc

Resize a chunk of system memory.

*/

PARROT_API
void *
mem__sys_realloc(void *from /*NULLOK*/, size_t size)
    /* MALLOC, WARN_UNUSED */
{
    void *ptr;
#ifdef DETAIL_MEMORY_DEBUG
    fprintf(stderr, "Freed %p (realloc -- %i bytes)\n", from, size);
#endif
    ptr = realloc(from, size);
#ifdef DETAIL_MEMORY_DEBUG
    fprintf(stderr, "Allocated %i at %p\n", size, ptr);
#endif
    if (!ptr)
         PANIC(NULL, "Out of mem");
    return ptr;
}


/*

FUNCDOC: mem_sys_realloc_zeroed

Resize a chunk of system memory. Fill the newly allocated space with zeroes.

*/

PARROT_API
void *
mem__sys_realloc_zeroed(void *from /*NULLOK*/, size_t size, size_t old_size)
    /* MALLOC, WARN_UNUSED */
{
    void *ptr;
#ifdef DETAIL_MEMORY_DEBUG
    fprintf(stderr, "Freed %p (realloc -- %i bytes)\n", from, size);
#endif
    ptr = realloc(from, size);
#ifdef DETAIL_MEMORY_DEBUG
    fprintf(stderr, "Allocated %i at %p\n", size, ptr);
#endif
    if (!ptr)
         PANIC(NULL, "Out of mem");

    if (size > old_size)
        memset((char*)ptr + old_size, 0, size - old_size);

    return ptr;
}

void *
mem__internal_realloc(void *from /*NN*/, size_t size,
        const char *file /*NN*/, int line)
    /* MALLOC, WARN_UNUSED */
{
    void * const ptr = realloc(from, size);
#ifdef DETAIL_MEMORY_DEBUG
    fprintf(stderr, "internal free of %p (realloc -- %i bytes) (%s/%d)\n",
            from, size, file, line);
    fprintf(stderr, "Internal malloc %i at %p (%s/%d)\n",
            size, ptr, file, line);
#else
    UNUSED(file);
    UNUSED(line);
#endif
    if (!ptr)
        PANIC(NULL, "Out of mem");
    return ptr;
}

/*

FUNCDOC: mem_sys_free

Free a chunk of memory back to the system.

*/

PARROT_API
void
mem_sys_free(void * from)
{
#ifdef DETAIL_MEMORY_DEBUG
    fprintf(stderr, "Freed %p\n", from);
#endif
    if (from)
        free(from);
}

void
mem__internal_free(void *from, const char *file /*NN*/, int line)
{
#ifdef DETAIL_MEMORY_DEBUG
    fprintf(stderr, "Internal free of %p (%s/%d)\n", from, file, line);
#endif
    free(from);
}

/*

FUNCDOC: mem_setup_allocator

Initializes the allocator.

*/

void
mem_setup_allocator(Interp *interp /*NN*/)
{
    interp->arena_base = mem_allocate_zeroed_typed(Arenas);
    interp->arena_base->sized_header_pools = NULL;

#if PARROT_GC_MS
    Parrot_gc_ms_init(interp);
#endif
#if PARROT_GC_IMS
    Parrot_gc_ims_init(interp);
#endif
#if PARROT_GC_GMS
    Parrot_gc_gms_init(interp);
#endif

    Parrot_initialize_memory_pools(interp);
    Parrot_initialize_header_pools(interp);
}

/*
 * Local variables:
 *   c-file-style: "parrot"
 * End:
 * vim: expandtab shiftwidth=4:
 */

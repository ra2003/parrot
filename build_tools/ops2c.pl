#! /usr/bin/perl -w
#
# ops2c.pl
#
# Generate a C header and source file from the operation definitions in
# an .ops file, using a supplied transform.
#
# $Id$
#

use strict;
use lib 'lib';
use Parrot::OpsFile;
use Parrot::OpLib::core;

my %arg_dir_mapping = (
	''   => 'PARROT_ARGDIR_IGNORED',
	'i'  => 'PARROT_ARGDIR_IN',
	'o'  => 'PARROT_ARGDIR_OUT',
	'io' => 'PARROT_ARGDIR_INOUT'
);

sub Usage {
    print STDERR <<_EOF_;
usage: $0 trans [--dynamic] [--core | input.ops [input2.ops ...]]
       trans := C | CGoto | CGP | CSwitch | CPrederef
_EOF_
    exit 1;
}

#
# Process command-line argument:
#

Usage() unless @ARGV >= 2;

my $trans_class = "Parrot::OpTrans::" . shift @ARGV;

eval "require $trans_class";

my $trans = $trans_class->new;

my $prefix  = $trans->prefix;
my $suffix  = $trans->suffix;
my $defines = $trans->defines;
my $opsarraytype = $trans->opsarraytype;
my $core_type = $trans->core_type;

my $dynamic;
my $file = shift @ARGV;
if ($file eq '-d' || $file eq '--dynamic') {
    $file = shift @ARGV;
    $dynamic = 1;
}
my $core = 0;
if ($file eq '--core') {
	$file = 'core.ops';
	$core = 1;
}

my $base = $file;
$base =~ s/\.ops$//;

my $incdir  = "include/parrot/oplib";
my $include = "parrot/oplib/${base}_ops${suffix}.h";
my $header  = "include/$include";
my $source  = "ops/${base}_ops${suffix}.c";

if ($base =~ m!^dynoplibs/! || $dynamic) {
    $source  =~ s!ops/!!;
    $header = "${base}_ops${suffix}.h";
    $base =~ s!^.*[/\\]!!;
    $include = "${base}_ops${suffix}.h";
    $dynamic = 1;
}

my %hashed_ops;

#
# Read the input files:
#

my $ops;
if ($core) {
    $ops = Parrot::OpsFile->new('ops/core.ops');
    $ops->{OPS} = $Parrot::OpLib::core::ops;
    $ops->{PREAMBLE} = $Parrot::OpLib::core::preamble;
}
else {
    my %opsfiles;
    my @opsfiles;

    foreach my $opsfile ($file, @ARGV) {
	if ($opsfiles{$opsfile}) {
	    print STDERR "$0: Ops file '$opsfile' mentioned more than once!\n";
	    next;
	}

	$opsfiles{$opsfile} = 1;
	push @opsfiles, $opsfile;

	die "$0: Could not read ops file '$opsfile'!\n" unless -r $opsfile;
    }

    $ops = new Parrot::OpsFile @opsfiles;

    my $cur_code = 0;
    for(@{$ops->{OPS}}) {
	$_->{CODE}=$cur_code++;

    }
}


my $version       = $ops->version;
my $major_version = $ops->major_version;
my $minor_version = $ops->minor_version;
my $patch_version = $ops->patch_version;
my $num_ops     = scalar $ops->ops;
my $num_entries = $num_ops + 1; # For trailing NULL


#
# Open the output files:
#

if (!$dynamic && ! -d $incdir) {
    mkdir($incdir, 0755) or die "ops2c.pl: Could not mkdir $incdir $!!\n";
}

open HEADER, ">$header"
  or die "ops2c.pl: Could not open header file '$header' for writing: $!!\n";

open SOURCE, ">$source"
  or die "ops2c.pl: Could not open source file '$source' for writing: $!!\n";


#
# Print the preamble for the HEADER and SOURCE files:
#

my $preamble = <<END_C;
/*
 * !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
 *
 * This file is generated automatically from '$file' (and possibly other
 * .ops files). by $0.
 *
 * Any changes made here will be lost!
 *
 */

END_C

my $mmp_v = "${major_version}_${minor_version}_${patch_version}";
my $init_func = "Parrot_DynOp_${base}${suffix}_$mmp_v";

print HEADER $preamble;
print HEADER <<END_C;
#include "parrot/parrot.h"
#include "parrot/oplib.h"

extern op_lib_t *$init_func(int init);

END_C
my $cg_func = $trans->core_prefix . $base;


if ($trans->can("run_core_func_decl")) {
    my $run_core_func = $trans->run_core_func_decl($base);
    print HEADER "$run_core_func;\n";
}
my $bs = "${base}${suffix}_";

print SOURCE $preamble;
print SOURCE <<END_C;
#include "$include"

${defines}
static op_lib_t ${bs}op_lib;

END_C

my $text = $ops->preamble($trans);
$text =~ s/\bops_addr\b/${bs}ops_addr/g;
print SOURCE $text;


if ($trans->can("ops_addr_decl")) {
    print SOURCE $trans->ops_addr_decl($bs);
}
if ($trans->can("run_core_func_decl")) {
    print SOURCE $trans->run_core_func_decl($base);
    print SOURCE "\n{\n";
    print SOURCE $trans->run_core_func_start;
}

#
# Iterate over the ops, appending HEADER and SOURCE fragments:
#

my @op_funcs;
my @op_func_table;
my @cg_jump_table;
my $index = 0;
my ($prev_source, $prev_func_name, $prev_def);

foreach my $op ($ops->ops) {
    my $func_name  = $op->func_name($trans);
    my $arg_types  = "$opsarraytype *, struct Parrot_Interp *";
    my $prototype  = "$opsarraytype * $func_name ($arg_types)";
    my $args       = "$opsarraytype *cur_opcode, struct Parrot_Interp * interpreter";
    my $definition;
    my $comment = '';
    $prev_def = '';
    if ($suffix =~ /cg/) {
	$prev_def = $definition = "PC_$index:";
	$comment =  "/* ". $op->func_name($trans) ." */";
	push @cg_jump_table, "        &&PC_$index,\n";
    } elsif ($suffix =~ /switch/) {
	$comment =  "/* ". $op->func_name($trans) ." */";
	push @op_funcs, <<END_C;
	case $index:	$comment
END_C
    }
    elsif ($suffix eq '') {
        $definition = "$opsarraytype * $func_name ($args);\n";
        $definition .= "$opsarraytype *\n$func_name ($args)";
    }
    else {
        $definition = "static $opsarraytype *\n$func_name ($args)";
    }
    my $source     = $op->source($trans);
    $source =~ s/\bop_lib\b/${bs}op_lib/;
    $source =~ s/\bops_addr\b/${bs}ops_addr/g;

#    print HEADER "$prototype;\n";
#
#   for predereferenced code all variants of one op with or without
#   "c" suffix generate the same function body
#
#   e.g.
#
#   set i,i,i
#   set i,ic,i
#   set i,i,ic
#   set i,ic,ic
#
#   have all the same function body, and thus we generate only the
#   first one and change the op_func_table accordingly

    if ($prev_source && $prev_source eq $source) {
	push @op_func_table, sprintf("  %-50s /* %6ld */\n",
	    "$prev_func_name,", $index);
	push @op_funcs, <<"EOF";
/*$prev_def	 $func_name => $prev_func_name */
EOF
	# pop off  label and duplicate previous
	if ($suffix =~ /cg/) {
	    pop @cg_jump_table;
	    push @cg_jump_table, $cg_jump_table[-1];
	}
	if ($suffix =~ /switch/) {
	    my $bdy = pop @op_funcs;
	    my $cas = pop @op_funcs;
	    $bdy = pop @op_funcs;
	    push @op_funcs, $cas;
	    push @op_funcs, $bdy;
	}
    }
    else {
	if ($suffix =~ /switch/) {
	    push @op_funcs,"\t{\n$source}\n\n";
	}
	else {
	    push @op_func_table, sprintf("  %-50s /* %6ld */\n",
		"$func_name,", $index);
	    push @op_funcs,      "$definition $comment {\n$source}\n\n";
	}
	$prev_source = $source;
	$prev_func_name = $func_name;
    }
    $index++;
}

if ($suffix =~ /cg/) {
    print SOURCE @cg_jump_table;
    print SOURCE <<END_C;
        NULL
    };
END_C
    print SOURCE $trans->run_core_after_addr_table($bs);

}

if ($suffix =~ /cgp/) {
    print SOURCE <<END_C;
#ifdef __GNUC__
# ifdef I386
    else if (cur_opcode == (opcode_t *) 1)
	asm ("jmp *4(%ebp)");	/* jump to ret addr, used by JIT */
# endif
    else
      _check();
#endif
    goto **cur_opcode;

END_C
} elsif ($suffix =~ /cg/) {
    print SOURCE <<END_C;
#ifdef __GNUC__
    _check();
#endif
goto *${bs}ops_addr[*cur_opcode];

END_C
}



print SOURCE <<END_C;
/*
** Op Function Definitions:
*/

END_C

#
# Finish the SOURCE file's array initializer:
#
print SOURCE @op_funcs;

if ($trans->can("run_core_finish")) {
    print SOURCE $trans->run_core_finish($base);
}


#
# reset #line in the SOURCE file.
#

close(SOURCE);
open(SOURCE, "<$source") || die "Error re-reading $source: $!\n";
my $line = 0; while (<SOURCE>) { $line++; } $line+=2;
close(SOURCE);
open(SOURCE, ">>$source") || die "Error appending to $source: $!\n";
print SOURCE "#line $line \"$source\"\n" unless $ENV{PARROT_NO_LINE};


#
# write op_func_func
#

my ($op_info, $op_func, $getop);
$op_info = $op_func = 'NULL';
$getop = '( int (*)(const char *, int) )NULL';

if ($suffix !~ /cg/ && $suffix !~ /switch/) {
    $op_func = "${bs}op_func_table";
    print SOURCE <<END_C;

INTVAL ${bs}numops${suffix} = $num_ops;

/*
** Op Function Table:
*/

static op_func${suffix}_t ${op_func}\[$num_entries] = {
END_C

    print SOURCE @op_func_table;

    print SOURCE <<END_C;
  (op_func${suffix}_t)0  /* NULL function pointer */
};


END_C

}

my (%names, $tot);
if ($suffix eq '') {
    $op_info = "${bs}op_info_table";
#
# Op Info Table:
#
    print SOURCE <<END_C;

/*
** Op Info Table:
*/

static op_info_t $op_info\[$num_entries] = {
END_C

    $index = 0;

    foreach my $op ($ops->ops) {
	my $type       = sprintf("PARROT_%s_OP", uc $op->type);
	my $name       = $op->name;
	$names{$name} = 1;
	my $full_name  = $op->full_name;
	my $func_name  = $op->func_name($trans);
	my $body       = $op->body;
	my $jump       = $op->jump || 0;
	my $arg_count  = $op->size;
	my $arg_types  = "{ " . join(", ", map { sprintf("PARROT_ARG_%s", uc $_) } $op->arg_types) . " }";
	my $arg_dirs   = "{ " . join(", ", map { $arg_dir_mapping{$_} } $op->arg_dirs) . " }";

	print SOURCE <<END_C;
  { /* $index */
    $type,
    "$name",
    "$full_name",
    "$func_name",
    "", /* TODO: Put the body here */
    $jump,
    $arg_count,
    $arg_types,
    $arg_dirs
  },
END_C

	$index++;
    }
    print SOURCE <<END_C;
};

END_C
}

if ($suffix eq '' && !$dynamic) {
    $getop = 'get_op';
    my $hash_size = 2011;
    $tot = $index + scalar keys(%names);
    if ($hash_size < $tot * 1.2) {
	    print STDERR "please increase hash_size ($hash_size) in ops2c.pl\n";
    }
    print SOURCE <<END_C;

/*
** Op lookup function:
*/

#define NUM_OPS $num_ops

#define OP_HASH_SIZE $hash_size

/* we could calculate a prime somewhat bigger than
 * n of fullnames + n of names
 * for now this should be ok
 *
 * look up an op_code: at first call to op_code() a hash
 * of short and full opcode names is created
 * hash functions are from imcc, thanks to Melvin.
 */


typedef struct hop {
    op_info_t * info;
    struct hop *next;
} HOP;
static HOP **hop;

static void hop_init(void);
static size_t hash_str(const char * str);
static void store_op(op_info_t *info, int full);

/* XXX on changing interpreters, this should be called,
   through a hook */

static void hop_deinit(void);

/*
 * find a short or full opcode
 * usage:
 *
 * interp->op_lib->op_code("set", 0)
 * interp->op_lib->op_code("set_i_i", 1)
 *
 * returns >= 0 (found idx into info_table), -1 if not
 */

static int get_op(const char * name, int full);

static size_t hash_str(const char * str) {
    size_t key = 0;
    const char * s;
    for(s=str; *s; s++)
	key = key * 65599 + *s;
    return key;
}

static void store_op(op_info_t *info, int full) {
    HOP *p = mem_sys_allocate(sizeof(HOP));
    size_t hidx;
    hidx = hash_str(full ? info->full_name : info->name) % OP_HASH_SIZE;
    p->info = info;
    p->next = hop[hidx];
    hop[hidx] = p;
}
static int get_op(const char * name, int full) {
    HOP * p;
    size_t hidx = hash_str(name) % OP_HASH_SIZE;
    if (!hop) {
	hop = mem_sys_allocate_zeroed(OP_HASH_SIZE * sizeof(HOP*));
	hop_init();
    }
    for(p = hop[hidx]; p; p = p->next) {
	if(!strcmp(name, full ? p->info->full_name : p->info->name))
	    return p->info - ${bs}op_lib.op_info_table;
    }
    return -1;
}
static void hop_init() {
    size_t i;
    op_info_t * info = ${bs}op_lib.op_info_table;
    /* store full names */
    for (i = 0; i < ${bs}op_lib.op_count; i++)
	store_op(info + i, 1);
    /* plus one short name */
    for (i = 0; i < ${bs}op_lib.op_count; i++)
	if (get_op(info[i].name, 0) == -1)
	    store_op(info + i, 0);
}
static void hop_deinit(void)
{
    HOP *p, *next;
    size_t i;
    if (hop) {
	for (i = 0; i < OP_HASH_SIZE; i++)
	    for(p = hop[i]; p; ) {
		next = p->next;
		free(p);
		p = next;
	}
	free(hop);
    }
    hop = 0;
}

END_C

}
else {
    print SOURCE <<END_C;
static void hop_deinit(void) {}
END_C
}

print SOURCE <<END_C;

/*
** op lib descriptor:
*/

static op_lib_t ${bs}op_lib = {
  "$base",		/* name */
  "$suffix",		/* suffix */
  $core_type,	        /* core_type = PARROT_XX_CORE */
  0,			/* flags */
  $major_version,	/* major_version */
  $minor_version,	/* minor_version */
  $patch_version,	/* patch_version */
  $num_ops,		/* op_count */
  $op_info,		/* op_info_table */
  $op_func,		/* op_func_table */
  $getop		/* op_code() */
};

END_C

# generate initfunc
my $init1_code = "";
if ($trans->can("init_func_init1")) {
    $init1_code = $trans->init_func_init1($base);
}

my $init_set_dispatch = "";
if ($trans->can("init_set_dispatch")) {
    $init_set_dispatch = $trans->init_set_dispatch($bs);
}

print SOURCE <<END_C;
op_lib_t *
$init_func(int init) {
    /* initialize and return op_lib ptr */
    if (init == 1) {
$init1_code
	return &${bs}op_lib;
    }
    /* set op_lib to the passed ptr (in init) */
    else if (init) {
$init_set_dispatch
    }
    /* deinit - free resources */
    else {
	hop_deinit();
    }
    return NULL;
}

END_C

if ($dynamic) {
    my $load_func = "Parrot_lib_${base}_ops${suffix}_load";
    print SOURCE <<END_C;
/*
 * dynamic lib load function - called once
 */

PMC*
$load_func(Parrot_Interp interpreter)
{
    PMC *lib = pmc_new(interpreter, enum_class_ConstParrotLibrary);
    lib->cache.struct_val = (void *) $init_func;
    dynop_register(interpreter, lib);
    return lib;
}
END_C

}

exit 0;

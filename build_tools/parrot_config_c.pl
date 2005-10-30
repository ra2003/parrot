#! perl -w
# Copyright: 2001-2003 The Perl Foundation.  All Rights Reserved.
# $Id$
use strict;

my ($svnid) = '$Id$' =~ /^\$[iI][dD]:\s(.*)\$$/;

=head1 NAME

build_tools/parrot_config_c.pl - Create src/parrot_config.c

=head1 SYNOPSIS

    % perl build_tools/parrot_config_c.pl --mini > src/null_config.c
    % perl build_tools/parrot_config_c.pl --install > src/install_config.c
    % perl build_tools/parrot_config_c.pl > src/parrot_config.c

=head1 DESCRIPTION

Create F<src/parrot_config.c> with relevant runtime fro the config
process. The created string contains a frozen image of the config hash.

For miniparrot a fake config file is written that contains just the interface.

=cut


use strict;

my ($mini_parrot, $install_parrot);
$mini_parrot = 1 if (@ARGV && $ARGV[0] =~ /mini/);
$install_parrot = 1 if (@ARGV && $ARGV[0] =~ /install/);

print << "EOF";
/*
 * !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
 *
 * This file is generated automatically by $0.
 *
 * Any changes made here will be lost!
 *
 */

#include "parrot/parrot.h"

static const unsigned char parrot_config[] = {
EOF

if ($mini_parrot) {
    print "    0\n";
}
else {
    my $image_file = $install_parrot ?
	'install_config.fpmc' : 'runtime/parrot/include/config.fpmc';
    open F, $image_file or die "Can't read '$image_file': $!";
    my $image;
    local $/;
	binmode F;
    $_ = <F>;
    close F;
    my @c = split '';
    printf '    ';
    my $i;
    for (@c) {
	printf "0x%02x", ord($_);
	++$i;
	print ', ', if ($i < scalar(@c));
	print "\n    " unless $i % 8;
    }
    print "\n";
}

print << "EOF";
}; /* parrot_config */

STRING*
parrot_get_config_string(Interp* interpreter)
{
    if (sizeof(parrot_config) <= 1)
	return NULL;
    return string_from_const_cstring(interpreter,
	parrot_config, sizeof(parrot_config));
}
EOF



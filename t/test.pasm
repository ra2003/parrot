#
# test.pasm
#
# Copyright (C) 2001 The Parrot Team. All rights reserved.
# This program is free software. It is subject to the same
# license as The Parrot Interpreter.
#
# $Id$
#

        set    I2, 0
        set    I3, 1
        set    I4, 100000000

	print  "Iterations:                  "
	print  I4
        print  "\n"

        time   I1

REDO:   eq     I2, I4, DONE
        add    I2, I2, I3
        branch REDO

DONE:   time   I5

	print  "Start time:                  "
        print  I1
        print  "\n"

	print  "End time:                    "
        print  I5
        print  "\n"

	print  "Count:                       "
        print  I2
        print  "\n"

        sub    I2, I5, I1

	print  "Elapsed time:                "
        print  I2
        print  "\n"

        set    I1, 3
        mul    I4, I4, I1
        iton   N1, I4
        iton   N2, I2

	print  "Estimated ops:               "
        print  I4
        print  "\n"

	print  "Estimated ops (numerically): "
        print  N1
        print  "\n"

	print  "Elapsed time:                "
        print  I2
        print  "\n"

	print  "Elapsed time:                "
        print  N2
        print  "\n"

        div    N1, N1, N2

	print  "Ops/sec:                     "
        print  N1
        print  "\n"

        end


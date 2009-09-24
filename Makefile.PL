use strict;
use inc::Module::Install;

die "OS unsupported\n" if $^O !~ /freebsd/;

name 'BSD-Process-Affinity';
perl_version '5.006';

abstract_from 'lib/BSD/Process/Affinity.pod';
author 'Sergey Aleynikov <sergey.aleynikov@gmail.com>';
version_from 'lib/BSD/Process/Affinity.pm';
license 'bsd';

test_requires 'Test::More';

requires 'XSLoader';
requires 'Exporter';

system 'pod2text lib/BSD/Process/Affinity.pod > README';

WriteAll;

use strict;
use inc::Module::Install;

die "OS unsupported\n" if $^O !~ /freebsd/;

name 'BSD-Process-Affinity';
perl_version '5.006';

abstract_from 'lib/BSD/Process/Affinity.pod';
version_from 'lib/BSD/Process/Affinity.pm';
author 'Sergey Aleynikov <sergey.aleynikov@gmail.com>';
license 'bsd';

test_requires 'Test::More';

requires 'XSLoader';
requires 'Exporter';
requires 'Bit::Vector' => 7.0;

install_script 'bin/setaffinity';
install_script 'bin/runaffinity';

system 'pod2text lib/BSD/Process/Affinity.pod > README';

WriteAll;

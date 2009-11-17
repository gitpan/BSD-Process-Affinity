package BSD::Process::Affinity;

use strict;

our $VERSION = '0.0301';
use Bit::Vector;

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

require Exporter;
@BSD::Process::Affinity::ISA = qw(Exporter);
%BSD::Process::Affinity::EXPORT_TAGS = (
	all	=> [qw(
		cpuset_clone
		cpuset_rootof_set cpuset_rootof_pid cpuset_current_set cpuset_current_pid
		cpuset_get_thread_mask cpuset_get_process_mask
	)],
);
Exporter::export_ok_tags('all');

1;

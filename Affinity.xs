/*
Copyright (c) 2009 by Sergey Aleynikov.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
SUCH DAMAGE.

*/
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <string.h>
#include <sys/param.h>
#include <sys/cpuset.h>

#define PANIC(msg) croak("%s: %s", msg, strerror(errno))

#define objnew(cl)								\
		SV* obj_ref;							\
		SV* obj;								\
		struct cpusetinfo* info;				\
												\
		obj_ref= newSViv(0);					\
		obj = newSVrv(obj_ref, cl);				\
												\
		Newz(0, info, 1, struct cpusetinfo);	\
		sv_setiv(obj, (IV)info);				\
		SvREADONLY_on(obj);						\

struct cpusetinfo {
	/* set is designated to */
	cpulevel_t	level;
	cpuwhich_t	which;
	id_t		id;
	/* set id */
	cpusetid_t	setid;
	/* data for it */
	cpuset_t	mask;
};

void
populate_set(struct cpusetinfo *info){
	int result;

	if (info->setid != 0){
		result = cpuset_getaffinity(CPU_LEVEL_WHICH, CPU_WHICH_CPUSET, info->setid, sizeof(info->mask), &(info->mask));
	}else{
		result = cpuset_getaffinity(CPU_LEVEL_WHICH, info->which, info->id, sizeof(info->mask), &(info->mask));
	}

	if (result != 0){
		Safefree(info);
		PANIC("Can't retrieve affinity info");
	}
}

MODULE = BSD::Process::Affinity		PACKAGE = BSD::Process::Affinity

PROTOTYPES: DISABLE

void
DESTROY(obj)
		SV* obj
	CODE:
		struct cpusetinfo* info = (struct cpusetinfo*)SvIV(SvRV(obj));
		Safefree(info);

SV *
cpuset_clone(...)
	ALIAS:
		clone = 1
	CODE:
		objnew("BSD::Process::Affinity");

		if (cpuset(&(info->setid)) != 0){
			Safefree(info);
			PANIC("Can't clone cpuset");
		}
		/* we're only members of new set */
		info->level = CPU_LEVEL_CPUSET;
		info->which = CPU_WHICH_PID;
		info->id = -1;

		populate_set(info);

		RETVAL = obj_ref;
	OUTPUT:
		RETVAL

SV *
cpuset_rootof_set(...)
	ALIAS:
		rootof_set = 1
		cpuset_rootof_pid = 2
		rootof_pid = 3
		cpuset_current_set = 4
		current_set = 5
		cpuset_current_pid = 6
		current_pid = 7
	CODE:
		objnew("BSD::Process::Affinity");

		if (ix % 2){
			if(items > 1){
				info->id = SvIV(ST(1));
			}
		}else{
			if (items > 0){
				info->id = SvIV(ST(0));
			}
		}
		if (info->id == 0){
			info->id = -1;
		}

		switch(ix){
			case 0:
			case 1:
				info->level = CPU_LEVEL_ROOT;
				info->which = CPU_WHICH_CPUSET;
				break;
			case 2:
			case 3:
				info->level = CPU_LEVEL_ROOT;
				info->which = CPU_WHICH_PID;
				break;
			case 4:
			case 5:
				info->level = CPU_LEVEL_CPUSET;
				info->which = CPU_WHICH_CPUSET;
				break;
			case 6:
			case 7:
				info->level = CPU_LEVEL_CPUSET;
				info->which = CPU_WHICH_PID;
				break;
		}

		if (cpuset_getid(info->level, info->which, info->id, &(info->setid)) != 0){
			Safefree(info);
			PANIC("Can't get cpuset");
		}

		populate_set(info);

		RETVAL = obj_ref;
	OUTPUT:
		RETVAL

SV *
cpuset_get_thread_mask(...)
	ALIAS:
		get_thread_mask = 1
		cpuset_get_process_mask = 2
		get_process_mask = 3
	CODE:
		objnew("BSD::Process::Affinity");

		info->level = CPU_LEVEL_WHICH;
		info->which = (ix < 2) ? CPU_WHICH_TID : CPU_WHICH_PID;

		if (ix % 2){
			if(items > 1){
				info->id = SvIV(ST(1));
			}
		}else{
			if (items > 0){
				info->id = SvIV(ST(0));
			}
		}
		if (info->id == 0){
			info->id = -1;
		}

		populate_set(info);

		RETVAL = obj_ref;
	OUTPUT:
		RETVAL

void
assign(obj, ...)
		SV* obj
	CODE:
		struct cpusetinfo* info = (struct cpusetinfo*)SvIV(SvRV(obj));

		if (info->setid == 0){
			croak("This object does not correspond to real cpuset, it's only an anonymous mask.");
		}

		id_t target = 0;
		if (items > 1){
			target = (id_t)SvIV(ST(1));
		}
		if (target == 0){
			target = -1;
		}

		if (cpuset_setid(CPU_WHICH_PID, target, info->setid) != 0){
			PANIC("Can't set thread's cpuset");
		}

void
update(obj)
		SV* obj
	CODE:
		struct cpusetinfo* info = (struct cpusetinfo*)SvIV(SvRV(obj));
		int result;

		if (info->setid != 0){
			result = cpuset_setaffinity(CPU_LEVEL_WHICH, CPU_WHICH_CPUSET, info->setid, sizeof(info->mask), &(info->mask));
		}else{
			result = cpuset_setaffinity(CPU_LEVEL_WHICH, info->which, info->id, sizeof(info->mask), &(info->mask));
		}

		if (result != 0){
			PANIC("Can't set affinity mask");
		}

int
get_cpusetid(obj)
		SV* obj
	CODE:
		struct cpusetinfo* info = (struct cpusetinfo*)SvIV(SvRV(obj));
		RETVAL = info->setid;
	OUTPUT:
		RETVAL

void
clear(obj)
		SV* obj
	PPCODE:
		struct cpusetinfo* info = (struct cpusetinfo*)SvIV(SvRV(obj));
		CPU_ZERO(&(info->mask));
		XSRETURN(1);

int
get_bit(obj, pos)
		SV* obj
		int pos
	CODE:
		struct cpusetinfo* info = (struct cpusetinfo*)SvIV(SvRV(obj));
		if(pos < 1 || pos > CPU_SETSIZE){
			croak("Processor number should be between 1 and %d", CPU_SETSIZE);
		}
		RETVAL = CPU_ISSET(pos - 1, &(info->mask));
	OUTPUT:
		RETVAL

void
set_bit(obj, pos)
		SV* obj
		int pos
	PPCODE:
		struct cpusetinfo* info = (struct cpusetinfo*)SvIV(SvRV(obj));
		if(pos < 1 || pos > CPU_SETSIZE){
			croak("Processor number should be between 1 and %d", CPU_SETSIZE);
		}
		CPU_SET(pos - 1, &(info->mask));
		XSRETURN(1);

void
clear_bit(obj, pos)
		SV* obj
		int pos
	PPCODE:
		struct cpusetinfo* info = (struct cpusetinfo*)SvIV(SvRV(obj));
		if(pos < 1 || pos > CPU_SETSIZE){
			croak("Processor number should be between 1 and %d", CPU_SETSIZE);
		}
		CPU_CLR(pos - 1, &(info->mask));
		XSRETURN(1);

void
intersect(obj1, obj2)
		SV* obj1
		SV* obj2
	PPCODE:
		struct cpusetinfo* info1 = (struct cpusetinfo*)SvIV(SvRV(obj1));
		struct cpusetinfo* info2 = (struct cpusetinfo*)SvIV(SvRV(obj2));

		CPU_AND(&(info1->mask), &(info2->mask));
		XSRETURN(1);


SV*
to_bitmask(obj)
		SV* obj
	CODE:
		struct cpusetinfo* info = (struct cpusetinfo*)SvIV(SvRV(obj));

		UV result = 0;
		int max_valid_bit = sizeof(UV);
		int i,j;
		for(i = 0; i < CPU_SETSIZE; i++){
			j = CPU_ISSET(i, &(info->mask));
			if (j){
				if (i > max_valid_bit){
					croak("Can't convert mask to number - not enough precision");
				}
				result |= (UV)1 << i;
			}
		}

		RETVAL = newSVuv(result);
	OUTPUT:
		RETVAL

void
from_bitmask(obj, num)
		SV* obj
		SV* num
	PPCODE:
		struct cpusetinfo* info = (struct cpusetinfo*)SvIV(SvRV(obj));

		UV input = SvUV(num);
		if (input == 0){
			CPU_ZERO(&(info->mask));
		}else{
			int i;
			CPU_ZERO(&(info->mask));
			for(i = 0; i < sizeof(UV) * 8; i++){
				if (i > CPU_SETSIZE){
					croak("Can't convert number to mask - not enough precision");
				}
				if (input & ((UV)1 << i)){
					CPU_SET(i, &(info->mask));
				}
			}
		}

		XSRETURN(1);

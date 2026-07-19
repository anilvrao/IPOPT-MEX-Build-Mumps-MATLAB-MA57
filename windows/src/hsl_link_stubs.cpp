#include <cstdio>
#include <cstdlib>

extern "C" void gpops_hsl_stub_called(const char* name)
{
    std::fprintf(stderr, "GPOPS-II IPOPT HSL link stub called unexpectedly: %s\n", name);
    std::abort();
}

#define STUB0(name) extern "C" void name() { gpops_hsl_stub_called(#name); }

STUB0(ma27ad_)
STUB0(ma27bd_)
STUB0(ma27cd_)
STUB0(ma28ad_)
STUB0(ma28bd_)
STUB0(ma28cd_)
STUB0(ma57ad_)
STUB0(ma57bd_)
STUB0(ma57cd_)
STUB0(ma57ed_)

extern "C" void ma27id_(int*, double*) {}
extern "C" void ma57id_(double*, int*) {}
extern "C" void ma28part_() { gpops_hsl_stub_called("ma28part_"); }

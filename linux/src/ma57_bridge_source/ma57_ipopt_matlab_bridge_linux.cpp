#include <dlfcn.h>

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

using i32 = std::int32_t;
using i64 = std::int64_t;

using ma57ad64_t = void (*)(i64*, i64*, const i64*, const i64*, i64*, i64*, i64*, i64*, i64*, double*);
using ma57bd64_t = void (*)(i64*, i64*, double*, double*, i64*, i64*, i64*, i64*, i64*, i64*, i64*, double*, i64*, double*);
using ma57cd64_t = void (*)(i64*, i64*, double*, i64*, i64*, i64*, i64*, double*, i64*, double*, i64*, i64*, i64*, i64*);
using ma57ed64_t = void (*)(i64*, i64*, i64*, double*, i64*, double*, i64*, i64*, i64*, i64*, i64*, i64*);
using ma57id64_t = void (*)(double*, i64*);

struct MatlabMa57 {
    void* so = nullptr;
    ma57ad64_t ad = nullptr;
    ma57bd64_t bd = nullptr;
    ma57cd64_t cd = nullptr;
    ma57ed64_t ed = nullptr;
    ma57id64_t id = nullptr;
};

std::unordered_map<const i32*, i32>& keep_lengths()
{
    static std::unordered_map<const i32*, i32> lengths;
    return lengths;
}

[[noreturn]] void fatal(const std::string& what)
{
    std::fprintf(stderr, "ma57_ipopt_matlab_bridge_linux: %s\n", what.c_str());
    std::fflush(stderr);
    std::abort();
}

std::string dirname_of_loaded_symbol(const char* library_name, const char* symbol_name)
{
    void* handle = dlopen(library_name, RTLD_NOW | RTLD_NOLOAD);
    if (!handle) {
        return {};
    }

    void* sym = dlsym(handle, symbol_name);
    if (!sym) {
        return {};
    }

    Dl_info info;
    if (dladdr(sym, &info) == 0 || !info.dli_fname) {
        return {};
    }

    std::string path(info.dli_fname);
    const std::string::size_type pos = path.find_last_of('/');
    return pos == std::string::npos ? std::string() : path.substr(0, pos);
}

void* try_dlopen(const std::string& candidate)
{
    if (candidate.empty()) {
        return nullptr;
    }
    return dlopen(candidate.c_str(), RTLD_NOW | RTLD_LOCAL);
}

void* load_real_ma57()
{
    const char* envs[] = {"MATLAB_MA57_SO", "MATLAB_MA57_DLL"};
    for (const char* env_name : envs) {
        const char* env = std::getenv(env_name);
        if (env && *env) {
            if (void* so = try_dlopen(env)) {
                return so;
            }
        }
    }

    const char* matlabroot = std::getenv("MATLABROOT");
    if (matlabroot && *matlabroot) {
        if (void* so = try_dlopen(std::string(matlabroot) + "/bin/glnxa64/libmwma57.so")) {
            return so;
        }
        if (void* so = try_dlopen(std::string(matlabroot) + "/sys/os/glnxa64/libmwma57.so")) {
            return so;
        }
    }

    const struct {
        const char* library;
        const char* symbol;
    } anchors[] = {
        {"libmex.so", "mexPrintf"},
        {"libmx.so", "mxCreateDoubleMatrix"},
        {"libmat.so", "matOpen"},
        {"libeng.so", "engOpen"},
    };

    for (const auto& anchor : anchors) {
        std::string dir = dirname_of_loaded_symbol(anchor.library, anchor.symbol);
        if (!dir.empty()) {
            if (void* so = try_dlopen(dir + "/libmwma57.so")) {
                return so;
            }
            const std::string suffix = "/bin/glnxa64";
            if (dir.size() >= suffix.size() &&
                dir.compare(dir.size() - suffix.size(), suffix.size(), suffix) == 0) {
                if (void* so = try_dlopen(dir.substr(0, dir.size() - suffix.size()) + "/sys/os/glnxa64/libmwma57.so")) {
                    return so;
                }
            }
        }
    }

    if (void* so = try_dlopen("libmwma57.so")) {
        return so;
    }

    const char* err = dlerror();
    fatal(std::string("could not load MATLAB libmwma57.so from matlabroot/bin/glnxa64 or matlabroot/sys/os/glnxa64; set MATLAB_MA57_SO or MATLABROOT if needed. ") +
          (err ? err : "unknown dlopen error"));
}

template <typename T>
T load_symbol(void* so, const char* base_name)
{
    const std::string names[] = {base_name, std::string(base_name) + "_"};
    for (const std::string& name : names) {
        dlerror();
        void* sym = dlsym(so, name.c_str());
        if (sym) {
            return reinterpret_cast<T>(sym);
        }
    }
    fatal(std::string("missing symbol in MATLAB libmwma57.so: ") + base_name);
}

MatlabMa57& real()
{
    static MatlabMa57 f;
    static bool initialized = false;
    if (!initialized) {
        f.so = load_real_ma57();
        f.ad = load_symbol<ma57ad64_t>(f.so, "ma57ad");
        f.bd = load_symbol<ma57bd64_t>(f.so, "ma57bd");
        f.cd = load_symbol<ma57cd64_t>(f.so, "ma57cd");
        f.ed = load_symbol<ma57ed64_t>(f.so, "ma57ed");
        f.id = load_symbol<ma57id64_t>(f.so, "ma57id");
        initialized = true;
    }
    return f;
}

size_t checked_len(i32 n, const char* name)
{
    if (n < 0) {
        fatal(std::string("negative array length for ") + name);
    }
    return static_cast<size_t>(n);
}

std::vector<i64> to64(const i32* src, size_t n)
{
    std::vector<i64> out(n);
    for (size_t k = 0; k < n; ++k) {
        out[k] = src[k];
    }
    return out;
}

void copy_to32(i32* dst, const i64* src, size_t n)
{
    for (size_t k = 0; k < n; ++k) {
        if (src[k] > std::numeric_limits<i32>::max() || src[k] < std::numeric_limits<i32>::min()) {
            fatal("MATLAB MA57 returned an integer value outside the 32-bit Ipopt range");
        }
        dst[k] = static_cast<i32>(src[k]);
    }
}

void copy_info_to32(i32* dst, const i64* src)
{
    copy_to32(dst, src, 40);
}

void ma57id_impl(double* cntl, i32* icntl)
{
    auto icntl64 = to64(icntl, 20);
    real().id(cntl, icntl64.data());
    copy_to32(icntl, icntl64.data(), 20);
}

void ma57ad_impl(i32* n, i32* ne, const i32* irn, const i32* jcn, i32* lkeep,
                 i32* keep, i32* iwork, i32* icntl, i32* info, double* rinfo)
{
    i64 n64 = *n;
    i64 ne64 = *ne;
    i64 lkeep64 = *lkeep;
    auto irn64 = to64(irn, checked_len(*ne, "irn"));
    auto jcn64 = to64(jcn, checked_len(*ne, "jcn"));
    auto keep64 = to64(keep, checked_len(*lkeep, "keep"));
    auto iwork64 = to64(iwork, checked_len(5 * (*n), "iwork"));
    auto icntl64 = to64(icntl, 20);
    auto info64 = to64(info, 40);

    real().ad(&n64, &ne64, irn64.data(), jcn64.data(), &lkeep64, keep64.data(),
              iwork64.data(), icntl64.data(), info64.data(), rinfo);

    *lkeep = static_cast<i32>(lkeep64);
    keep_lengths()[keep] = *lkeep;
    copy_to32(keep, keep64.data(), checked_len(*lkeep, "keep"));
    copy_to32(iwork, iwork64.data(), checked_len(5 * (*n), "iwork"));
    copy_to32(icntl, icntl64.data(), 20);
    copy_info_to32(info, info64.data());
}

void ma57bd_impl(i32* n, i32* ne, double* a, double* fact, i32* lfact,
                 i32* ifact, i32* lifact, i32* lkeep, i32* keep, i32* iwork,
                 i32* icntl, double* cntl, i32* info, double* rinfo)
{
    i64 n64 = *n;
    i64 ne64 = *ne;
    i64 lfact64 = *lfact;
    i64 lifact64 = *lifact;
    i64 lkeep64 = *lkeep;
    auto ifact64 = to64(ifact, checked_len(*lifact, "ifact"));
    auto keep64 = to64(keep, checked_len(*lkeep, "keep"));
    auto iwork64 = to64(iwork, checked_len(5 * (*n), "iwork"));
    auto icntl64 = to64(icntl, 20);
    auto info64 = to64(info, 40);

    real().bd(&n64, &ne64, a, fact, &lfact64, ifact64.data(), &lifact64,
              &lkeep64, keep64.data(), iwork64.data(), icntl64.data(), cntl,
              info64.data(), rinfo);

    *lfact = static_cast<i32>(lfact64);
    *lifact = static_cast<i32>(lifact64);
    *lkeep = static_cast<i32>(lkeep64);
    keep_lengths()[keep] = *lkeep;
    copy_to32(ifact, ifact64.data(), checked_len(*lifact, "ifact"));
    copy_to32(keep, keep64.data(), checked_len(*lkeep, "keep"));
    copy_to32(iwork, iwork64.data(), checked_len(5 * (*n), "iwork"));
    copy_to32(icntl, icntl64.data(), 20);
    copy_info_to32(info, info64.data());
}

void ma57cd_impl(i32* job, i32* n, double* fact, i32* lfact, i32* ifact,
                 i32* lifact, i32* nrhs, double* rhs, i32* lrhs, double* work,
                 i32* lwork, i32* iwork, i32* icntl, i32* info)
{
    i64 job64 = *job;
    i64 n64 = *n;
    i64 lfact64 = *lfact;
    i64 lifact64 = *lifact;
    i64 nrhs64 = *nrhs;
    i64 lrhs64 = *lrhs;
    i64 lwork64 = *lwork;
    auto ifact64 = to64(ifact, checked_len(*lifact, "ifact"));
    auto iwork64 = to64(iwork, checked_len(*n, "iwork"));
    auto icntl64 = to64(icntl, 20);
    auto info64 = to64(info, 40);

    real().cd(&job64, &n64, fact, &lfact64, ifact64.data(), &lifact64,
              &nrhs64, rhs, &lrhs64, work, &lwork64, iwork64.data(),
              icntl64.data(), info64.data());

    copy_to32(iwork, iwork64.data(), checked_len(*n, "iwork"));
    copy_to32(icntl, icntl64.data(), 20);
    copy_info_to32(info, info64.data());
}

void ma57ed_impl(i32* n, i32* ic, i32* keep, double* fact, i32* lfact,
                 double* newfac, i32* lnew, i32* ifact, i32* lifact,
                 i32* newifc, i32* linew, i32* info)
{
    i64 n64 = *n;
    i64 ic64 = *ic;
    i64 lfact64 = *lfact;
    i64 lnew64 = *lnew;
    i64 lifact64 = *lifact;
    i64 linew64 = *linew;

    auto keep_it = keep_lengths().find(keep);
    size_t keep_len = keep_it == keep_lengths().end()
        ? checked_len(5 * (*n) + std::max(*n, 0) + 42, "keep-min")
        : checked_len(keep_it->second, "keep");
    auto keep64 = to64(keep, keep_len);
    auto ifact64 = to64(ifact, checked_len(*lifact, "ifact"));
    auto info64 = to64(info, 40);

    if (*ic == 0) {
        i64 newifc_dummy = newifc ? *newifc : 0;
        real().ed(&n64, &ic64, keep64.data(), fact, &lfact64, newfac, &lnew64,
                  ifact64.data(), &lifact64, &newifc_dummy, &linew64, info64.data());
        if (newifc) {
            *newifc = static_cast<i32>(newifc_dummy);
        }
    } else {
        auto newifc64 = to64(newifc, checked_len(*linew, "newifc"));
        real().ed(&n64, &ic64, keep64.data(), fact, &lfact64, newfac, &lnew64,
                  ifact64.data(), &lifact64, newifc64.data(), &linew64, info64.data());
        copy_to32(newifc, newifc64.data(), checked_len(*linew, "newifc"));
    }

    copy_to32(keep, keep64.data(), keep_len);
    copy_to32(ifact, ifact64.data(), checked_len(*lifact, "ifact"));
    copy_info_to32(info, info64.data());
}

}  // namespace

#define EXPORTED extern "C" __attribute__((visibility("default")))

EXPORTED void ma57id(double* cntl, i32* icntl) { ma57id_impl(cntl, icntl); }
EXPORTED void ma57ad(i32* n, i32* ne, const i32* irn, const i32* jcn, i32* lkeep, i32* keep, i32* iwork, i32* icntl, i32* info, double* rinfo) { ma57ad_impl(n, ne, irn, jcn, lkeep, keep, iwork, icntl, info, rinfo); }
EXPORTED void ma57bd(i32* n, i32* ne, double* a, double* fact, i32* lfact, i32* ifact, i32* lifact, i32* lkeep, i32* keep, i32* iwork, i32* icntl, double* cntl, i32* info, double* rinfo) { ma57bd_impl(n, ne, a, fact, lfact, ifact, lifact, lkeep, keep, iwork, icntl, cntl, info, rinfo); }
EXPORTED void ma57cd(i32* job, i32* n, double* fact, i32* lfact, i32* ifact, i32* lifact, i32* nrhs, double* rhs, i32* lrhs, double* work, i32* lwork, i32* iwork, i32* icntl, i32* info) { ma57cd_impl(job, n, fact, lfact, ifact, lifact, nrhs, rhs, lrhs, work, lwork, iwork, icntl, info); }
EXPORTED void ma57ed(i32* n, i32* ic, i32* keep, double* fact, i32* lfact, double* newfac, i32* lnew, i32* ifact, i32* lifact, i32* newifc, i32* linew, i32* info) { ma57ed_impl(n, ic, keep, fact, lfact, newfac, lnew, ifact, lifact, newifc, linew, info); }
EXPORTED void ma57id_(double* cntl, i32* icntl) { ma57id_impl(cntl, icntl); }
EXPORTED void ma57ad_(i32* n, i32* ne, const i32* irn, const i32* jcn, i32* lkeep, i32* keep, i32* iwork, i32* icntl, i32* info, double* rinfo) { ma57ad_impl(n, ne, irn, jcn, lkeep, keep, iwork, icntl, info, rinfo); }
EXPORTED void ma57bd_(i32* n, i32* ne, double* a, double* fact, i32* lfact, i32* ifact, i32* lifact, i32* lkeep, i32* keep, i32* iwork, i32* icntl, double* cntl, i32* info, double* rinfo) { ma57bd_impl(n, ne, a, fact, lfact, ifact, lifact, lkeep, keep, iwork, icntl, cntl, info, rinfo); }
EXPORTED void ma57cd_(i32* job, i32* n, double* fact, i32* lfact, i32* ifact, i32* lifact, i32* nrhs, double* rhs, i32* lrhs, double* work, i32* lwork, i32* iwork, i32* icntl, i32* info) { ma57cd_impl(job, n, fact, lfact, ifact, lifact, nrhs, rhs, lrhs, work, lwork, iwork, icntl, info); }
EXPORTED void ma57ed_(i32* n, i32* ic, i32* keep, double* fact, i32* lfact, double* newfac, i32* lnew, i32* ifact, i32* lifact, i32* newifc, i32* linew, i32* info) { ma57ed_impl(n, ic, keep, fact, lfact, newfac, lnew, ifact, lifact, newifc, linew, info); }

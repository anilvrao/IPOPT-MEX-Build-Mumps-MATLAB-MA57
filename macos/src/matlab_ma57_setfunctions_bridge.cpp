#include "IpMa57TSolverInterface.hpp"
#include "mex.h"

#include <algorithm>
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <dlfcn.h>
#include <limits>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

typedef ptrdiff_t mwma57int;
typedef ma57int ipma57int;

typedef void (*mw_ma57ad_f)(mwma57int*, mwma57int*, const mwma57int*, const mwma57int*,
                            mwma57int*, mwma57int*, mwma57int*, mwma57int*,
                            mwma57int*, double*);
typedef void (*mw_ma57bd_f)(mwma57int*, mwma57int*, double*, double*, mwma57int*,
                            mwma57int*, mwma57int*, mwma57int*, mwma57int*,
                            mwma57int*, mwma57int*, double*, mwma57int*, double*);
typedef void (*mw_ma57cd_f)(mwma57int*, mwma57int*, double*, mwma57int*,
                            mwma57int*, mwma57int*, mwma57int*, double*,
                            mwma57int*, double*, mwma57int*, mwma57int*,
                            mwma57int*, mwma57int*);
typedef void (*mw_ma57ed_f)(mwma57int*, mwma57int*, mwma57int*, double*,
                            mwma57int*, double*, mwma57int*, mwma57int*,
                            mwma57int*, mwma57int*, mwma57int*, mwma57int*);
typedef void (*mw_ma57id_f)(double*, mwma57int*);

struct MatlabMa57 {
  void* handle = nullptr;
  mw_ma57ad_f ma57ad = nullptr;
  mw_ma57bd_f ma57bd = nullptr;
  mw_ma57cd_f ma57cd = nullptr;
  mw_ma57ed_f ma57ed = nullptr;
  mw_ma57id_f ma57id = nullptr;
};

MatlabMa57& lib()
{
  static MatlabMa57* L = new MatlabMa57();
  if (!L->handle) {
    mxArray* lhs[1] = {nullptr};
    if (mexCallMATLAB(1, lhs, 0, nullptr, "matlabroot") != 0 || lhs[0] == nullptr) {
      std::fprintf(stderr, "MATLAB MA57 bridge: unable to query matlabroot\n");
      std::abort();
    }

    char* root = mxArrayToString(lhs[0]);
    mxDestroyArray(lhs[0]);
    if (root == nullptr) {
      std::fprintf(stderr, "MATLAB MA57 bridge: unable to convert matlabroot to a path\n");
      std::abort();
    }

    std::string path = std::string(root) + "/bin/maca64/libmwma57.dylib";
    mxFree(root);

    L->handle = dlopen(path.c_str(), RTLD_LAZY | RTLD_LOCAL);
    if (!L->handle) {
      std::fprintf(stderr, "MATLAB MA57 bridge: unable to load %s: %s\n", path.c_str(), dlerror());
      std::abort();
    }
    L->ma57ad = reinterpret_cast<mw_ma57ad_f>(dlsym(L->handle, "ma57ad_"));
    L->ma57bd = reinterpret_cast<mw_ma57bd_f>(dlsym(L->handle, "ma57bd_"));
    L->ma57cd = reinterpret_cast<mw_ma57cd_f>(dlsym(L->handle, "ma57cd_"));
    L->ma57ed = reinterpret_cast<mw_ma57ed_f>(dlsym(L->handle, "ma57ed_"));
    L->ma57id = reinterpret_cast<mw_ma57id_f>(dlsym(L->handle, "ma57id_"));
    if (!L->ma57ad || !L->ma57bd || !L->ma57cd || !L->ma57ed || !L->ma57id) {
      std::fprintf(stderr, "MATLAB MA57 bridge: unable to resolve required MA57 symbols\n");
      std::abort();
    }
  }
  return *L;
}

std::unordered_map<const void*, std::size_t>& keep_lengths()
{
  static std::unordered_map<const void*, std::size_t>* M =
      new std::unordered_map<const void*, std::size_t>();
  return *M;
}

std::vector<mwma57int> to64(const ipma57int* x, std::size_t n)
{
  std::vector<mwma57int> y(n);
  for (std::size_t k = 0; k < n; ++k) y[k] = static_cast<mwma57int>(x[k]);
  return y;
}

void to32(ipma57int* x, const std::vector<mwma57int>& y)
{
  for (std::size_t k = 0; k < y.size(); ++k) {
    if (y[k] > static_cast<mwma57int>(std::numeric_limits<ipma57int>::max()) ||
        y[k] < static_cast<mwma57int>(std::numeric_limits<ipma57int>::min())) {
      std::fprintf(stderr, "MATLAB MA57 bridge: MATLAB MA57 returned an integer outside Ipopt range\n");
      std::abort();
    }
    x[k] = static_cast<ipma57int>(y[k]);
  }
}

std::size_t safe_nonnegative(ipma57int v)
{
  return v > 0 ? static_cast<std::size_t>(v) : 0u;
}

void bridge_ma57a(ipma57int* n, ipma57int* ne, const ipma57int* irn,
                  const ipma57int* jcn, ipma57int* lkeep, ipma57int* keep,
                  ipma57int* iwork, ipma57int* icntl, ipma57int* info,
                  double* rinfo)
{
  MatlabMa57& L = lib();
  mwma57int n64 = *n;
  mwma57int ne64 = *ne;
  mwma57int lkeep64 = *lkeep;
  std::vector<mwma57int> irn64 = to64(irn, safe_nonnegative(*ne));
  std::vector<mwma57int> jcn64 = to64(jcn, safe_nonnegative(*ne));
  std::vector<mwma57int> keep64 = to64(keep, safe_nonnegative(*lkeep));
  std::vector<mwma57int> iwork64 = to64(iwork, safe_nonnegative(5 * (*n)));
  std::vector<mwma57int> icntl64 = to64(icntl, 20);
  std::vector<mwma57int> info64 = to64(info, 40);

  L.ma57ad(&n64, &ne64, irn64.data(), jcn64.data(), &lkeep64, keep64.data(),
           iwork64.data(), icntl64.data(), info64.data(), rinfo);

  *n = static_cast<ipma57int>(n64);
  *ne = static_cast<ipma57int>(ne64);
  *lkeep = static_cast<ipma57int>(lkeep64);
  to32(keep, keep64);
  to32(iwork, iwork64);
  to32(icntl, icntl64);
  to32(info, info64);
  keep_lengths()[keep] = keep64.size();
}

void bridge_ma57b(ipma57int* n, ipma57int* ne, double* a, double* fact,
                  ipma57int* lfact, ipma57int* ifact, ipma57int* lifact,
                  ipma57int* lkeep, ipma57int* keep, ipma57int* iwork,
                  ipma57int* icntl, double* cntl, ipma57int* info,
                  double* rinfo)
{
  MatlabMa57& L = lib();
  mwma57int n64 = *n, ne64 = *ne, lfact64 = *lfact, lifact64 = *lifact;
  mwma57int lkeep64 = *lkeep;
  std::vector<mwma57int> ifact64 = to64(ifact, safe_nonnegative(*lifact));
  std::vector<mwma57int> keep64 = to64(keep, safe_nonnegative(*lkeep));
  std::vector<mwma57int> iwork64 = to64(iwork, safe_nonnegative(5 * (*n)));
  std::vector<mwma57int> icntl64 = to64(icntl, 20);
  std::vector<mwma57int> info64 = to64(info, 40);

  L.ma57bd(&n64, &ne64, a, fact, &lfact64, ifact64.data(), &lifact64,
           &lkeep64, keep64.data(), iwork64.data(), icntl64.data(),
           cntl, info64.data(), rinfo);

  *n = static_cast<ipma57int>(n64);
  *ne = static_cast<ipma57int>(ne64);
  *lfact = static_cast<ipma57int>(lfact64);
  *lifact = static_cast<ipma57int>(lifact64);
  *lkeep = static_cast<ipma57int>(lkeep64);
  to32(ifact, ifact64);
  to32(keep, keep64);
  to32(iwork, iwork64);
  to32(icntl, icntl64);
  to32(info, info64);
}

void bridge_ma57c(ipma57int* job, ipma57int* n, double* fact,
                  ipma57int* lfact, ipma57int* ifact, ipma57int* lifact,
                  ipma57int* nrhs, double* rhs, ipma57int* lrhs,
                  double* work, ipma57int* lwork, ipma57int* iwork,
                  ipma57int* icntl, ipma57int* info)
{
  MatlabMa57& L = lib();
  mwma57int job64 = *job, n64 = *n, lfact64 = *lfact, lifact64 = *lifact;
  mwma57int nrhs64 = *nrhs, lrhs64 = *lrhs, lwork64 = *lwork;
  std::vector<mwma57int> ifact64 = to64(ifact, safe_nonnegative(*lifact));
  std::vector<mwma57int> iwork64 = to64(iwork, safe_nonnegative(*n));
  std::vector<mwma57int> icntl64 = to64(icntl, 20);
  std::vector<mwma57int> info64 = to64(info, 40);

  L.ma57cd(&job64, &n64, fact, &lfact64, ifact64.data(), &lifact64,
           &nrhs64, rhs, &lrhs64, work, &lwork64, iwork64.data(),
           icntl64.data(), info64.data());

  *job = static_cast<ipma57int>(job64);
  *n = static_cast<ipma57int>(n64);
  *lfact = static_cast<ipma57int>(lfact64);
  *lifact = static_cast<ipma57int>(lifact64);
  *nrhs = static_cast<ipma57int>(nrhs64);
  *lrhs = static_cast<ipma57int>(lrhs64);
  *lwork = static_cast<ipma57int>(lwork64);
  to32(ifact, ifact64);
  to32(iwork, iwork64);
  to32(icntl, icntl64);
  to32(info, info64);
}

void bridge_ma57e(ipma57int* n, ipma57int* ic, ipma57int* keep,
                  double* fact, ipma57int* lfact, double* newfac,
                  ipma57int* lnew, ipma57int* ifact, ipma57int* lifact,
                  ipma57int* newifc, ipma57int* linew, ipma57int* info)
{
  MatlabMa57& L = lib();
  mwma57int n64 = *n, ic64 = *ic, lfact64 = *lfact, lnew64 = *lnew;
  mwma57int lifact64 = *lifact, linew64 = *linew;
  std::size_t keep_len = 5 * safe_nonnegative(*n) + 64;
  auto it = keep_lengths().find(keep);
  if (it != keep_lengths().end()) keep_len = it->second;
  std::vector<mwma57int> keep64 = to64(keep, keep_len);
  std::vector<mwma57int> ifact64 = to64(ifact, safe_nonnegative(*lifact));
  std::vector<mwma57int> info64 = to64(info, 40);

  if (*ic == 0) {
    mwma57int newifcDummy = newifc ? static_cast<mwma57int>(*newifc) : 0;
    L.ma57ed(&n64, &ic64, keep64.data(), fact, &lfact64, newfac, &lnew64,
             ifact64.data(), &lifact64, &newifcDummy, &linew64,
             info64.data());
    if (newifc) {
      *newifc = static_cast<ipma57int>(newifcDummy);
    }
  } else {
    std::vector<mwma57int> newifc64 =
        to64(newifc, std::max<std::size_t>(1, safe_nonnegative(*linew)));
    L.ma57ed(&n64, &ic64, keep64.data(), fact, &lfact64, newfac, &lnew64,
             ifact64.data(), &lifact64, newifc64.data(), &linew64,
             info64.data());
    to32(newifc, newifc64);
  }

  *n = static_cast<ipma57int>(n64);
  *ic = static_cast<ipma57int>(ic64);
  *lfact = static_cast<ipma57int>(lfact64);
  *lnew = static_cast<ipma57int>(lnew64);
  *lifact = static_cast<ipma57int>(lifact64);
  *linew = static_cast<ipma57int>(linew64);
  to32(keep, keep64);
  to32(ifact, ifact64);
  to32(info, info64);
}

void bridge_ma57i(double* cntl, ipma57int* icntl)
{
  MatlabMa57& L = lib();
  std::vector<mwma57int> icntl64(20, 0);
  L.ma57id(cntl, icntl64.data());
  to32(icntl, icntl64);
}

} // namespace

extern "C" void ipoptMexRegisterMatlabMa57ForIpopt()
{
  Ipopt::Ma57TSolverInterface::SetFunctions(&bridge_ma57a, &bridge_ma57b,
                                            &bridge_ma57c, &bridge_ma57e,
                                            &bridge_ma57i);
}

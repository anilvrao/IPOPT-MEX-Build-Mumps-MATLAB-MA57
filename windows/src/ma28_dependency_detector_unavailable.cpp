#include "IpMa28TDependencyDetector.hpp"

namespace Ipopt {

Ma28TDependencyDetector::Ma28TDependencyDetector()
{ }

void Ma28TDependencyDetector::RegisterOptions(SmartPtr<RegisteredOptions>)
{ }

bool Ma28TDependencyDetector::InitializeImpl(const OptionsList&, const std::string&)
{
    return false;
}

bool Ma28TDependencyDetector::DetermineDependentRows(Index, Index, Index, Number*,
                                                     Index*, Index*, std::list<Index>& c_deps)
{
    c_deps.clear();
    return false;
}

} // namespace Ipopt

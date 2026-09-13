// Exercise LLVM's actual library implementations, not a reimplementation.
#include "llvm/Support/SuffixTree.h"
#include "llvm/Transforms/Utils/CodeLayout.h"
#include <algorithm>
#include <iomanip>
#include <iostream>
#include <string>
#include <vector>
int main() {
  std::string text = "abcabxabcd$";
  std::vector<unsigned> symbols(text.begin(), text.end());
  llvm::SuffixTree tree(symbols);
  std::vector<std::pair<std::string, std::vector<unsigned>>> repeated;
  for (auto &r : tree) {
    std::vector<unsigned> starts(r.StartIndices.begin(), r.StartIndices.end());
    std::sort(starts.begin(), starts.end());
    repeated.emplace_back(text.substr(starts.front(), r.Length), starts);
  }
  std::sort(repeated.begin(), repeated.end());
  using namespace llvm::codelayout;
  std::vector<uint64_t> sizes{16,16,16,16,16}, counts{1500,1000,995,5,500};
  std::vector<EdgeCount> edges{{0,1,1000},{0,4,500},{1,2,995},{1,3,5}};
  std::vector<uint64_t> a{0,1,2,3,4}, b{0,1,2,4,3};
  auto order = computeExtTspLayout(sizes, counts, edges);
  std::cout << std::setprecision(12) << "{\"score_a\":" << calcExtTspScore(a,sizes,counts,edges)
    << ",\"score_b\":" << calcExtTspScore(b,sizes,counts,edges)
    << ",\"score_result\":" << calcExtTspScore(order,sizes,counts,edges) << ",\"layout\":[";
  for (unsigned i=0;i<order.size();++i) std::cout << (i?",":"") << order[i];
  std::cout << "],\"repeated\":[";
  for (unsigned i=0;i<repeated.size();++i) {
    std::cout << (i?",":"") << "{\"text\":\"" << repeated[i].first << "\",\"starts\":[";
    for (unsigned j=0;j<repeated[i].second.size();++j) std::cout << (j?",":"") << repeated[i].second[j];
    std::cout << "]}";
  }
  std::cout << "]}\n";
}

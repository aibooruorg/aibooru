#ifndef DTEXT_URL_H
#define DTEXT_URL_H

#include <string>
#include <regex>
#include <vector>

namespace DText {

class URL {
 public:
  const std::string_view url;
  std::string_view scheme;
  std::string_view domain;
  std::string_view path;
  std::string_view query;
  std::string_view fragment;

  URL(std::string_view url) : url(url) {
    parse();
  }

  const std::vector<std::string_view> path_components() const {
    std::vector<std::string_view> output;

    for (size_t previous = 0, current = 0; current != std::string_view::npos; previous = current + 1) {
      current = path.find_first_of('/', previous);

      if (current > previous) {
        output.push_back(path.substr(previous, current - previous));
      }
    }

    return output;
  }

 private:

  void parse() {
    // https://danbooru.donmai.us:443/posts/1234?q=touhou#comment-1234
    static const std::regex url_regex("^([a-z]+):(?://)?([^/?#:]+)(:[0-9]+)?(?:/([^?#]*))?(?:\\?([^#]*))?(?:#(.*))?$", std::regex_constants::icase | std::regex_constants::optimize);
    std::match_results<std::string_view::const_iterator> matches;

    if (std::regex_search(url.begin(), url.end(), matches, url_regex)) {
      scheme = { matches[1].first, matches[1].second };
      domain = { matches[2].first, matches[2].second };
      path = { matches[4].first, matches[4].second };
      query = { matches[5].first, matches[5].second };
      fragment = { matches[6].first, matches[6].second };
    };
  }
};

}

#endif

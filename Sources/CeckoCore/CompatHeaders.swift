/// Headers that GCC (Code::Blocks on Windows) has and clang on the Mac does
/// not. They are written into an include directory passed with `-isystem`,
/// so code from the teacher compiles unchanged.
public enum CompatHeaders {

    /// GCC's "include everything" header, rebuilt from the standard headers
    /// available in libc++ for C++20.
    public static let bitsStdcpp = """
    // Cecko: compatibility replacement for GCC's <bits/stdc++.h>.
    #pragma once

    #include <cassert>
    #include <cctype>
    #include <cerrno>
    #include <cfloat>
    #include <climits>
    #include <clocale>
    #include <cmath>
    #include <csetjmp>
    #include <csignal>
    #include <cstdarg>
    #include <cstddef>
    #include <cstdint>
    #include <cstdio>
    #include <cstdlib>
    #include <cstring>
    #include <ctime>
    #include <cwchar>
    #include <cwctype>

    #include <algorithm>
    #include <array>
    #include <atomic>
    #include <bitset>
    #include <chrono>
    #include <complex>
    #include <condition_variable>
    #include <deque>
    #include <exception>
    #include <forward_list>
    #include <fstream>
    #include <functional>
    #include <future>
    #include <initializer_list>
    #include <iomanip>
    #include <ios>
    #include <iosfwd>
    #include <iostream>
    #include <istream>
    #include <iterator>
    #include <limits>
    #include <list>
    #include <locale>
    #include <map>
    #include <memory>
    #include <mutex>
    #include <new>
    #include <numeric>
    #include <optional>
    #include <ostream>
    #include <queue>
    #include <random>
    #include <ratio>
    #include <regex>
    #include <set>
    #include <sstream>
    #include <stack>
    #include <stdexcept>
    #include <streambuf>
    #include <string>
    #include <string_view>
    #include <system_error>
    #include <thread>
    #include <tuple>
    #include <type_traits>
    #include <typeindex>
    #include <typeinfo>
    #include <unordered_map>
    #include <unordered_set>
    #include <utility>
    #include <valarray>
    #include <variant>
    #include <vector>

    #if __cplusplus >= 202002L
    #include <bit>
    #include <compare>
    #include <concepts>
    #include <numbers>
    #include <ranges>
    #include <span>
    #endif

    """
}

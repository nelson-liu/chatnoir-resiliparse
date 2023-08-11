set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
set(VCPKG_OSX_ARCHITECTURES x86_64)

set(VCPKG_BUILD_TYPE release)
set(VCPKG_C_FLAGS "-O3")
set(VCPKG_CXX_FLAGS "-std=c++17 -O3")
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
if(PORT MATCHES "abseil")
    set(VCPKG_LIBRARY_LINKAGE static)
endif()

cmake_minimum_required(VERSION 3.14)

set(CMAKE_VERBOSE_MAKEFILE off)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
if (SKBUILD)
    set(CMAKE_MACOSX_RPATH ON)
    set(CMAKE_BUILD_WITN_INSTALL_RPATH ON)
    set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
endif()
set(CMAKE_OSX_DEPLOYMENT_TARGET "10.14") # required for onnxruntime 1.14.1

project(
    piper_phonemize
    VERSION 1.2.0
    DESCRIPTION "Phonemization library for Piper text to speech system"
    HOMEPAGE_URL "https://github.com/rhasspy/piper-phonemize"
    LANGUAGES CXX
)

if(MSVC)
    # Force compiler to use UTF-8 for IPA constants
    add_compile_options("$<$<C_COMPILER_ID:MSVC>:/utf-8>")
    add_compile_options("$<$<CXX_COMPILER_ID:MSVC>:/utf-8>")

elseif(NOT APPLE)
    # Linux flags
    string(APPEND CMAKE_CXX_FLAGS "-D_FILE_OFFSET_BITS=64 -Wall -Wextra ")
    string(APPEND CMAKE_C_FLAGS "-D_FILE_OFFSET_BITS=64 -Wall -Wextra ")
endif()

if (APPLE)
    set(RPATH_PREFIX "@loader_path")
else()
    set(RPATH_PREFIX "\$ORIGIN")
endif()

add_library(
    piper_phonemize SHARED
    src/phonemize.cpp
    src/phoneme_ids.cpp
    src/tashkeel.cpp
    src/shared.cpp
)

include(GNUInstallDirs)

if(SKBUILD)
    set(PIPER_PHONEMIZE_LIBDIR "piper_phonemize/lib")
    set(CMAKE_INSTALL_LIBDIR "piper_phonemize/lib")
    set(CMAKE_INSTALL_BINDIR "piper_phonemize/lib")

else()
    set(PIPER_PHONEMIZE_LIBDIR ${CMAKE_INSTALL_LIBDIR})
endif()

set_target_properties(piper_phonemize PROPERTIES
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
)

set_target_properties(
    piper_phonemize PROPERTIES
    INSTALL_RPATH "${RPATH_PREFIX}"
)

if (SKBUILD)
    set(PYBIND11_FINDPYTHON ON)
    find_package(pybind11 CONFIG)

    pybind11_add_module(piper_phonemize_cpp
        src/python.cpp
    )
endif()
# ---- onnxruntime ---

# Look for onnxruntime files in <root>/lib
if(NOT DEFINED ONNXRUNTIME_DIR)
    if(NOT DEFINED ONNXRUNTIME_VERSION)
        set(ONNXRUNTIME_VERSION "1.14.1")
    endif()

    if(WIN32)
        if(CMAKE_SYSTEM_PROCESSOR STREQUAL AMD64)
            # Windows x86-64
            set(ONNXRUNTIME_PREFIX "onnxruntime-win-x64-${ONNXRUNTIME_VERSION}")
        elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL X86)
            # Windows x86
            set(ONNXRUNTIME_PREFIX "onnxruntime-win-x86-${ONNXRUNTIME_VERSION}")
        elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL ARM64)
            # Windows ARM64
            set(ONNXRUNTIME_PREFIX "onnxruntime-win-arm64-${ONNXRUNTIME_VERSION}")
        else()
            message(FATAL_ERROR "Unsupported architecture for onnxruntime")
        endif()
        set(ONNXRUNTIME_EXT "zip")
    elseif (APPLE)
        if(CMAKE_SYSTEM_PROCESSOR STREQUAL x86_64)
            # MacOS x86-64
            set(ONNXRUNTIME_PREFIX "onnxruntime-osx-x86_64-${ONNXRUNTIME_VERSION}")
        elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL arm64)
            # MacOS Apple Silicon
            set(ONNXRUNTIME_PREFIX "onnxruntime-osx-arm64-${ONNXRUNTIME_VERSION}")
        else()
            message(FATAL_ERROR "Unsupported architecture for onnxruntime")
        endif()

        set(ONNXRUNTIME_EXT "tgz")
    else()
        if(CMAKE_SYSTEM_PROCESSOR STREQUAL x86_64)
            # Linux x86-64
            set(ONNXRUNTIME_PREFIX "onnxruntime-linux-x64-${ONNXRUNTIME_VERSION}")
        elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL aarch64)
            # Linux ARM 64-bit
            set(ONNXRUNTIME_PREFIX "onnxruntime-linux-aarch64-${ONNXRUNTIME_VERSION}")
        elseif(CMAKE_SYSTEM_PROCESSOR STREQUAL armv7l)
            # Linux ARM 32-bit
            set(ONNXRUNTIME_PREFIX "onnxruntime-linux-arm32-${ONNXRUNTIME_VERSION}")
            set(ONNXRUNTIME_URL "https://github.com/synesthesiam/prebuilt-apps/releases/download/v1.0/onnxruntime-linux-arm32-${ONNXRUNTIME_VERSION}.tgz")
        else()
            message(FATAL_ERROR "Unsupported architecture for onnxruntime")
        endif()

        set(ONNXRUNTIME_EXT "tgz")
    endif()

    if(NOT DEFINED ONNXRUNTIME_URL)
        set(ONNXRUNTIME_URL "https://github.com/microsoft/onnxruntime/releases/download/v${ONNXRUNTIME_VERSION}/${ONNXRUNTIME_PREFIX}.${ONNXRUNTIME_EXT}")
    endif()

    set(ONNXRUNTIME_FILENAME "${ONNXRUNTIME_PREFIX}.${ONNXRUNTIME_EXT}")
    set(ONNXRUNTIME_DIR "${CMAKE_CURRENT_LIST_DIR}/lib/${ONNXRUNTIME_PREFIX}")

    if(NOT EXISTS "${ONNXRUNTIME_DIR}")
        if(NOT EXISTS "download/${ONNXRUNTIME_FILENAME}")
            # Download onnxruntime release
            message("Downloading ${ONNXRUNTIME_URL}")
            file(DOWNLOAD "${ONNXRUNTIME_URL}" "download/${ONNXRUNTIME_FILENAME}")
        endif()

        # Extract .zip or .tgz to a directory like lib/onnxruntime-linux-x64-1.14.1/
        file(ARCHIVE_EXTRACT INPUT "download/${ONNXRUNTIME_FILENAME}" DESTINATION "${CMAKE_CURRENT_LIST_DIR}/lib")
    endif()
endif()

# ---- espeak-ng ---

if(NOT DEFINED ESPEAK_NG_DIR)
    set(ESPEAK_NG_DIR "${CMAKE_CURRENT_BINARY_DIR}/ei")

        include(ExternalProject)
        ExternalProject_Add(
            espeak_ng_external
            PREFIX "${CMAKE_CURRENT_BINARY_DIR}/e"
            URL "https://github.com/rhasspy/espeak-ng/archive/0f65aa301e0d6bae5e172cc74197d32a6182200f.zip"
            CMAKE_ARGS -DCMAKE_INSTALL_PREFIX:PATH=${ESPEAK_NG_DIR}
            CMAKE_ARGS -DUSE_ASYNC:BOOL=OFF
            CMAKE_ARGS -DBUILD_SHARED_LIBS:BOOL=ON
            CMAKE_ARGS -DUSE_MBROLA:BOOL=OFF
            CMAKE_ARGS -DUSE_LIBSONIC:BOOL=OFF
            CMAKE_ARGS -DUSE_LIBPCAUDIO:BOOL=OFF
            CMAKE_ARGS -DUSE_KLATT:BOOL=OFF
            CMAKE_ARGS -DUSE_SPEECHPLAYER:BOOL=OFF
            CMAKE_ARGS -DEXTRA_cmn:BOOL=ON
            CMAKE_ARGS -DEXTRA_ru:BOOL=ON
            CMAKE_ARGS -DCMAKE_C_FLAGS=${CMAKE_C_FLAGS}
            CMAKE_ARGS -DCMAKE_CXX_FLAGS=${CMAKE_CXX_FLAGS}
            CMAKE_ARGS -DCMAKE_POSITION_INDEPENDENT_CODE=ON
        )
        add_dependencies(piper_phonemize espeak_ng_external)
        if (SKBUILD)
            add_dependencies(piper_phonemize_cpp espeak_ng_external)
        endif()

    set(EXTERNAL_ESPEAK TRUE) 
endif()


# ---- Declare library ----

target_include_directories(
    piper_phonemize PUBLIC
    "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/src>"
    ${ESPEAK_NG_DIR}/include
    ${ONNXRUNTIME_DIR}/include
)

target_link_directories(
    piper_phonemize PUBLIC
    ${ESPEAK_NG_DIR}/lib
    ${ONNXRUNTIME_DIR}/lib
)

target_link_libraries(
    piper_phonemize
    espeak-ng
    onnxruntime
)

if (SKBUILD)
    target_include_directories(
        piper_phonemize_cpp PUBLIC
        "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/src>"
        ${ESPEAK_NG_DIR}/include
        ${ONNXRUNTIME_DIR}/include
    )

    target_link_directories(
        piper_phonemize_cpp PUBLIC
        ${ESPEAK_NG_DIR}/lib
        ${ONNXRUNTIME_DIR}/lib
    )
    set_target_properties(piper_phonemize_cpp PROPERTIES
        INSTALL_RPATH "${RPATH_PREFIX}/${PIPER_PHONEMIZE_LIBDIR}")

    target_link_libraries(
        piper_phonemize_cpp PUBLIC 
        espeak-ng
        onnxruntime
        piper_phonemize)

    install(TARGETS piper_phonemize_cpp DESTINATION .)

endif()


target_compile_features(piper_phonemize PUBLIC cxx_std_17)

# ---- Declare executable ----
if (NOT SKBUILD)
    add_executable(piper_phonemize_exe src/main.cpp src/phoneme_ids.cpp)

    if(NOT WIN32)
        set_property(TARGET piper_phonemize_exe PROPERTY OUTPUT_NAME piper_phonemize)
    endif()

    target_compile_features(piper_phonemize_exe PUBLIC cxx_std_17)

    target_include_directories(
        piper_phonemize_exe PUBLIC
        "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/src>"
        ${ESPEAK_NG_DIR}/include
    )

    target_link_directories(
        piper_phonemize_exe PUBLIC
        ${ESPEAK_NG_DIR}/lib
    )

    set_target_properties(
        piper_phonemize_exe PROPERTIES
        INSTALL_RPATH ${RPATH_PREFIX}/../lib
    )

    target_link_libraries(piper_phonemize_exe PUBLIC
        piper_phonemize
        espeak-ng
    )

    # ---- Declare test ----

    include(CTest)
    enable_testing()
    add_executable(test_piper_phonemize src/test.cpp src/phoneme_ids.cpp)
    add_test(
        NAME test_piper_phonemize
        COMMAND test_piper_phonemize "${ESPEAK_NG_DIR}/share/espeak-ng-data" "${CMAKE_SOURCE_DIR}/etc/libtashkeel_model.ort"
    )

    target_compile_features(test_piper_phonemize PUBLIC cxx_std_17)

    target_include_directories(
        test_piper_phonemize PUBLIC
        "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/src>"
        ${ESPEAK_NG_DIR}/include
    )

    target_link_directories(
        test_piper_phonemize PUBLIC
        ${ESPEAK_NG_DIR}/lib
    )

    target_link_libraries(test_piper_phonemize PUBLIC
        piper_phonemize
        espeak-ng
    )
endif()
# ---- Declare install targets ----

install(
    TARGETS piper_phonemize
    RUNTIME LIBRARY DESTINATION ${PIPER_PHONEMIZE_LIBDIR})


if (SKBUILD)
    install(
        FILES "${CMAKE_SOURCE_DIR}/piper_phonemize/__init__.py"
        DESTINATION "piper_phonemize"
    )
    install(
        FILES ${CMAKE_SOURCE_DIR}/etc/libtashkeel_model.ort
        DESTINATION "piper_phonemize"
    )
    install(
        DIRECTORY ${ESPEAK_NG_DIR}/share/
        DESTINATION "piper_phonemize")
    
else()
    install(
        DIRECTORY ${CMAKE_SOURCE_DIR}/src/
        DESTINATION include/piper-phonemize
        FILES_MATCHING
        PATTERN "*.h"
        PATTERN "*.hpp")

    install(
        TARGETS piper_phonemize_exe
        ARCHIVE DESTINATION ${CMAKE_INSTALL_BINDIR})
    install(
        FILES ${CMAKE_SOURCE_DIR}/etc/libtashkeel_model.ort
        TYPE DATA)

    # Dependencies
    install(
        DIRECTORY ${ESPEAK_NG_DIR}/share/espeak-ng-data
        DESTINATION ${CMAKE_INSTALL_PREFIX})

    install(
        DIRECTORY ${ONNXRUNTIME_DIR}/include/
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

endif()

# Dependencies
if (SKBUILD AND UNIX AND NOT APPLE AND DEFINED ONNXRUNTIME_VERSION)
    # cheeky hack to avoid installing duplicates (scikit-build-core currently lacks zip-safe support)
    install(
        FILES "${ONNXRUNTIME_DIR}/lib/libonnxruntime.so.${ONNXRUNTIME_VERSION}"
        DESTINATION ${PIPER_PHONEMIZE_LIBDIR})
else()
    install(
        DIRECTORY ${ONNXRUNTIME_DIR}/lib/
        DESTINATION ${PIPER_PHONEMIZE_LIBDIR}
        PATTERN "*.pdb" EXCLUDE
        PATTERN "*.dSYM" EXCLUDE) # don't include debug symbols on Mac/Windows, those are like 200 MB
endif()

if (EXTERNAL_ESPEAK)
    install(DIRECTORY ${ESPEAK_NG_DIR}/lib/
            DESTINATION ${PIPER_PHONEMIZE_LIBDIR})
    if (WIN32)
        install(
            DIRECTORY ${ESPEAK_NG_DIR}/bin/
            DESTINATION ${PIPER_PHONEMIZE_LIBDIR})
    endif ()
endif()
